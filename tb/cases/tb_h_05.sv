module tb_h_05 #(parameter bit AUTO_RUN = 1);
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  task automatic run;
    logic [4:0] cfg;
    env.reset();
    for (int n = 0; n < 4; n++)
      for (int p = 0; p < 3; p++)
        for (int s = 0; s < 2; s++) begin
          cfg = {p == 2, p != 0, s[0], n[1:0]};
          env.wr('h008, {27'h0,cfg});
          env.rd('h008, {27'h0,cfg});
          env.transmit_and_check('hA5, cfg);
          env.rd('h000, 'ha5);
          env.rd('h010, 1);
          env.receive_and_check('hA5, cfg);
          env.receive_and_check('hA4, cfg);
        end
  endtask
  initial if (AUTO_RUN) begin
    run();
    $display("PASS H-05");
    $finish;
  end
endmodule
