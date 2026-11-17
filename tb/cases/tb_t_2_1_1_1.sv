module tb_t_2_1_1_1;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  localparam logic [31:0] TX [5] = '{'ha5,'h55,'haa,'hff,0};
  localparam logic [31:0] CFG [5] = '{'h1b,0,'h55,'h2a,3};
  localparam logic [31:0] BAUD [4] = '{'hb028,1,'hffff,'h900d};
  localparam logic [31:0] IER [4] = '{5,2,7,0};
  logic [31:0] expected [7] = '{0,0,0,0,1,'h900d,0};
  task automatic write_and_compare(input int index, input logic [31:0] value);
    env.wr(12'(4*index), value, 15);
    expected[index] = value;
    if (index == 2) expected[4] = 1 | ((value & 'h60) >> 1);
    foreach (expected[i]) env.rd(12'(4*i), expected[i]);
  endtask
  initial begin
    env.reset();
    foreach (TX[i]) write_and_compare(0, TX[i]);
    foreach (CFG[i]) write_and_compare(2, CFG[i]);
    foreach (BAUD[i]) write_and_compare(5, BAUD[i]);
    foreach (IER[i]) write_and_compare(6, IER[i]);
    write_and_compare(2, 0);
    $display("PASS T-2.1.1.1");
    $finish;
  end
endmodule
