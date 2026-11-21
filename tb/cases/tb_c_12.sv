module tb_c_12;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env #(.CORE(1)) env();

  task automatic request;
    @(negedge env.pclk);
    env.psel = 1; env.penable = 0; env.pwrite = 1;
    env.paddr = 'h00c; env.pstrb = 1; env.pwdata = 1;
    @(negedge env.pclk);
    env.penable = 1;
    @(posedge env.pclk);
    env.check(!$isunknown(env.stat_tx_done), "SB-06 unknown tx_done");
    env.check(env.pslverr === !env.stat_tx_done, "SB-02 start_tx race");
    #1ns;
    env.psel = 0; env.penable = 0;
  endtask

  initial begin
    realtime started_at, done_latency;
    int starts;
    bit accepted;
    env.reset();
    env.wr('h008, 3); env.wr('h000, 'h55);
    fork
      env.wr('h00c, 1);
      begin
        @(negedge env.tx);
        started_at = $realtime;
        @(posedge env.stat_tx_done);
        done_latency = $realtime - started_at;
        env.check(done_latency >= 86800.0 && done_latency <= 86880.0,
                  "SB-06 tx_done outside stop-bit completion window");
      end
    join

    for (int k = -3; k <= 3; k++) begin
      env.reset();
      env.wr('h008, 3); env.wr('h000, 'h55);
      starts = 0;
      fork
        forever begin
          @(negedge env.tx);
          if (env.tx === 1'b0) starts++;
        end
        begin
          fork
            env.expect_tx('h55, 3, 217, 0);
            begin
              @(negedge env.tx);
              // Anchor before the two APB phases, just after a pclk rising edge.
              #(done_latency + (k-2)*40.0 + 1.0);
              fork
                request();
                begin
                  wait (env.psel && env.penable);
                  @(posedge env.pclk);
                  accepted = (env.pslverr === 1'b0);
                end
              join
            end
            env.wr('h00c, 1);
          join
          repeat (2300) @(posedge env.pclk);
        end
      join_any
      disable fork;
      // 8N1 0x55 has five falling edges per frame including the start bit.
      env.check(starts == (accepted ? 10 : 5), "SB-04 unexpected frame count");
      env.rd('h010, 1);
    end
    $display("PASS C-12");
    $finish;
  end
endmodule
