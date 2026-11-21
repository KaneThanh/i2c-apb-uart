module tb_h_11 #(parameter bit AUTO_RUN = 1);
  timeunit 1ns;
  timeprecision 1ps;
  spi_env env();
  spi_unit_env unit_check();
  task automatic run;
    unit_check.reset();
    unit_check.verify(56'h04000000000000, 56'h00000000000100, 8);
    env.reset();
    env.verify_spi(56'h04000000000000, 56'h00000000000100);
  endtask
  initial if (AUTO_RUN) begin
    run();
    $display("PASS H-11");
    $finish;
  end
endmodule
