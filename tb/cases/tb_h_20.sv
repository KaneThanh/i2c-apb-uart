module tb_h_20;
  timeunit 1ns;
  timeprecision 1ps;
  spi_env env();
  initial begin
    #1ns env.rst_n = 0;
    #2ns;
    env.check((env.uo_out & 8'h7b) === 8'h0b, "Wrapper reset outputs");
    #100ns env.rst_n = 1;
    for (int i = 0; i < 8; i++) begin
      env.unused_inputs = i[2:0];
      repeat (4) @(negedge env.clk);
      env.check(env.uo_out === 8'h09, "Unused input changed idle behavior");
    end
    $display("PASS H-20");
    $finish;
  end
endmodule
