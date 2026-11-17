module tb_t_1_1_1_3;
  timeunit 1ns;
  timeprecision 1ps;
  tb_h_08 #(.AUTO_RUN(0)) source_0();
  initial begin
    source_0.run();
    $display("PASS T-1.1.1.3");
    $finish;
  end
endmodule
