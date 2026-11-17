module tb_t_2_2_2_1;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  initial begin
    // ASSUMPTION: disabled start_tx silently ignored (SPEC 16.2 Q2).
    env.reset();
    env.wr('h008, 'h23); env.wr('h000, 'h41); env.wr('h00c, 1);
    repeat (2300) begin @(negedge env.pclk); env.check(env.tx === 1, "TX while disabled"); end
    env.rd('h010, 'h11);
    env.wr('h008, 3); env.rd('h010, 1);
    env.transmit_and_check('h41, 3);
    $display("PASS T-2.2.2.1");
    $finish;
  end
endmodule
