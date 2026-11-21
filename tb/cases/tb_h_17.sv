module tb_h_17 #(parameter bit AUTO_RUN = 1);
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  task automatic run;
    env.reset();
    env.wr('h008, 3);
    env.check(env.rts_n === 0, "RX ready");
    fork
      env.send_rx('h55, 3);
      begin
        #6000ns;
        env.rd('h010, 'h09);
      end
    join
    env.wait_rx_ready();
    env.rd('h010, 3); env.rd('h004, 'h55);
    #80ns;
    env.check(env.rts_n === 0, "RTS after read");
    env.wr('h018, 2);
    env.send_rx('h55, 3);
    env.wait_rx_ready();
    #80ns;
    env.check(env.irq === 1, "IRQ on RX done");
    env.send_rx('haa, 3);
    env.rd('h010, 'h83); env.rd('h004, 'h55);
    #80ns;
    env.check({env.rts_n,env.irq} === 0, "RTS and IRQ after read");
  endtask
  initial if (AUTO_RUN) begin
    run();
    $display("PASS H-17");
    $finish;
  end
endmodule
