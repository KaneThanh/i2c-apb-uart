module tb_t_3_3_1 #(parameter bit AUTO_RUN = 1);
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  task automatic run;
    logic [4:0] cfg;
    env.reset(); env.wr('h018, 4);
    for (int n = 0; n < 4; n++)
      for (int p = 0; p < 2; p++) begin
        cfg = 5'h08 | (p << 4) | n;
        env.wr('h008, {27'h0,cfg});
        env.send_rx('ha5, cfg, 8680.0, 1); env.rd('h010, 7);
        env.check(env.irq === 1, "Parity IRQ");
        env.rd('h004, {24'h0,env.masked_byte('ha5, cfg)}); env.rd('h010, 1);
        env.check(env.irq === 0, "Parity IRQ cleared");
        env.send_rx('ha5, cfg); env.rd('h010, 3);
        env.check(env.irq === 0, "No parity IRQ");
        env.rd('h004, {24'h0,env.masked_byte('ha5, cfg)});
      end
  endtask
  initial if (AUTO_RUN) begin
    run();
    $display("PASS T-3.3.1");
    $finish;
  end
endmodule
