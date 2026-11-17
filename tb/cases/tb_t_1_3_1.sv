module tb_t_1_3_1;
  timeunit 1ns;
  timeprecision 1ps;
  spi_env env();
  initial begin
    env.reset();
    env.check({env.uio_oe,env.uio_out,env.uo_out[7]} === 17'h0, "Wrapper static pins");
    env.write_reg(2, 3); env.send_rx('h5a, 3);
    env.check({env.rx_done,env.rts_n} === 2'b11, "Wrapper RX pins");
    env.read_reg(1, 'h5a);
    env.write_reg(2, 'h0b); env.send_rx('h5a, 'h0b, 8680.0, 1);
    env.check(env.parity_err === 1, "Wrapper parity pin");
    env.read_reg(4, 7); env.read_reg(1, 'h5a);
    env.write_reg(2, 3);
    env.cts_n = 1; env.write_reg(0, 'h41); env.write_reg(3, 1);
    env.check({env.tx,env.tx_done} === 2'b10, "Wrapper CTS blocks start");
    env.write_reg(6, 1);
    fork
      env.expect_tx('h41, 3);
      begin #1ns; env.cts_n = 0; end
    join
    #80ns;
    env.check(env.irq === 1, "Wrapper IRQ pin");
    $display("PASS T-1.3.1");
    $finish;
  end
endmodule
