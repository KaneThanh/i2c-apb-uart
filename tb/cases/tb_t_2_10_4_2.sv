module tb_t_2_10_4_2;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  localparam logic [7:0] DATA [4] = '{0,'hff,'ha5,'h5a};
  initial begin
    logic [4:0] cfg;
    env.reset();
    for (int n = 0; n < 4; n++)
      for (int p = 0; p < 3; p++)
        for (int s = 0; s < 2; s++) begin
          cfg = {p == 2, p != 0, s[0], n[1:0]};
          env.wr('h008, {27'h0,cfg});
          foreach (DATA[i]) begin
            env.receive_and_check(DATA[i], cfg, 8680.0/1.03);
            env.receive_and_check(DATA[i], cfg, 8680.0/0.97);
          end
        end
    $display("PASS T-2.10.4.2");
    $finish;
  end
endmodule
