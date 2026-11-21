module tb_t_3_1_5;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  initial begin
    env.reset();
    env.wr('h014, 0, 3, 1); env.rd('h014, 'h900d);
    env.wr('h014, 0, 1, 1); env.rd('h014, 'h900d);
    env.wr('h014, 'h9000, 3, 1); env.rd('h014, 'h900d);
    env.wr('h014, 'h9100, 3); env.rd('h014, 'h9100);
    env.wr('h014, 0, 2, 1); env.rd('h014, 'h9100);
    env.wr('h014, 1, 1); env.rd('h014, 'h9101);
    env.wr('h014, 1, 3); env.rd('h014, 1);
    env.wr('h014, 'h900d, 3);
    $display("PASS T-3.1.5");
    $finish;
  end
endmodule
