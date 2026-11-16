# =============================================================================
# SDC cho top APB: apb_uart   (pclk = 25 MHz, 40 ns)
# Dùng cho: STA G6 trên netlist Yosys (flow/sta/sta.tcl) và harden riêng apb_uart
# (flow/librelane_apb_uart/config.json, phương án D1-b). Top này không được tape-out.
# Trạng thái: đã chạy với flow/sta/sta.tcl 3 corner ngày 16/11/2026 [ĐÃ ĐO]; số trễ IO là [GIẢ ĐỊNH].
#
# [GIẢ ĐỊNH] Mạch ngoài: APB master cùng miền pclk (testbench hoặc bus):
#   - tín hiệu APB tới cổng muộn nhất 40 % chu kỳ sau sườn lên, sớm nhất 0,5 ns
#   - master cần prdata/pslverr/pready trước sườn lên kế tiếp 30 % chu kỳ
# Spec không quy định các số này; nêu rõ trong báo cáo G6.
# =============================================================================

proc env_or {name default} {
    if { [info exists ::env($name)] && $::env($name) ne "" } { return $::env($name) }
    return $default
}

set clk_period  [env_or CLOCK_PERIOD 40.0]
set clk_unc     [env_or CLOCK_UNCERTAINTY_CONSTRAINT 0.25]
set clk_unc_h   [env_or CLOCK_UNCERTAINTY_HOLD $clk_unc]    ;# xem 00_master_plan T08 lỗi (1)
set clk_tran    [env_or CLOCK_TRANSITION_CONSTRAINT 0.15]
set derate_pct  [env_or TIME_DERATING_CONSTRAINT 5.0]
set max_fanout  [env_or MAX_FANOUT_CONSTRAINT 10]
set max_tran    [env_or MAX_TRANSITION_CONSTRAINT 0.75]
set max_cap     [env_or MAX_CAPACITANCE_CONSTRAINT 0.2]
set out_load_ff [env_or OUTPUT_CAP_LOAD 33.442]
set drv_cell    [env_or SYNTH_DRIVING_CELL "sky130_fd_sc_hd__inv_2/Y"]

create_clock -name pclk -period $clk_period [get_ports pclk]
set_clock_uncertainty -setup $clk_unc   [get_clocks pclk]
set_clock_uncertainty -hold  $clk_unc_h [get_clocks pclk]
set_clock_transition  $clk_tran [get_clocks pclk]

set apb_in   [get_ports {psel penable pwrite paddr[*] pstrb[*] pwdata[*]}]
set apb_out  [get_ports {pready pslverr prdata[*]}]
set async_in [get_ports {rx cts_n}]
set uart_out [get_ports {tx rts_n irq}]
set rst_in   [get_ports presetn]

# APB: đồng bộ với pclk
set_input_delay  -max [expr { 0.40 * $clk_period }] -clock [get_clocks pclk] $apb_in
set_input_delay  -min 0.5                           -clock [get_clocks pclk] $apb_in
set_output_delay -max [expr { 0.30 * $clk_period }] -clock [get_clocks pclk] $apb_out
set_output_delay -min 0.0                           -clock [get_clocks pclk] $apb_out

# UART: bất đồng bộ, qua 2FF (REQ-IO-04). Hold tại tầng đầu không có ý nghĩa.
set_input_delay  [expr { 0.20 * $clk_period }] -clock [get_clocks pclk] $async_in
set_false_path -hold -from $async_in
set_output_delay [expr { 0.20 * $clk_period }] -clock [get_clocks pclk] $uart_out

# Reset bất đồng bộ: giữ ràng buộc để kiểm tra recovery/removal
set_input_delay  [expr { 0.20 * $clk_period }] -clock [get_clocks pclk] $rst_in

set drv_c [lindex [split $drv_cell "/"] 0]
set drv_p [lindex [split $drv_cell "/"] 1]
set_driving_cell -lib_cell $drv_c -pin $drv_p [concat $apb_in $async_in $rst_in]
set_driving_cell -lib_cell $drv_c -pin $drv_p [get_ports pclk]
set_load [expr { $out_load_ff / 1000.0 }] [all_outputs]

set_max_fanout      $max_fanout [current_design]
set_max_transition  $max_tran   [current_design]
set_max_capacitance $max_cap    [current_design]

set_timing_derate -early [expr { 1.0 - $derate_pct / 100.0 }]
set_timing_derate -late  [expr { 1.0 + $derate_pct / 100.0 }]

if { [env_or OPENLANE_SDC_IDEAL_CLOCKS 1] } {
    unset_propagated_clock [all_clocks]
} else {
    set_propagated_clock [all_clocks]
}
