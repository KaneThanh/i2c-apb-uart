module tb_t_2_10_3_2;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  regs_env regs_check();
  initial begin
    // ASSUMPTION: reading RXDATA keeps the last byte and clears only status.
    env.reset(); env.wr('h008, 'h1b);
    env.send_rx('h41, 'h1b, 8680.0, 1, 1); #8680ns;
    env.send_rx('h22, 'h1b);
    repeat (3) env.rd('h010, 'hc7);
    env.rd('h004, 'h41); env.rd('h010, 1);
    env.check(env.rts_n === 0, "RTS after read");
    env.rd('h004, 'h41);
    fork
      env.send_rx('h77, 'h1b);
      begin #7000ns; env.rd('h004, 'h41); env.rd('h010, 9); end
    join
    env.rd('h010, 3); env.rd('h004, 'h77);
    regs_check.read_collision();
    $display("PASS T-2.10.3.2");
    $finish;
  end
endmodule
