module tb_t_3_3_2_1;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  initial begin
    env.reset(); env.wr('h008, 3); env.rd('h010, 1);
    env.send_rx('h41, 3, 8680.0, 0, 1);
    env.rd('h010, 'h43); env.rd('h004, 'h41); env.rd('h010, 1);
    $display("PASS T-3.3.2.1");
    $finish;
  end
endmodule
