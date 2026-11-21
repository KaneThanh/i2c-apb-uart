module tb_h_18 #(parameter bit AUTO_RUN = 1);
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  task automatic irq_is(input logic value);
    #80ns;
    env.check(env.irq === value, "SB-07 IRQ truth table");
  endtask
  task automatic run;
    env.reset();
    env.wr('h008, 'h1b);
    irq_is(0);
    env.wr('h018, 1); irq_is(1);
    env.cts_n = 1;
    env.wr('h00c, 1); irq_is(0);
    env.wr('h018, 7); irq_is(0);
    env.wr('h018, 1);
    env.send_rx('h55,'h1b,8680.0,1,1); #8680ns;
    env.send_rx('haa,'h1b);
    env.rd('h010, 'hc6); irq_is(0);
    env.rd('h004, 'h55);
    env.wr('h018, 2);
    env.send_rx('h55,'h1b); irq_is(1);
    env.rd('h004, 'h55); irq_is(0);
    env.reset();
    env.wr('h008, 'h1b);
    env.wr('h018, 2); irq_is(0);
    env.wr('h018, 4);
    env.send_rx('h55,'h1b); irq_is(0);
    env.rd('h004, 'h55);
    env.send_rx('h55,'h1b,8680.0,1); irq_is(1);
    env.rd('h004, 'h55); irq_is(0);
    env.send_rx('h55,'h1b,8680.0,0,1); irq_is(1);
    env.rd('h004, 'h55); irq_is(0);
    env.send_rx('h55,'h1b); irq_is(0);
    env.send_rx('haa,'h1b); irq_is(1);
    env.rd('h004, 'h55); irq_is(0);
    env.cts_n = 0;
    env.wr('h00c, 1);
    env.wr('h018, 1); irq_is(0);
    #110000ns;
    irq_is(1);
  endtask
  initial if (AUTO_RUN) begin
    run();
    $display("PASS H-18");
    $finish;
  end
endmodule
