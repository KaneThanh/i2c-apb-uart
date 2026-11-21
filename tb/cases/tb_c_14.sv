module tb_c_14;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  initial begin
    env.reset();
    env.wr('h008, 'h1b); env.wr('h014, 'hb028, 3);
    env.wr('h018, 7); env.wr('h000, 'h41);
    fork
      env.expect_tx('h41, 'h1b, 651);
      begin
        env.wr('h00c, 'h101);
        env.rd('h010, 0);
        env.wr('h00c, 'h101, 1, 1);
        env.rd('h008, 'h1b); env.rd('h014, 'hb028); env.rd('h018, 7);
      end
    join
    env.rd('h010, 1);
    env.wr('h00c, 'h101, 2);
    #120ns; env.reset_registers();
    repeat (2300) begin
      @(negedge env.pclk); env.check(env.tx === 1, "Soft reset launched a frame");
    end
    $display("PASS C-14");
    $finish;
  end
endmodule
