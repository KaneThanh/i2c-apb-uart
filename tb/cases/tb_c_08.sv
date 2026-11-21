module tb_c_08;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  initial begin
    env.reset();
    env.wr('h008, 3);
    fork
      env.transmit_and_check('h41, 3);
      env.send_rx('h5a, 3);
      begin
        #6500ns;
        // Wait for the stimulus BFM to finish its first two APB writes.
        env.rd('h010, 8);
        env.wr('h010, '1, 'hf, 1); env.wr('h004, 0, 'hf, 1);
        env.wr('h01c, 1, 'hf, 1); env.wr('h0fc, 1, 1, 1); env.wr('h009, 3, 'hf, 1);
      end
    join
    env.rd('h000, 'h41); env.rd('h008, 3); env.rd('h00c, 0); env.rd('h010, 3);
    env.rd('h004, 'h5a); env.rd('h014, 'h900d); env.rd('h018, 0);
    $display("PASS C-08");
    $finish;
  end
endmodule
