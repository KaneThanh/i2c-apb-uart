module tb_t_2_9_1_2;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  initial begin
    env.reset();
    for (int n = 0; n < 3; n++) begin
      env.wr('h008, n); env.wr('h000, 'he0); env.rd('h000, 'he0);
      env.transmit_and_check('he0, n[4:0]); env.rd('h000, 'he0);
    end
    env.wr('h008, 0); env.transmit_and_check('hff, 0); env.rd('h000, 'hff);
    $display("PASS T-2.9.1.2");
    $finish;
  end
endmodule
