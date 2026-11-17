module tb_t_2_9_1_3;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  localparam logic [7:0] DATA [6] = '{0,1,'ha5,'h7f,'hff,'he5};
  initial begin
    logic [4:0] cfg;
    env.reset();
    for (int even_parity = 0; even_parity < 2; even_parity++) begin
      cfg = 5'h0b | (even_parity << 4);
      env.wr('h008, {27'h0,cfg});
      foreach (DATA[i]) env.transmit_and_check(DATA[i], cfg);
      for (int n = 0; n < 3; n++) begin
        cfg = 5'h08 | (even_parity << 4) | n;
        env.wr('h008, {27'h0,cfg});
        env.transmit_and_check('he5, cfg);
        env.transmit_and_check(env.masked_byte('he5, cfg), cfg);
      end
    end
    $display("PASS T-2.9.1.3");
    $finish;
  end
endmodule
