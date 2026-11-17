module tb_c_10;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  initial begin
    env.reset();
    env.wr('h018, 2);
    env.wr('h018, 'h700, 2); env.rd('h018, 2);
    env.check(env.irq === 0, "RX IRQ must stay low");
    env.wr('h018, '1, 14); env.rd('h018, 2);
    env.wr('h018, 'hfffffff8); env.rd('h018, 0);
    env.check(env.irq === 0, "RFU must not enable IRQ");
    env.wr('h018, 'hff); env.rd('h018, 7);
    env.check(env.irq === 1, "TX done IRQ");
    $display("PASS C-10");
    $finish;
  end
endmodule
