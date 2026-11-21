module tb_t_2_1_1_4;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  initial begin
    env.reset();
    env.wr('h000, '1, 15); env.rd('h000, 'hff);
    env.wr('h008, '1, 15); env.rd('h008, 'h7f); env.wr('h008, 3, 15);
    env.wr('h014, '1, 15); env.rd('h014, 'hffff); env.wr('h014, 'h900d, 15);
    env.wr('h018, '1, 15); env.rd('h018, 7); env.wr('h018, 0, 15);
    env.wr('h00c, 'hfffffefe, 15); env.rd('h00c, 0);
    env.rd('h004, 0); env.rd('h010, 1);
    env.rd('h000, 'hff); env.rd('h008, 3);
    repeat (2300) begin @(negedge env.pclk); env.check(env.tx === 1, "RFU triggered TX"); end
    $display("PASS T-2.1.1.4");
    $finish;
  end
endmodule
