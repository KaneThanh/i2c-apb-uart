module tb_h_15 #(parameter bit AUTO_RUN = 1);
  timeunit 1ns;
  timeprecision 1ps;
  spi_env env();
  task automatic run;
    env.reset();
    env.write_reg(2, 3);
    env.write_reg(5, 'h900d);
    env.write_reg(6, 2);
    env.check({env.irq,env.rts_n} === 2'b00, "RX idle");
    env.send_rx('h5a, 3);
    for (int i = 0; i < 113 && {env.rx_done,env.rts_n,env.irq} !== 3'b111; i++)
      @(negedge env.clk);
    env.check({env.rx_done,env.rts_n,env.irq} === 3'b111, "RX complete");
    env.read_reg(4, 3);
    env.read_reg(1, 'h5a);
    env.check({env.rx_done,env.rts_n,env.irq} === 3'b000, "RXDATA read clears flags");
  endtask
  initial if (AUTO_RUN) begin
    run();
    $display("PASS H-15");
    $finish;
  end
endmodule
