#!/usr/bin/env bash
# Tổng hợp Yosys cho sky130_fd_sc_hd, dùng cho G4 (netlist), STA trước layout (G6) và LEC (G6).
# Cách dùng:  synth.sh <top> <thư mục ra> <file rtl...>
# Biến môi trường (flow/Makefile đặt sẵn): YOSYS, LIB_TT, EXCLUDE_FILES, CLOCK_PERIOD_PS
#
# Đã chạy ngày 16/11/2026 (Yosys 0.71) trên cả 2 top:
#   apb_uart             767 cell,  8 961 µm², 130 FF, 0 latch
#   tt_um_hust_apb_uart  927 cell, 11 337 µm², 188 FF, 0 latch
# Lưu ý: bản YoWASP (pip install yowasp-yosys) chỉ thấy thư mục hiện hành và thư mục con,
# nên mọi đường dẫn phải nằm dưới thư mục chạy lệnh.
set -euo pipefail

TOP=$1; OUT=$2; shift 2
RTL="$*"
: "${YOSYS:=yosys}"
: "${LIB_TT:?chưa đặt LIB_TT (liberty tt_025C_1v80)}"
: "${CLOCK_PERIOD_PS:=40000}"
: "${EXCLUDE_FILES:=}"

mkdir -p "$OUT"

# Cell mà LibreLane cấm dùng khi tổng hợp (no_synth.cells) và cell lỗi DRC (drc_exclude.cells).
# Dùng cùng danh sách để netlist G4 gần với netlist của bước layout.
DONT_USE=""
for f in $EXCLUDE_FILES; do
  [ -f "$f" ] || { echo "CẢNH BÁO: không thấy $f" >&2; continue; }
  while read -r c; do
    [ -n "$c" ] && DONT_USE="$DONT_USE -dont_use $c"
  done < <(grep -v '^#' "$f" | tr -d '\r' | sort -u)
done

cat > "$OUT/synth.ys" << EOF
# Sinh tự động bởi flow/synth/synth.sh — đừng sửa tay
read_verilog $RTL
hierarchy -check -top $TOP

# REQ-RTL-03: không có latch sau proc. Lệnh dưới dừng với lỗi nếu có.
proc
tee -o $OUT/latch_check.rpt select -count t:\$dlatch t:\$adlatch t:\$dlatchsr
select -assert-none t:\$dlatch t:\$adlatch t:\$dlatchsr

tee -o $OUT/check_rtl.rpt check
synth -top $TOP -flatten

dfflibmap -liberty $LIB_TT $DONT_USE
abc -liberty $LIB_TT -D $CLOCK_PERIOD_PS $DONT_USE
opt_clean -purge
hilomap -hicell sky130_fd_sc_hd__conb_1 HI -locell sky130_fd_sc_hd__conb_1 LO
setundef -zero
splitnets
opt_clean -purge
insbuf -buf sky130_fd_sc_hd__buf_2 A X

# Không còn cell nội bộ của Yosys (chưa ánh xạ) và không còn lỗi kết nối
select -assert-none t:\$*
read_liberty -lib -ignore_miss_dir -setattr blackbox $LIB_TT
tee -o $OUT/check_netlist.rpt check -assert
tee -o $OUT/stat.rpt stat -liberty $LIB_TT
write_verilog -noattr -noexpr -nohex -nodec $OUT/$TOP.nl.v
EOF

"$YOSYS" -q -l "$OUT/yosys.log" -s "$OUT/synth.ys"

# Cảnh báo nếu Yosys mã hóa lại FSM (làm hỏng ghép tên của eqy, xem research_02 §1.1)
if grep -q "Recoding FSM" "$OUT/yosys.log"; then
  echo "CẢNH BÁO: Yosys đã mã hóa lại FSM:" >&2
  grep "Recoding FSM" "$OUT/yosys.log" >&2
  echo "  -> thêm (* fsm_encoding = \"none\" *) cho thanh ghi trạng thái trước khi chạy LEC." >&2
fi

echo "== $TOP =="
grep -E "Chip area|cells$" "$OUT/stat.rpt" | head -3 || true
grep -cE "sky130_fd_sc_hd__(df|sdf|edf)" "$OUT/$TOP.nl.v" | sed 's/^/flip-flop: /'
echo "Netlist: $OUT/$TOP.nl.v"
