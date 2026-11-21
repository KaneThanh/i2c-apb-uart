module tb_t_1_2_2;
  timeunit 1ns;
  timeprecision 1ps;
  apb_env env();
  initial begin
    env.reset();
    // Precondition (T-1.2.2): 8E1, all IER bits, unread RX byte (rts_n=1, irq=1), TX mid-frame.
    env.wr('h008, 'h1b); env.wr('h018, 7);
    env.send_rx('h5a, 'h1b);
    env.wr('h000, 'h55); env.wr('h00c, 1);
    #4000ns;
    env.check({env.rts_n, env.irq} === 2'b11, "T-1.2.2 precondition: rts_n and irq must be 1");
    env.rd('h010, 'h02, 0, 'h03);
    @(negedge env.pclk);
    env.psel = 1; env.penable = 0; env.pwrite = 1;
    env.paddr = 'h020; env.pstrb = 'hf; env.pwdata = 0;
    @(negedge env.pclk); env.penable = 1;
    @(posedge env.pclk);
    env.check(env.pslverr === 1, "Error before reset");
    #10ns env.presetn = 0;
    #2ns env.check({env.tx, env.rts_n, env.irq, env.pslverr, env.pready} === 5'b11001,
                  "A-04 asynchronous reset during access");
    env.psel = 0; env.penable = 0;
    repeat (3) @(negedge env.pclk);
    #1ns env.presetn = 1;
    repeat (2) @(posedge env.pclk);
    env.reset_registers();
    repeat (2300) begin @(negedge env.pclk); env.check(env.tx === 1, "TX resumed after reset"); end
    $display("PASS T-1.2.2");
    $finish;
  end
endmodule
