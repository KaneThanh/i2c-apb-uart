# =============================================================================
# STA một corner bằng OpenSTA (2.7.0 trong môi trường LibreLane 3.0.14).
# Trạng thái: đã chạy 16/11/2026 trên netlist Yosys của 2 top, 3 corner (make -C flow sta_pre) [ĐÃ ĐO].
#             Chế độ có SPEF (sau layout) [CHƯA XÁC MINH].
#
# Cách dùng (flow/Makefile gọi sẵn):
#   TOP=apb_uart NETLIST=build/syn/apb_uart/apb_uart.nl.v SDC=flow/constraints/apb_uart.sdc \
#   LIB=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ss_100C_1v60.lib \
#   CORNER=ss OUT=build/sta/apb_uart/ss OPENLANE_SDC_IDEAL_CLOCKS=1 \
#   sta -no_init -no_splash -exit flow/sta/sta.tcl
#
# Sau layout: NETLIST=runs/wokwi/final/nl/<top>.nl.v, SPEF=runs/wokwi/final/spef/nom/<top>.nom.spef,
#             OPENLANE_SDC_IDEAL_CLOCKS=0. (LibreLane đã tự chạy STA 9 corner; dùng script này để
#             kiểm tra chéo hoặc lấy báo cáo đường đi theo ý mình.)
# =============================================================================

proc need {name} {
    if { ![info exists ::env($name)] || $::env($name) eq "" } {
        puts "LỖI: chưa đặt biến môi trường $name"; exit 2
    }
    return $::env($name)
}

set top     [need TOP]
set netlist [need NETLIST]
set sdc     [need SDC]
set lib     [need LIB]
set corner  [need CORNER]
set out     [need OUT]
file mkdir $out

read_liberty $lib
read_verilog $netlist
link_design  $top
if { [info exists ::env(SPEF)] && $::env(SPEF) ne "" } {
    read_spef $::env(SPEF)
}
read_sdc $sdc

# --- kiểm tra ràng buộc ---
check_setup -verbose -unconstrained_endpoints -multiple_clock -no_clock -loops > $out/check_setup.rpt

# --- đường xấu nhất ---
report_checks -path_delay max -group_path_count 5 -sort_by_slack -format full_clock_expanded \
    -fields {slew capacitance fanout input_pin} -digits 3 > $out/max.rpt
report_checks -path_delay min -group_path_count 5 -sort_by_slack -format full_clock_expanded \
    -fields {slew capacitance fanout input_pin} -digits 3 > $out/min.rpt
# đường vào->ra tổ hợp spi_cs_n -> spi_miso (chỉ có ở top TT)
if { $top eq "tt_um_hust_apb_uart" } {
    report_checks -path_delay max -from [get_ports {ui_in[2]}] -to [get_ports {uo_out[2]}] \
        -format full -digits 3 > $out/cs_to_miso.rpt
}

# --- luật thiết kế ---
report_check_types -max_slew -max_capacitance -max_fanout -violators > $out/drv.rpt
# recovery/removal của reset bất đồng bộ
report_check_types -recovery -removal -violators > $out/recrem.rpt

# --- tóm tắt (1 dòng mỗi chỉ số, dễ chép vào báo cáo) ---
set f [open $out/summary.rpt w]
puts $f "top=$top corner=$corner netlist=$netlist"
close $f
report_worst_slack -max -digits 3 >> $out/summary.rpt
report_worst_slack -min -digits 3 >> $out/summary.rpt
report_tns -max -digits 3         >> $out/summary.rpt
report_tns -min -digits 3         >> $out/summary.rpt

if { $corner eq "tt" } {
    report_power > $out/power.rpt
}
puts "STA xong: $out/summary.rpt"
