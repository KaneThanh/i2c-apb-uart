module tb_t_2_3_1_1;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  initial begin
    env.reset(); env.wr('h008, 3); env.wr('h000, 'h41);
    env.wr('h00c, 0); env.wr('h00c, 1, 14);
    repeat (2300) begin @(negedge env.pclk); env.check(env.tx === 1, "Unexpected start"); end
    fork
      env.expect_tx('h41, 3);
      begin env.wr('h00c, 1); env.rd('h00c, 0); env.rd('h010, 0); end
    join
    env.rd('h010, 1); env.transmit_and_check('h42, 3);
    repeat (2300) begin @(negedge env.pclk); env.check(env.tx === 1, "Extra TX frame"); end
    $display("PASS T-2.3.1.1");
    $finish;
  end
endmodule
