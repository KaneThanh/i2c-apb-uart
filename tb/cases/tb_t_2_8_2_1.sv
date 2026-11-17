module tb_t_2_8_2_1;
  timeunit 1ns;
  timeprecision 1ps;
  tb_h_03 #(.AUTO_RUN(0)) source_0();
  initial begin
    source_0.run();
    $display("PASS T-2.8.2.1");
    $finish;
  end
endmodule
