module tb_t_1_1_1_5;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  initial begin
    env.reset(); env.wr('h008, 'h1b);
    env.send_rx('h5a, 'h1b, 8680.0, 1);
    // rx_done is set, so CFG may change only because rx_busy=0 and tx_done=1.
    env.wr('h008, 3); env.wr('h000, 'h41);
    @(negedge env.pclk);
    env.psel = 0; env.penable = 1; env.pwrite = 1;
    env.paddr = 'h00c; env.pstrb = 'hf; env.pwdata = 'h101;
    repeat (2300) begin
      @(negedge env.pclk); env.check(env.tx === 1, "Idle bus triggered TX");
    end
    env.pwrite = 0; env.paddr = 4;
    repeat (100) @(negedge env.pclk);
    env.psel = 1; env.penable = 0;
    @(negedge env.pclk); env.psel = 0;
    for (int i = 0; i < 1000; i++) begin
      env.paddr = i == 0 ? 12'h020 : 12'($urandom);
      env.pwdata = $urandom; env.pwrite = 1'($urandom);
      env.pstrb = 4'($urandom); env.penable = 1'($urandom);
      @(negedge env.pclk);
      env.check({env.pslverr,env.tx} === 2'b01, "Idle bus side effect");
    end
    env.rd('h010, 7); env.rd('h004, 'h5a);
    env.rd('h000, 'h41); env.rd('h008, 3); env.rd('h00c, 0);
    env.rd('h014, 'h900d); env.rd('h018, 0);
    $display("PASS T-1.1.1.5");
    $finish;
  end
endmodule
