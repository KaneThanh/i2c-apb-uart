module tb_c_04;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  initial begin
    env.reset();
    env.wr('h008, 'h1b);
    env.wr('h000, 'h41); env.wr('h00c, 1);
    env.rx = 0; #7000ns;
    env.rd('h010, 8);
    fork
      env.reset();
      begin #100ns; env.rx = 1; end
    join
    env.rd('h010, 1);
    repeat (2600) begin
      @(negedge env.pclk); env.check({env.tx,env.rts_n} === 2'b10, "Unexpected frame after reset");
    end
    env.rd('h010, 1);
    env.wr('h008, 'h1b); env.receive_and_check('h5a, 'h1b);
    $display("PASS C-04");
    $finish;
  end
endmodule
