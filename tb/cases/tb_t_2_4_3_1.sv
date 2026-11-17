module tb_t_2_4_3_1;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  initial begin
    env.reset();
    for (int i = 0; i < 4; i++) begin
      env.wr('h008, 3 | (i << 5));
      env.rd('h010, 1 | (i << 4));
    end
    env.wr('h008, 3);
    $display("PASS T-2.4.3.1");
    $finish;
  end
endmodule
