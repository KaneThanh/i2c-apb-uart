module tb_t_3_1_4_1;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  task automatic test_lanes;
    env.wr('h008, 'h1b, 1, 1); env.wr('h014, 'hab, 1, 1);
    env.wr('h014, 'h2000, 2, 1); env.wr('h014, 'h201b, 3, 1);
    env.wr('h008, 'hff00, 2); env.wr('h008, 0, 0);
    env.wr('h014, 'hffff0000, 12); env.wr('h014, 0, 0);
    env.rd('h008, 3); env.rd('h014, 'h900d);
  endtask
  initial begin
    env.reset(); env.wr('h008, 3); env.wr('h000, 'h41);
    fork
      env.expect_tx('h41, 3);
      begin env.wr('h00c, 1); test_lanes(); end
    join
    fork
      env.send_rx('h5a, 3);
      begin #6500ns; env.rd('h010, 9); test_lanes(); end
    join
    env.rd('h010, 3); env.rd('h004, 'h5a);
    env.cts_n = 1; #200ns;
    env.wr('h00c, 1); env.rd('h010, 0); test_lanes();
    fork
      env.expect_tx('h41, 3);
      begin #1ns; env.cts_n = 0; end
    join
    env.rd('h010, 1);
    $display("PASS T-3.1.4.1");
    $finish;
  end
endmodule
