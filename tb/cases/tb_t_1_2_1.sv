module tb_t_1_2_1;
  timeunit 1ns;
  timeprecision 1ps;
  tb_h_01 #(.AUTO_RUN(0)) source_0();
  initial begin
    source_0.run();
    $display("PASS T-1.2.1");
    $finish;
  end
endmodule
