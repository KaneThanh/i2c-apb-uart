module tb_h_06 #(parameter bit AUTO_RUN = 1);
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  localparam logic [7:0] DATA [4] = '{8'h00, 8'hff, 8'ha5, 8'h5a};
  task automatic run;
    logic [4:0] cfg;
    env.reset();
    for (int n = 0; n < 4; n++)
      for (int p = 0; p < 3; p++)
        for (int s = 0; s < 2; s++) begin
          cfg = {p == 2, p != 0, s[0], n[1:0]};
          env.wr('h008, {27'h0,cfg});
          foreach (DATA[i]) begin
            env.receive_and_check(DATA[i], cfg, 8680.0/1.02);
            env.receive_and_check(DATA[i], cfg, 8680.0/0.98);
          end
        end
  endtask
  initial if (AUTO_RUN) begin
    run();
    $display("PASS H-06");
    $finish;
  end
endmodule
