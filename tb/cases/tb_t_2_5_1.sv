module tb_t_2_5_1;
  timeunit 1ns;
  timeprecision 1ps;
  tb_h_18 #(.AUTO_RUN(0)) source_0();
  initial begin
    source_0.run();
    $display("PASS T-2.5.1");
    $finish;
  end
endmodule
