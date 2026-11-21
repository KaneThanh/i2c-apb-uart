module tb_c_13;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  initial begin
    env.reset();
    env.wr('h008, 3);
    env.wr('h000, 'h55); env.wr('h00c, 1);
    env.rd('h010, 0);
    env.wr('h014, 0, 3, 1); env.rd('h014, 'h900d);
    #87000ns;
    fork
      env.send_rx('h5a, 3);
      begin
        #6500ns; env.rd('h010, 'h09);
        env.wr('h014, 0, 3, 1); env.rd('h014, 'h900d);
      end
    join
    env.rd('h004, 'h5a);
    env.wr('h014, 0, 3, 1); env.rd('h014, 'h900d);
    $display("PASS C-13");
    $finish;
  end
endmodule
