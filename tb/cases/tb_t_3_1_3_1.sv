module tb_t_3_1_3_1;
  timeunit 1ns;
  timeprecision 1ps;
  tb_h_09 #(.AUTO_RUN(0)) source_0();
  initial begin
    source_0.run();
    $display("PASS T-3.1.3.1");
    $finish;
  end
endmodule
