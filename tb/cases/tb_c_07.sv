module tb_c_07;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  initial begin
    env.reset();
    env.wr('h008, 'h1b); env.wr('h018, 4);
    env.send_rx('ha5, 'h1b, 8680.0, 1, 1);
    env.rd('h010, 'h47); env.check(env.irq === 1, "Both errors assert IRQ");
    env.rd('h004, 'ha5); env.rd('h010, 1);
    env.check(env.irq === 0, "IRQ clears");
    $display("PASS C-07");
    $finish;
  end
endmodule
