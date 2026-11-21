module tb_t_2_8_1_1;
  timeunit 1ns;
  timeprecision 1ps;
  tb_h_04 #(.AUTO_RUN(0)) source_0();
  tb_h_03 #(.AUTO_RUN(0)) source_1();
  initial begin
    source_0.run();
    source_1.run();
    $display("PASS T-2.8.1.1");
    $finish;
  end
endmodule
