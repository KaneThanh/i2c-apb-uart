module spi_env;
  timeunit 1ns;
  timeprecision 1ps;
  logic clk = 0, rst_n = 1, ena = 1;
  bit reset_seen = 0;
  always @(negedge rst_n) reset_seen = 1;
  logic rx = 1, cts_n = 0, cs_n = 1, sclk = 0, mosi = 0;
  logic [2:0] unused_inputs = 0;
  wire [7:0] ui_in = {unused_inputs, mosi, sclk, cs_n, cts_n, rx};
  wire [7:0] uo_out, uio_out, uio_oe;
  wire tx = uo_out[0], rts_n = uo_out[1], miso = uo_out[2];
  wire tx_done = uo_out[3], rx_done = uo_out[4], parity_err = uo_out[5], irq = uo_out[6];

  tt_um_hust_apb_uart dut (
    .clk(clk), .rst_n(rst_n), .ena(ena), .ui_in(ui_in), .uo_out(uo_out),
    .uio_in(8'h00), .uio_out(uio_out), .uio_oe(uio_oe)
  );
  `include "uart_peer.svh"
  always #(CLK_NS / 2) clk = ~clk;
  initial #100ms $fatal(1, "%m: timeout");

  a14: assert property (@(posedge clk) disable iff (!reset_seen || !rst_n)
    cs_n[*3] |-> miso === 1'b0) else $fatal(1, "%m A-14");
  a15: assert property (@(posedge clk) disable iff (!reset_seen)
    {uio_oe, uio_out, uo_out[7]} === 17'h0) else $fatal(1, "%m A-15");

  covergroup spi_commands with function sample(logic [7:0] cmd, int clocks);
    option.per_instance = 1;
    writes: coverpoint cmd[3:0] iff (cmd[7] && cmd[6:4] == 0 && clocks == 56) {
      bins addresses[] = {0, 2, 3, 5, 6, 7};
    }
    reads: coverpoint cmd[3:0] iff (!cmd[7] && cmd[6:4] == 0 && clocks == 56) {
      bins addresses[] = {1, 4, 7};
    }
    invalid: coverpoint cmd[6:4] iff (clocks == 56) { bins invalid_command = {[1:7]}; }
    abort_write: coverpoint clocks iff (cmd[7]) { bins before_commit = {[8:47]}; }
    abort_read: coverpoint clocks iff (!cmd[7]) { bins after_commit = {[8:55]}; }
  endgroup
  spi_commands cg13 = new;

  task automatic reset;
    #1ns rst_n = 0;
    repeat (4) @(negedge clk);
    #1ns rst_n = 1;
    repeat (4) @(negedge clk);
  endtask

  task automatic exchange(input logic [55:0] request, output logic [55:0] response,
                           input int count = 56);
    response = '0;
    cs_n = 0;
    #(5 * CLK_NS);
    for (int i = 55; i >= 56-count; i--) begin
      mosi = request[i];
      #(5 * CLK_NS);
      response[i] = miso;
      sclk = 1;
      #(5 * CLK_NS);
      sclk = 0;
    end
    cg13.sample(request[55:48], count);
    cs_n = 1;
    #(5 * CLK_NS);
  endtask

  task automatic verify_spi(input logic [55:0] request, input logic [55:0] expected);
    logic [55:0] actual;
    exchange(request, actual);
    check(actual === expected,
          $sformatf("SB-10 MOSI=%014h MISO=%014h expected=%014h", request, actual, expected));
  endtask

  task automatic write_reg(input logic [3:0] index, input logic [31:0] data);
    verify_spi({8'h80 | {4'h0,index}, 8'h00, data, 8'h00}, 56'h0);
  endtask

  task automatic read_reg(input logic [3:0] index, input logic [31:0] data);
    verify_spi({4'h0,index,48'h0}, {16'h0,data,8'h0});
  endtask
endmodule
