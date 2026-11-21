module tb_h_08 #(parameter bit AUTO_RUN = 1);
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  regs_env regs_check();
  task automatic run;
    regs_check.baud_commit();
    env.reset();
    env.wr('h014, 'h900d, 'hf);
    env.rd('h014, 'h900d);
    env.rd('h010, 1);
    env.wr('h020, 'h55, 'hf, 1);
    env.reset_registers();
    env.wr('h014, 'hb028, 'hf);
    env.rd('h014, 'hb028);
    env.wr('h014, 'h900d, 'hf);
    env.rd('h014, 'h900d);
  endtask
  initial if (AUTO_RUN) begin
    run();
    $display("PASS H-08");
    $finish;
  end
endmodule
