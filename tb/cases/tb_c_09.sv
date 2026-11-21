module tb_c_09;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  initial begin
    env.reset();
    env.wr('h008, 'h1f);
    for (int slow = 0; slow < 2; slow++) begin
      fork
        for (int i = 0; i < 20; i++) env.send_rx(i[7:0], 'h1f, 8680.0/(slow ? 0.98 : 1.02));
        for (int i = 0; i < 20; i++) begin
          @(posedge env.rts_n);
          env.rd('h010, 3);
          env.rd('h004, i);
        end
      join
    end
    $display("PASS C-09");
    $finish;
  end
endmodule
