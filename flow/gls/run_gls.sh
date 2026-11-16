#!/usr/bin/env bash
# =============================================================================
# GLS (gate-level simulation) trên Questa của server lab, có hoặc không có SDF (gate G8).
# Trạng thái: [CHƯA XÁC MINH] — chưa chạy (không có Questa ở nơi viết script).
# Script KHÔNG chứa testbench: testbench do người kiểm chứng cung cấp (H5 trong master plan).
#
# Cách dùng:
#   run_gls.sh <corner> <tb_top> <dut_path> <file tb...>
#     corner   : none | tt | ss | ff
#     tb_top   : tên module testbench
#     dut_path : đường dẫn instance của DUT trong testbench, ví dụ /tb_top/dut
#
# Biến môi trường:
#   PDK_ROOT  (bắt buộc)    thư mục chứa sky130A
#   NETLIST   (bắt buộc)    netlist không có chân nguồn:
#                             top TT : runs/wokwi/final/nl/tt_um_hust_apb_uart.nl.v
#                             apb_uart (D1-b): flow/librelane_apb_uart/runs/<tag>/final/nl/apb_uart.nl.v
#   SDF_DIR                 thư mục chứa nom_<corner>/ (mặc định runs/wokwi/final/sdf)
#   TOP                     tên module của netlist (mặc định tt_um_hust_apb_uart)
#   VSIM_EXTRA              tham số thêm cho vsim (ví dụ +TEST=t1_1_1)
#
# Thứ tự biên dịch: primitives.v, sky130_fd_sc_hd.v (KHÔNG define FUNCTIONAL để giữ khối specify),
# netlist, testbench.
# =============================================================================
set -euo pipefail
CORNER=$1; TB_TOP=$2; DUT=$3; shift 3
TB_FILES="$*"
: "${PDK_ROOT:?chưa đặt PDK_ROOT}"
: "${NETLIST:?chưa đặt NETLIST}"
: "${SDF_DIR:=runs/wokwi/final/sdf}"
: "${TOP:=tt_um_hust_apb_uart}"
: "${VSIM_EXTRA:=}"
SCL=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog

case "$CORNER" in
  none) SDF="" ;;
  tt)   SDF=$SDF_DIR/nom_tt_025C_1v80/${TOP}__nom_tt_025C_1v80.sdf ;;
  ss)   SDF=$SDF_DIR/nom_ss_100C_1v60/${TOP}__nom_ss_100C_1v60.sdf ;;
  ff)   SDF=$SDF_DIR/nom_ff_n40C_1v95/${TOP}__nom_ff_n40C_1v95.sdf ;;
  *) echo "corner phải là none|tt|ss|ff"; exit 2 ;;
esac
[ -z "$SDF" ] || [ -f "$SDF" ] || { echo "Không thấy SDF: $SDF"; exit 2; }

W=build/gls/$CORNER
mkdir -p "$W"
LIB=$W/work

# 1) Thư viện cell (một lần cho mỗi thư mục)
if [ ! -d "$LIB" ]; then
  vlib "$LIB"
  if [ "$CORNER" = none ]; then
    # Không SDF: mô hình chức năng, trễ đơn vị (giống gl_test của TT)
    vlog -work "$LIB" +define+FUNCTIONAL +define+UNIT_DELAY=#1 -timescale 1ns/1ps \
         "$SCL/primitives.v" "$SCL/sky130_fd_sc_hd.v" > "$W/vlog_cells.log"
  else
    # Có SDF: cần khối specify, không đặt FUNCTIONAL
    vlog -work "$LIB" +define+UNIT_DELAY=#0 -timescale 1ns/1ps \
         "$SCL/primitives.v" "$SCL/sky130_fd_sc_hd.v" > "$W/vlog_cells.log"
  fi
fi

# 2) Netlist + testbench
vlog -work "$LIB" -timescale 1ns/1ps "$NETLIST" > "$W/vlog_netlist.log"
vlog -work "$LIB" -sv -timescale 1ns/1ps $TB_FILES > "$W/vlog_tb.log"

# 3) Tắt kiểm tra timing chỉ ở tầng đồng bộ đầu tiên (flip-flop có Q nối lưới *meta_q):
#    tín hiệu vào không đồng bộ vi phạm setup/hold ở đây là đúng bản chất, không phải lỗi.
#    [CHƯA XÁC MINH] cú pháp tcheck_set trên phiên bản Questa của lab.
DO=$W/run.do
: > "$DO"
if [ "$CORNER" != none ]; then
  # Đọc từng khối instance "sky130_fd_sc_hd__<cell> <tên> ( ... );" và in tên nếu chân Q nối *meta_q
  awk '
    /^[ \t]*sky130_fd_sc_hd__[a-z0-9_]+[ \t]+[^ \t(]+/ { inst=$2; next_ok=1 }
    next_ok && /\.Q\([ \t]*\\[^ ]*meta_q[ \t]*\)/      { print inst; next_ok=0 }
    /\);[ \t]*$/                                        { next_ok=0 }
  ' "$NETLIST" \
    | while read -r inst; do
        echo "tcheck_set {$DUT/$inst} ALL OFF" >> "$DO"
      done
  echo "# $(grep -c tcheck_set "$DO" || true) flip-flop đồng bộ tầng 1 được tắt kiểm tra timing" >> "$DO"
fi
echo "run -all" >> "$DO"
echo "quit -f" >> "$DO"

# 4) Mô phỏng
SDF_ARG=""
[ -n "$SDF" ] && SDF_ARG="-sdftyp $DUT=$SDF +sdf_verbose"
vsim -c -lib "$LIB" $SDF_ARG -voptargs=+acc $VSIM_EXTRA "$TB_TOP" -do "$DO" | tee "$W/sim.log"

# 5) Tóm tắt
echo "== GLS corner=$CORNER =="
grep -E "Failed to find INSTANCE|Error|Fatal" "$W/sim.log" | head -5 || true
grep -cE "Timing violation|\\\$setuphold|\\\$recovery|\\\$removal|\\\$width" "$W/sim.log" \
  | sed 's/^/vi phạm timing check: /' || true
grep -E "PASS|FAIL" "$W/sim.log" | tail -25 || true
