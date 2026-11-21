module tb_t_2_13_3_1;
  timeunit 1ns;
  timeprecision 1ps;
  tb_h_12 #(.AUTO_RUN(0)) source_0();
  initial begin
    source_0.run();
    $display("PASS T-2.13.3.1");
    $finish;
  end
endmodule
