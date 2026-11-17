module tb_h_13 #(parameter bit AUTO_RUN = 1);
  timeunit 1ns;
  timeprecision 1ps;
  spi_env env();
  task automatic run;
    logic [55:0] unused;
    env.reset();
    env.write_reg(2, 'h1b);
    env.send_rx('h5a, 'h1b, 8680.0, 1);
    env.check({env.rx_done,env.parity_err} === 2'b11, "RX precondition");
    env.write_reg(2, 3);
    env.exchange(56'h82000000001b00, unused, 40);
    env.read_reg(2, 3);
    env.exchange(56'h01000000000000, unused, 8);
    env.read_reg(4, 1);
  endtask
  initial if (AUTO_RUN) begin
    run();
    $display("PASS H-13");
    $finish;
  end
endmodule
