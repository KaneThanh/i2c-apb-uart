module tb_t_3_2_1_1;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  task automatic busy_legal;
    env.wr('h008, 'hff00, 2); env.wr('h008, 0, 0);
    env.wr('h014, 'hffff0000, 12); env.wr('h014, 0, 0);
  endtask
  task automatic check_access(input logic [31:0] status);
    env.wr('h018, 7); env.rd('h000, 'h42); env.rd('h004, 0); env.rd('h008, 3);
    env.rd('h00c, 0); env.rd('h010, status); env.rd('h014, 'h900d); env.rd('h018, 7);
  endtask
  initial begin
    env.reset(); env.wr('h008, 3);
    env.wr('h000, 'h42); check_access(1);
    fork
      env.send_rx('h5a, 3);
      begin
        #6500ns; check_access(9); busy_legal();
        fork
          env.expect_tx('h42, 3);
          begin env.wr('h00c, 1); busy_legal(); env.wr('h00c, 0); check_access(8); end
        join
      end
    join
    env.rd('h010, 3); env.rd('h004, 'h5a);
    env.cts_n = 1; #200ns;
    env.wr('h00c, 1); env.wr('h018, 7); env.rd('h010, 0);
    $display("PASS T-3.2.1.1");
    $finish;
  end
endmodule
