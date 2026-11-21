module tb_t_2_9_3_1;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  initial begin
    env.reset(); env.cts_n = 1; env.wr('h008, 3);
    env.wr('h000, 'h55); env.wr('h00c, 1); env.rd('h010, 0);
    env.wr('h000, 'h7f, 1, 1); env.wr('h00c, 1, 1, 1); env.wr('h008, 'h1b, 1, 1);
    repeat (3000) begin @(negedge env.pclk); env.check(env.tx === 1, "CTS hold"); end
    fork
      env.expect_tx('h55, 3);
      begin
        realtime start_at;
        #1ns;
        start_at = $realtime; env.cts_n = 0;
        @(negedge env.tx);
        env.check($realtime - start_at >= 80.0, "CTS path too short");
        #8680ns env.cts_n = 1;
      end
    join
    env.rd('h010, 1);
    $display("PASS T-2.9.3.1");
    $finish;
  end
endmodule
