module tb_t_3_3_3;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  initial begin
    env.reset(); env.wr('h008, 3);
    env.send_rx('h11, 3); env.send_rx('h22, 3);
    env.rd('h010, 'h83); env.check(env.rts_n === 1, "RTS remains full");
    env.rd('h004, 'h11); env.rd('h010, 1); env.check(env.rts_n === 0, "RTS cleared");
    env.receive_and_check('h33, 3);
    env.wr('h018, 4);
    env.send_rx('h11, 3); env.send_rx('h22, 3);
    env.rd('h010, 'h83); env.check(env.irq === 1, "Overrun IRQ");
    env.rd('h004, 'h11); env.rd('h010, 1); env.check(env.irq === 0, "Overrun IRQ cleared");
    $display("PASS T-3.3.3");
    $finish;
  end
endmodule
