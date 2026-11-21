module tb_t_2_14_1_2;
  timeunit 1ns;
  timeprecision 1ps;
  tb_h_15 #(.AUTO_RUN(0)) source_0();
  initial begin
    source_0.run();
    $display("PASS T-2.14.1.2");
    $finish;
  end
endmodule
