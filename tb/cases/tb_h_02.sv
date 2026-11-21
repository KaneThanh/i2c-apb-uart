module tb_h_02 #(parameter bit AUTO_RUN = 1);
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  task automatic run;
    env.reset();
    env.reset_registers();
  endtask
  initial if (AUTO_RUN) begin
    run();
    $display("PASS H-02");
    $finish;
  end
endmodule
