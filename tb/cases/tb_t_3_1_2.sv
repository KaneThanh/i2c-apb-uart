module tb_t_3_1_2;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  initial begin
    env.reset(); env.wr('h008, 3); env.send_rx('h5a, 3);
    env.wr('h004, '1, 15, 1); env.wr('h004, 0, 0, 1);
    env.wr('h010, '1, 15, 1); env.wr('h010, 0, 0, 1);
    env.rd('h010, 3); env.rd('h004, 'h5a); env.rd('h010, 1);
    $display("PASS T-3.1.2");
    $finish;
  end
endmodule
