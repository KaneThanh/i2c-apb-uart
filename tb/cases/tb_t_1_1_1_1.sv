module tb_t_1_1_1_1;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  task automatic sweep(input logic [31:0] stat_expected, input bit tx_active);
    env.rd('h000, 'h41); env.rd('h004, 0); env.rd('h008, 3); env.rd('h00c, 0);
    env.rd('h010, stat_expected); env.rd('h014, 'h900d); env.rd('h018, 0);
    env.wr('h000, 'h41, 1, tx_active); env.wr('h004, 0, 1, 1);
    env.wr('h008, 3, 0); env.wr('h00c, 0); env.wr('h010, 0, 0, 1);
    env.wr('h014, 0, 0); env.wr('h018, 0);
  endtask
  initial begin
    env.reset(); env.wr('h008, 3); env.wr('h000, 'h41);
    sweep(1, 0); env.wr('h020, 0, 'hf, 1);
    env.cts_n = 1; #200ns; env.wr('h00c, 1);
    sweep(0, 1);
    env.cts_n = 0; #88000ns;
    fork
      env.send_rx('h5a, 3);
      begin #6500ns; sweep(9, 0); end
    join
    env.rd('h004, 'h5a);
    $display("PASS T-1.1.1.1");
    $finish;
  end
endmodule
