module tb_t_1_1_2_1;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  task automatic no_lane;
    env.wr('h000, '1, 0); env.wr('h008, '1, 0); env.wr('h00c, 'h101, 0);
    env.wr('h014, '1, 0); env.wr('h018, '1, 0);
    env.rd('h000, 'h41); env.rd('h008, 3); env.rd('h00c, 0);
    env.rd('h014, 'h900d); env.rd('h018, 0);
  endtask
  initial begin
    env.reset(); env.wr('h008, 3); env.wr('h000, 'h41);
    env.wr('h014, 'hab, 1); env.rd('h014, 'h90ab);
    env.wr('h014, 'h5500, 2); env.rd('h014, 'h55ab);
    env.wr('h014, 'h900d, 3); env.wr('h014, 'hffff0000, 12);
    env.wr('h008, 'hff00, 2);
    no_lane(); env.rd('h010, 1); env.rd('h004, 0);
    fork
      env.expect_tx('h41, 3);
      begin env.wr('h00c, 1); no_lane(); end
    join
    fork
      env.send_rx('h5a, 3);
      begin #6500ns; no_lane(); end
    join
    env.rd('h010, 3); env.rd('h004, 'h5a);
    $display("PASS T-1.1.2.1");
    $finish;
  end
endmodule
