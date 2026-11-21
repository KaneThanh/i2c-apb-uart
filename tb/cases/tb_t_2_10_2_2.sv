module tb_t_2_10_2_2;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  localparam int WIDTHS [3] = '{5,65,84};
  initial begin
    env.reset(); env.wr('h008, 3);
    foreach (WIDTHS[i]) begin
      fork
        begin env.rx = 0; #(40ns * WIDTHS[i]); env.rx = 1; end
        repeat (1100) env.rd('h010, 1);
      join
    end
    env.rd('h004, 0); env.receive_and_check('h55, 3);
    $display("PASS T-2.10.2.2");
    $finish;
  end
endmodule
