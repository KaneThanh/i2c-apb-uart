// Top 1 (no SPI): exactly the 16 ports of spec 2.1 around apb_uart_core.
module apb_uart
  (input pclk, input presetn,
   input psel, input penable, input pwrite, input [11:0] paddr, input [3:0] pstrb, input [31:0] pwdata,
   output pready, output pslverr, output [31:0] prdata,
   input rx, input cts_n,
   output tx, output rts_n, output irq);
  wire stat_tx_done, stat_rx_done, stat_parity_err;
  wire unused = &{1'b0, stat_tx_done, stat_rx_done, stat_parity_err};

  apb_uart_core u_core
    (.pclk(pclk), .presetn(presetn),
     .psel(psel), .penable(penable), .pwrite(pwrite), .paddr(paddr), .pstrb(pstrb), .pwdata(pwdata),
     .pready(pready), .pslverr(pslverr), .prdata(prdata),
     .rx(rx), .cts_n(cts_n),
     .tx(tx), .rts_n(rts_n), .irq(irq),
     .stat_tx_done(stat_tx_done), .stat_rx_done(stat_rx_done), .stat_parity_err(stat_parity_err));
endmodule
