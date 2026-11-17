module tb_t_2_2_2_2;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  initial begin
    env.reset();
    env.wr('h008, 'h43); #80ns;
    fork
      env.send_rx('h5a, 3);
      repeat (100) begin env.rd('h010, 'h21); env.check(env.rts_n === 1, "RX disabled RTS"); end
    join
    env.rd('h010, 'h21); env.rd('h004, 0);
    env.wr('h008, 3); #80ns;
    env.check(env.rts_n === 0, "RX re-enabled");
    env.send_rx('h5a, 3);
    env.check(env.rts_n === 1, "RX completed");
    env.rd('h010, 3); env.rd('h004, 'h5a);
    $display("PASS T-2.2.2.2");
    $finish;
  end
endmodule
