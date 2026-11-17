module tb_c_06;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  initial begin
    env.reset();
    env.wr('h008, 3); env.wr('h000, 'h55);
    for (int k = -2; k <= 2; k++) begin
      env.cts_n = 1; #200ns;
      @(posedge env.pclk);
      fork
        env.expect_tx('h55, 3);
        begin
          #81ns;
          env.wr('h00c, 1);
          env.rd('h010, 0);
        end
        begin
          realtime released_at;
          #((4+k)*40ns);
          env.cts_n <= 0;
          released_at = $realtime;
          @(negedge env.tx);
          if (k >= 0)
            env.check($realtime - released_at >= 80.0, "CTS edge to start timing");
        end
      join
      env.rd('h010, 1);
      repeat (2200) begin
        @(negedge env.pclk); env.check(env.tx === 1, "Duplicate TX");
      end
    end
    $display("PASS C-06");
    $finish;
  end
endmodule
