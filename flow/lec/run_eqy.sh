#!/usr/bin/env bash
# LEC: kiểm tra tương đương hình thức RTL <-> netlist bằng eqy (gate G6).
# Cách dùng:  run_eqy.sh <top> <netlist.v> <thư mục ra> <file rtl...>
# Biến môi trường:
#   PDK_ROOT (bắt buộc), PDK (mặc định sky130A), EQY (mặc định eqy)
#   EQY_STICKY  danh sách mẫu lưới tổ hợp cần gộp vào partition dùng nó (mặc định bên dưới)
#   JOBS        số tiến trình song song (mặc định nproc)
# netlist: netlist Yosys (build/syn/<top>/<top>.nl.v) hoặc netlist sau layout của LibreLane
#          (runs/wokwi/final/nl/<top>.nl.v — bản KHÔNG có chân nguồn).
#
# Chạy trong môi trường Nix của LibreLane 3.0.14 (có eqy 0.62 và eqy.formal_pdk_proc).
# KHÔNG đặt biến YOSYS trỏ tới bản YoWASP khi chạy script này: eqy cần plugin .so của Yosys thật.
#
# Trạng thái [ĐÃ ĐO 16/11/2026, RTL ↔ netlist Yosys]:
#   - cần (* fsm_encoding = "none" *) cho u_tx.state_q trong RTL (research_02 §1.1)
#   - apb_uart: PASS ("Successfully proved designs equivalent"), ~10 giây
#   - tt_um_hust_apb_uart: PASS, ~15 giây
#   - thử đột biến (đổi 1 cell and2 thành or2 trong netlist): eqy báo KHÔNG tương đương → không PASS giả
#   - RTL ↔ netlist sau layout: [CHƯA XÁC MINH]
set -euo pipefail
TOP=$1; NL=$2; OUT=$3; shift 3
RTL="$*"
: "${PDK:=sky130A}"; : "${EQY:=eqy}"; : "${JOBS:=$(nproc)}"
: "${PDK_ROOT:?chưa đặt PDK_ROOT}"
: "${EQY_STICKY:=*pslverr *soft_rst_wr}"
SCL=$PDK_ROOT/$PDK/libs.ref/sky130_fd_sc_hd/verilog

mkdir -p "$OUT"
NL=$(readlink -f "$NL"); OUTA=$(readlink -f "$OUT")
RTLA=""; for f in $RTL; do RTLA="$RTLA $(readlink -f "$f")"; done

# Mô hình cell sky130 dùng primitive UDP mà Yosys không đọc được.
# eqy.formal_pdk_proc đổi chúng sang Verilog thường, đúng như bước Yosys.EQY của LibreLane.
PROC=$OUTA/formal_pdk.v
eqy.formal_pdk_proc --output "$PROC" "$SCL/primitives.v" "$SCL/sky130_fd_sc_hd.v"

STICKY_LINES=""
for p in $EQY_STICKY; do STICKY_LINES="${STICKY_LINES}sticky $p
"; done

cat > "$OUTA/$TOP.eqy" << EOF
[gold]
read_verilog -formal -sv $RTLA

[gate]
read_verilog -formal -sv $PROC $NL

[script]
hierarchy -top $TOP
proc
prep -top $TOP -flatten
memory -nomap
async2sync
# Netlist Yosys/OpenROAD tách bus thành từng bit (\x[0]); tách cả hai bên
# giống nhau để eqy ghép được thanh ghi theo tên.
splitnets

[partition *]
# Lưới tổ hợp được ghép tên trở thành điểm cắt tự do và gây phản ví dụ giả khi
# netlist tính lại cùng hàm bằng nút khác. sticky gộp logic sinh ra lưới đó vào
# partition dùng nó (eqy docs, mục "sticky and nosticky").
${STICKY_LINES}
[strategy sat]
use sat
depth 5

[strategy pdr]
use sby
engine abc pdr -rfi
EOF

rm -rf "$OUTA/work"
set +e
"$EQY" -f "$OUTA/$TOP.eqy" -d "$OUTA/work" -j "$JOBS" > "$OUTA/eqy.log" 2>&1
rc=$?
set -e

proved=$(grep -c "Proved equivalence of partition" "$OUTA/eqy.log" || true)
unproved=$(grep "Could not prove equivalence of partition" "$OUTA/eqy.log" | sed "s/.*partition '\([^']*\)'.*/\1/" | sort -u || true)
echo "== LEC $TOP: $proved partition chứng minh (lượt sat), eqy rc=$rc"
if grep -q "Successfully proved designs equivalent" "$OUTA/eqy.log"; then
  echo "LEC PASS: $TOP"
else
  echo "LEC CHƯA PASS: $TOP. Partition sat không chứng minh được (pdr có thể đã thử tiếp):"
  echo "$unproved" | sed 's/^/  /'
  echo "Chi tiết: $OUTA/eqy.log, $OUTA/work/strategies/<partition>/"
  echo "Gợi ý: xem đầu vào của partition trong work/partitions/<partition>.json (khóa inbits);"
  echo "       lưới tổ hợp nào xuất hiện ở nhiều partition lỗi thì thêm vào EQY_STICKY."
  exit 1
fi
