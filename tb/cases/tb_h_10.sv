module tb_h_10 #(parameter bit AUTO_RUN = 1);
  timeunit 1ns;
  timeprecision 1ps;
  spi_env env();
  spi_unit_env unit_check();
  task automatic run;
    unit_check.reset();
    unit_check.verify(56'h85000000900d00, 56'h0, 48);
    env.reset();
    repeat (4) begin #200ns env.sclk = ~env.sclk; end
    env.check(env.miso === 0, "MISO while deselected");
    env.verify_spi(56'h85000000900d00, 56'h0);
    env.read_reg(5, 'h900d);
  endtask
  initial if (AUTO_RUN) begin
    run();
    $display("PASS H-10");
    $finish;
  end
endmodule
