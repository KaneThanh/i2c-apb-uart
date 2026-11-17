module tb_h_04 #(parameter bit AUTO_RUN = 1);
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  baud_env baud_check();
  task automatic run;
    baud_check.verify_ticks(16'h200e);
    env.reset();
    env.wr('h008, 3);
    env.wr('h014, 'h200e, 3);
    env.rd('h014, 'h200e);
    env.transmit_and_check('h55, 3, 226);
  endtask
  initial if (AUTO_RUN) begin
    run();
    $display("PASS H-04");
    $finish;
  end
endmodule
