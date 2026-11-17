module tb_c_03;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  initial begin
    env.reset();
    env.wr('h008, 3);
    env.rx = 0; #260400ns;
    env.rd('h010, 'h43); env.rd('h004, 0);
    #86800ns;
    env.rd('h010, 1);
    env.rx = 1; #17360ns;
    env.receive_and_check('h55, 3);
    $display("PASS C-03");
    $finish;
  end
endmodule
