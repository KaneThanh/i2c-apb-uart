module tb_h_14 #(parameter bit AUTO_RUN = 1);
  timeunit 1ns;
  timeprecision 1ps;
  spi_env env();
  task automatic run;
    env.reset();
    env.write_reg(2, 3);
    env.check(env.irq === 0, "IRQ after CFG");
    env.write_reg(5, 'h900d);
    env.read_reg(4, 1);
    env.write_reg(0, 'h41);
    fork
      env.expect_tx('h41, 3);
      begin
        env.write_reg(3, 1);
        env.check(env.tx_done === 0, "TX must be active");
        env.write_reg(6, 1);
        env.check(env.irq === 0, "IRQ while TX active");
      end
    join
    #80ns;
    env.check({env.tx_done,env.irq} === 2'b11, "TX complete IRQ");
    env.read_reg(4, 1);
    env.write_reg(0, 'h42);
    env.write_reg(3, 1);
    env.check({env.tx_done,env.irq} === 2'b00, "New TX clears IRQ");
  endtask
  initial if (AUTO_RUN) begin
    run();
    $display("PASS H-14");
    $finish;
  end
endmodule
