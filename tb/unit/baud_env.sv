module baud_env;
  timeunit 1ns;
  timeprecision 1ps;
  logic pclk = 0, presetn = 1, clr = 0, en = 0;
  logic [11:0] div_int = 1;
  logic [3:0] div_frac = 0;
  wire tick;
  baud_gen dut (.pclk(pclk), .presetn(presetn), .clr(clr), .en(en),
    .div_int(div_int), .div_frac(div_frac), .tick(tick));
  always #20ns pclk = ~pclk;
  task automatic verify_ticks(input logic [15:0] baud);
    realtime previous_tick;
    int gap, long_gaps;
    #1ns presetn = 0;
    repeat (2) @(negedge pclk);
    {div_frac,div_int} = baud;
    presetn = 1;
    clr = 1;
    @(negedge pclk);
    clr = 0;
    en = 1;
    do @(posedge pclk); while (tick !== 1'b1);
    previous_tick = $realtime;
    repeat (2) begin
      long_gaps = 0;
      repeat (16) begin
        do @(posedge pclk); while (tick !== 1'b1);
        gap = int'(($realtime - previous_tick) / 40.0);
        previous_tick = $realtime;
        if (gap == int'(div_int) + 1) long_gaps++;
        else if (gap != int'(div_int))
          $fatal(1, "%m: BAUD=%h illegal tick gap=%0d", baud, gap);
      end
      if (long_gaps != int'(div_frac))
        $fatal(1, "%m: BAUD=%h long gaps=%0d expected=%0d", baud, long_gaps, div_frac);
    end
    @(negedge pclk);
    en = 0;
  endtask
endmodule
