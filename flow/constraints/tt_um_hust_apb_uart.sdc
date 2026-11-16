# =============================================================================
# SDC cho top Tiny Tapeout: tt_um_hust_apb_uart   (pclk = clk = 25 MHz, 40 ns)
#
# Dùng ở hai nơi, cùng một file:
#   1. LibreLane:  PNR_SDC_FILE và SIGNOFF_SDC_FILE trong src/config.json
#      (đã chạy full flow LibreLane 3.0.14 ngày 16/11/2026 với file này)
#   2. OpenSTA riêng: flow/sta/sta.tcl (netlist Yosys trước layout, hoặc netlist + SPEF sau layout)
#
# Giá trị mặc định bên dưới bằng mặc định của LibreLane 3.0.14 cho sky130
# (config/pdk_compat.py và libs.tech/openlane/sky130_fd_sc_hd/config.tcl).
# Khi chạy trong LibreLane, biến môi trường của flow được ưu tiên.
# =============================================================================

proc env_or {name default} {
    if { [info exists ::env($name)] && $::env($name) ne "" } { return $::env($name) }
    return $default
}

set clk_period   [env_or CLOCK_PERIOD 40.0]                 ;# ns  (REQ-GEN-01: 25 MHz)
set clk_unc      [env_or CLOCK_UNCERTAINTY_CONSTRAINT 0.25] ;# ns  jitter + skew chưa biết
set clk_tran     [env_or CLOCK_TRANSITION_CONSTRAINT 0.15]  ;# ns
set derate_pct   [env_or TIME_DERATING_CONSTRAINT 5.0]      ;# %   OCV early/late
set io_pct       [env_or IO_DELAY_CONSTRAINT 20.0]          ;# %   chu kỳ dành cho mạch ngoài
set max_fanout   [env_or MAX_FANOUT_CONSTRAINT 10]
set max_tran     [env_or MAX_TRANSITION_CONSTRAINT 0.75]    ;# ns
set max_cap      [env_or MAX_CAPACITANCE_CONSTRAINT 0.2]    ;# pF
set out_load_ff  [env_or OUTPUT_CAP_LOAD 33.442]            ;# fF  (chân A của inv_16)
set drv_cell     [env_or SYNTH_DRIVING_CELL "sky130_fd_sc_hd__inv_2/Y"]

# ---- 1. Đồng hồ -------------------------------------------------------------
create_clock -name clk -period $clk_period [get_ports clk]
set_clock_uncertainty $clk_unc  [get_clocks clk]
set_clock_transition  $clk_tran [get_clocks clk]

# ---- 2. Nhóm cổng -----------------------------------------------------------
# Đầu vào không đồng bộ, đều qua 2 flip-flop đồng bộ trong RTL (REQ-IO-04, REQ-SPI-11):
#   ui_in[0] rx   ui_in[1] cts_n   ui_in[2] spi_cs_n   ui_in[3] spi_sclk   ui_in[4] spi_mosi
set async_in  [get_ports {ui_in[0] ui_in[1] ui_in[2] ui_in[3] ui_in[4]}]
# Đầu vào không dùng trong RTL (chân scan dự phòng, uio, ena)
set unused_in [get_ports {ui_in[5] ui_in[6] ui_in[7] uio_in[*] ena}]
set rst_in    [get_ports rst_n]
set all_out   [all_outputs]

# ---- 3. Trễ vào / ra --------------------------------------------------------
set in_dly  [expr { $clk_period * $io_pct / 100.0 }]
set out_dly [expr { $clk_period * $io_pct / 100.0 }]

set_input_delay  $in_dly  -clock [get_clocks clk] $async_in
set_input_delay  $in_dly  -clock [get_clocks clk] $unused_in
# rst_n: giữ ràng buộc để STA kiểm tra recovery/removal của reset bất đồng bộ.
# Trên bo mạch RP2040 nhả rst_n không theo pha clk (xem research_01 §5, rủi ro R7).
set_input_delay  $in_dly  -clock [get_clocks clk] $rst_in
set_output_delay $out_dly -clock [get_clocks clk] $all_out

# ---- 4. Ngoại lệ ------------------------------------------------------------
# Hold tại tầng đồng bộ đầu tiên của tín hiệu bất đồng bộ không có ý nghĩa
# (pha của rx/cts_n/SPI so với clk là bất kỳ); bộ đồng bộ 2FF xử lý metastability.
# Setup vẫn được giữ để đường tổ hợp ui_in[2] (spi_cs_n) -> uo_out[2] (spi_miso) có ràng buộc.
set_false_path -hold -from $async_in

# ---- 5. Môi trường điện -----------------------------------------------------
set drv_c [lindex [split $drv_cell "/"] 0]
set drv_p [lindex [split $drv_cell "/"] 1]
set_driving_cell -lib_cell $drv_c -pin $drv_p [concat $async_in $unused_in $rst_in]
set_driving_cell -lib_cell $drv_c -pin $drv_p [get_ports clk]
set_load [expr { $out_load_ff / 1000.0 }] $all_out

# ---- 6. Luật thiết kế -------------------------------------------------------
set_max_fanout      $max_fanout [current_design]
set_max_transition  $max_tran   [current_design]
set_max_capacitance $max_cap    [current_design]

# ---- 7. OCV -----------------------------------------------------------------
set_timing_derate -early [expr { 1.0 - $derate_pct / 100.0 }]
set_timing_derate -late  [expr { 1.0 + $derate_pct / 100.0 }]

# ---- 8. Đồng hồ lý tưởng hay đã có cây đồng hồ -------------------------------
# LibreLane đặt OPENLANE_SDC_IDEAL_CLOCKS=1 trước CTS và =0 sau CTS.
# Chạy OpenSTA riêng: đặt 1 cho netlist Yosys, 0 cho netlist sau layout.
if { [env_or OPENLANE_SDC_IDEAL_CLOCKS 0] } {
    unset_propagated_clock [all_clocks]
} else {
    set_propagated_clock [all_clocks]
}
