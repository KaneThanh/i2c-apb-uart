module tb_c_05;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  initial begin
    env.reset();
    env.cts_n = 1;
    env.wr('h008, 3); env.wr('h000, 'h41); env.wr('h00c, 1);
    env.rd('h010, 0);
    env.wr('h00c, 'h100, 2);
    #80ns;
    env.rd('h010, 1); env.rd('h000, 0);
    env.cts_n = 0;
    repeat (2300) begin
      @(negedge env.pclk); env.check(env.tx === 1, "TX request survived soft reset");
    end
    $display("PASS C-05");
    $finish;
  end
endmodule
