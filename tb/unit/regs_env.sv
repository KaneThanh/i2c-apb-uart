module regs_env;
  timeunit 1ns;
  timeprecision 1ps;
  logic pclk = 0, presetn = 1;
  logic psel = 0, penable = 0, pwrite = 0;
  logic [11:0] paddr = 0;
  logic [3:0] pstrb = 0;
  logic [31:0] pwdata = 0;
  wire pready, pslverr;
  wire [31:0] prdata;
  logic rx_valid = 0;
  logic [7:0] rx_data = 0;
  wire rx_done, rts_n, irq, rx_dis, parity_err;
  wire [11:0] div_int;
  wire [3:0] div_frac;
  uart_regs dut (
    .pclk(pclk), .presetn(presetn), .psel(psel), .penable(penable),
    .pwrite(pwrite), .paddr(paddr), .pstrb(pstrb), .pwdata(pwdata),
    .pready(pready), .pslverr(pslverr), .prdata(prdata),
    .tx_done(1'b1), .rx_busy(1'b0), .rx_valid(rx_valid),
    .rx_data(rx_data), .rx_perr(1'b0), .rx_ferr(1'b0),
    .div_int(div_int), .div_frac(div_frac), .rx_done(rx_done),
    .rts_n(rts_n), .irq(irq), .rx_dis(rx_dis), .parity_err(parity_err)
  );
  always #20ns pclk = ~pclk;
  task automatic read_collision;
    #1ns presetn = 0;
    repeat (2) @(negedge pclk);
    presetn = 1;
    @(negedge pclk);
    rx_data = 8'h41; rx_valid = 1;
    @(negedge pclk);
    rx_valid = 0;
    if (rx_done !== 1'b1) $fatal(1, "%m: old RX byte not latched");
    psel = 1; penable = 0; pwrite = 0; paddr = 'h004;
    @(negedge pclk);
    penable = 1; rx_data = 8'h77; rx_valid = 1;
    @(posedge pclk);
    if ({pready, pslverr, prdata} !== {2'b10,32'h41})
      $fatal(1, "%m: access must return old byte");
    @(negedge pclk);
    rx_valid = 0; psel = 0; penable = 0;
    if (rx_done !== 1'b1) $fatal(1, "%m: new RX byte lost");
    psel = 1; paddr = 'h010;
    @(negedge pclk);
    penable = 1;
    @(posedge pclk);
    if (prdata !== 32'h03) $fatal(1, "%m: collision set error or lost rx_done");
    @(negedge pclk);
    penable = 0; paddr = 'h004;
    @(negedge pclk);
    penable = 1;
    @(posedge pclk);
    if (prdata !== 32'h77) $fatal(1, "%m: collision lost the new data");
    @(negedge pclk);
    psel = 0; penable = 0;
  endtask

  task automatic baud_commit;
    #1ns presetn = 0;
    repeat (2) @(negedge pclk);
    presetn = 1;
    @(negedge pclk);
    psel = 1; pwrite = 1; paddr = 'h014; pstrb = 'hf; pwdata = 'hb028;
    @(posedge pclk);
    #1ns;
    if ({div_frac,div_int} !== 16'h900d)
      $fatal(1, "%m: BAUD changed in setup");
    @(negedge pclk);
    penable = 1;
    @(posedge pclk);
    if ({div_frac,div_int} !== 16'h900d || {pready,pslverr} !== 2'b10)
      $fatal(1, "%m: BAUD changed before access edge");
    #1ns;
    if ({div_frac,div_int} !== 16'hb028)
      $fatal(1, "%m: BAUD was not committed at access edge");
    psel = 0; penable = 0;
  endtask
endmodule
