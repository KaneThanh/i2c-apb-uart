module tb_h_12 #(parameter bit AUTO_RUN = 1);
  timeunit 1ns;
  timeprecision 1ps;
  spi_env env();
  task automatic run;
    env.reset();
    env.write_reg(0, 'ha5);
    env.verify_spi(56'h90000000123400, 56'h00000000000002);
    env.verify_spi(56'h87000000123400, 56'h00000000000001);
    env.verify_spi(56'h07000000000000, 56'h00000000000001);
    env.read_reg(0, 'ha5);
  endtask
  initial if (AUTO_RUN) begin
    run();
    $display("PASS H-12");
    $finish;
  end
endmodule
