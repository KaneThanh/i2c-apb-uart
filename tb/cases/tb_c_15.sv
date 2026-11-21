module tb_c_15;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  initial begin
    env.reset(); env.wr('h008, 3);
    env.check(env.rts_n === 0, "RTS ready");
    env.send_rx('h5a, 3);
    env.check(env.rts_n === 1, "RTS full");
    env.wr('h008, 'h43); #80ns;
    env.check(env.rts_n === 1, "RTS full and disabled");
    env.wr('h008, 3); #80ns;
    env.check(env.rts_n === 1, "RTS full after re-enable");
    env.rd('h004, 'h5a); #80ns;
    env.check(env.rts_n === 0, "RTS cleared");
    env.wr('h008, 'h43); #80ns;
    env.check(env.rts_n === 1, "RTS disabled and empty");
    $display("PASS C-15");
    $finish;
  end
endmodule
