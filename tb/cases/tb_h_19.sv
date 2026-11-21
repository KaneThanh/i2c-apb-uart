module tb_h_19 #(parameter bit AUTO_RUN = 1);
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  // ASSUMPTION: SPEC 12.2 reset values and SPEC 16.1 soft_rst precedence.
  task automatic soft_reset(input logic [31:0] data, input logic [3:0] strb);
    env.wr('h00c, data, strb);
    env.check(env.rts_n === 1, "A-11 soft reset RTS");
    @(posedge env.pclk);
    env.check(env.rts_n === 1, "A-11 second soft reset cycle");
    #1ns;
    env.reset_registers();
    env.check({env.tx,env.rts_n} === 2'b10, "Soft reset recovery");
  endtask
  task automatic run;
    env.reset();
    env.wr('h008, 'h1b); env.wr('h014, 'hb028, 3); env.wr('h018, 7);
    env.wr('h000, 'h41); env.send_rx('h5a, 'h1b,26040.0);
    env.rd('h010, 3);
    soft_reset('h100, 2);
    env.wr('h008, 3); env.wr('h000, 'h41); env.wr('h00c, 1);
    #25000ns;
    soft_reset('h100, 2);
    // The rest of the aborted frame (about 62 us) must not appear on tx.
    repeat (2300) begin
      @(negedge env.pclk);
      env.check(env.tx === 1, "Soft reset left the aborted TX frame running");
    end
    env.wr('h008, 3);
    fork
      env.send_rx('hff, 3);
      begin
        #6000ns;
        env.rd('h010, 9);
        soft_reset('h100, 2);
      end
    join
    env.rd('h010, 1);
    soft_reset('h101, 3);
    env.cts_n = 1;
    env.wr('h00c, 1); env.rd('h010, 0);
    soft_reset('h101, 3);
    env.cts_n = 0;
    env.wr('h008, 3); env.rd('h008, 3);
    env.transmit_and_check('h41, 3);
  endtask
  initial if (AUTO_RUN) begin
    run();
    $display("PASS H-19");
    $finish;
  end
endmodule
