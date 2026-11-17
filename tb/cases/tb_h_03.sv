module tb_h_03 #(parameter bit AUTO_RUN = 1);
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  localparam logic [15:0] BAUD [10] = '{16'h128b,16'h8145,16'hc0a2,16'h6051,
    16'hb028,16'h201b,16'h900d,16'hd006,16'h6003,16'hb001};
  localparam int CYCLES [10] = '{10417,5208,2604,1302,651,434,217,109,54,27};
  baud_env baud_check();
  task automatic run;
    baud_check.verify_ticks(16'hb001);
    env.reset();
    env.wr('h008, 3);
    foreach (BAUD[i]) begin
      env.wr('h014, {16'h0, BAUD[i]}, 3);
      env.rd('h014, {16'h0, BAUD[i]});
      env.transmit_and_check('h55, 3, CYCLES[i]);
      env.receive_and_check('h55, 3, 40.0 * CYCLES[i]);
    end
  endtask
  initial if (AUTO_RUN) begin
    run();
    $display("PASS H-03");
    $finish;
  end
endmodule
