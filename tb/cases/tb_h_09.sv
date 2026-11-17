module tb_h_09 #(parameter bit AUTO_RUN = 1);
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  task automatic compare_state(input bit busy, input logic [31:0] ier);
    env.rd('h000, 'h41); env.rd('h004, 0);
    env.rd('h008, 3); env.rd('h00c, 0);
    env.rd('h010, busy ? 0 : 1); env.rd('h014, 'h900d); env.rd('h018, ier);
  endtask

  task automatic illegal_write(input logic [11:0] addr, input logic [31:0] data,
                               input logic [3:0] strb, input bit busy = 0);
    env.wr(addr, data, strb, 1);
    compare_state(busy, 0);
  endtask

  task automatic run;
    env.reset();
    env.wr('h008, 3); env.wr('h000, 'h41);
    env.rd('h01c, 0, 1); env.rd('h020, 0, 1); env.rd('hffc, 0, 1);
    illegal_write('h001, '1, 'hf); illegal_write('h002, '1, 'hf);
    illegal_write('h003, '1, 'hf); illegal_write('h00d, '1, 'hf);
    illegal_write('h004, 'h55, 'hf);
    illegal_write('h010, 0, 0); illegal_write('h010, 'hff, 'hf);
    env.rd('h004, 0); env.rd('h010, 1);
    illegal_write('h014, 0, 3); illegal_write('h014, 0, 1);
    env.wr('h014, 1, 3); env.rd('h014, 1); env.wr('h014, 'h900d, 3);
    fork
      env.expect_tx('h41, 3);
      begin
        env.wr('h00c, 1);
        illegal_write('h000, 'h7f, 1, 1);
        illegal_write('h00c, 1, 1, 1); env.wr('h00c, 0); env.wr('h000, 'h7f, 0);
        illegal_write('h008, 'h1b, 1, 1);
        illegal_write('h014, 'hab, 1, 1); illegal_write('h014, 'h2000, 2, 1);
        illegal_write('h014, 'h201b, 3, 1);
        env.wr('h008, 'hff00, 2); env.wr('h014, 'hffff0000, 12);
        env.rd('h008, 3); env.rd('h014, 'h900d);
        env.wr('h018, 7); env.rd('h018, 7);
      end
    join
    fork
      env.send_rx('h55, 3);
      begin
        #6000ns;
        env.rd('h010, 'h9, 0, 'h9);
        env.transmit_and_check('h42, 3);
      end
    join
    env.rd('h010, 3); env.rd('h004, 'h55);
  endtask
  initial if (AUTO_RUN) begin
    run();
    $display("PASS H-09");
    $finish;
  end
endmodule
