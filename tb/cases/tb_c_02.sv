module tb_c_02;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  baud_env baud_check();
  initial begin
    baud_check.verify_ticks(16'hffff);
    env.reset();
    env.wr('h014, 'hffff, 3); env.rd('h014, 'hffff);
    env.transmit_and_check('h15, 0, 65535);
    env.wr('h014, 'h900d, 3);
    $display("PASS C-02");
    $finish;
  end
endmodule
