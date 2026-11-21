module tb_c_01;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  initial begin
    // ASSUMPTION: BAUD div_int=1 is legal (SPEC 16.2).
    env.reset();
    env.wr('h008, 3); env.wr('h014, 1, 3); env.rd('h014, 1);
    env.transmit_and_check('h55, 3, 16);
    env.wr('h014, 'h900d, 3);
    $display("PASS C-01");
    $finish;
  end
endmodule
