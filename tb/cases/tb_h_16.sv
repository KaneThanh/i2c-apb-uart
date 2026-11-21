module tb_h_16 #(parameter bit AUTO_RUN = 1);
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  task automatic run;
    env.reset();
    env.wr('h008, 3);
    for (int enable_irq = 0; enable_irq < 2; enable_irq++) begin
      env.wr('h018, enable_irq); #80ns;
      env.check(env.irq === enable_irq[0], "TX idle IRQ follows IER");
      env.cts_n = 1;
      env.wr('h000, 'h55);
      env.wr('h00c, 1);
      env.rd('h010, 0);
      env.check(env.irq === 0, "IRQ while TX waiting");
      repeat (500) begin
        @(negedge env.pclk);
        env.check(env.tx === 1, "A-09 CTS wait");
      end
      #1ns;
      fork
        env.expect_tx('h55, 3);
        begin
          realtime released_at;
          released_at = $realtime;
          env.cts_n = 0;
          @(negedge env.tx);
          env.check($realtime - released_at >= 80.0, "A-10 CTS synchronization");
          #40000ns env.cts_n = 1;
        end
      join
      #80ns;
      env.check(env.irq === enable_irq[0], "IRQ on TX completion");
      env.rd('h010, 1);
    end
  endtask
  initial if (AUTO_RUN) begin
    run();
    $display("PASS H-16");
    $finish;
  end
endmodule
