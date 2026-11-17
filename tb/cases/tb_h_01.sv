module tb_h_01 #(parameter bit AUTO_RUN = 1);
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  task automatic run;
    env.reset();
    env.check({env.tx, env.rts_n, env.irq, env.pslverr, env.pready} === 5'b10001,
              "H-01 outputs after reset release");
  endtask
  initial if (AUTO_RUN) begin
    run();
    $display("PASS H-01");
    $finish;
  end
endmodule
