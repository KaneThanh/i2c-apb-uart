module tb_h_07 #(parameter bit AUTO_RUN = 1);
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  task automatic run;
    env.reset();
    env.wr('h008, 7);
    env.send_rx('h41, 7, 8680.0, 0, 0, 1);
    env.rd('h010, 'h43); env.rd('h004, 'h41);
    #8680ns;
    env.send_rx('h41, 7, 8680.0, 0, 1, 0);
    env.rd('h010, 'h43); env.rd('h004, 'h41);
    #8680ns;
    env.receive_and_check('h41, 7);
    env.wr('h008, 3);
    fork
      repeat (3) env.send_rx('h41, 3, 8680.0/1.02);
      repeat (3) begin
        @(posedge env.rts_n);
        env.rd('h010, 3);
        env.rd('h004, 'h41);
      end
    join
  endtask
  initial if (AUTO_RUN) begin
    run();
    $display("PASS H-07");
    $finish;
  end
endmodule
