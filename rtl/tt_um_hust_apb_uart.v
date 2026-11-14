// Top 2 (Tiny Tapeout): spi2apb in front of apb_uart_core, pin map of spec 13.2.
// ui_in[7:5] and uo_out[7] are the scan pins; scan is inserted after synthesis, not in RTL.
module tt_um_hust_apb_uart
  (input [7:0] ui_in, output [7:0] uo_out, input [7:0] uio_in, output [7:0] uio_out, output [7:0] uio_oe,
   input ena, input clk, input rst_n);
  wire        psel, penable, pwrite, pready, pslverr;
  wire [11:0] paddr;
  wire [3:0]  pstrb;
  wire [31:0] pwdata, prdata;
  wire        tx, rts_n, irq, spi_miso, tx_done, rx_done, parity_err;
  wire        unused = &{1'b0, ena, uio_in, ui_in[7:5]};

  assign uo_out  = {1'b0, irq, parity_err, rx_done, tx_done, spi_miso, rts_n, tx};
  assign uio_out = 8'd0;
  assign uio_oe  = 8'd0;

  spi2apb u_spi2apb
    (.pclk(clk), .presetn(rst_n),
     .spi_cs_n(ui_in[2]), .spi_sclk(ui_in[3]), .spi_mosi(ui_in[4]), .spi_miso(spi_miso),
     .psel(psel), .penable(penable), .pwrite(pwrite), .paddr(paddr), .pstrb(pstrb), .pwdata(pwdata),
     .prdata(prdata), .pready(pready), .pslverr(pslverr));

  apb_uart_core u_core
    (.pclk(clk), .presetn(rst_n),
     .psel(psel), .penable(penable), .pwrite(pwrite), .paddr(paddr), .pstrb(pstrb), .pwdata(pwdata),
     .pready(pready), .pslverr(pslverr), .prdata(prdata),
     .rx(ui_in[0]), .cts_n(ui_in[1]),
     .tx(tx), .rts_n(rts_n), .irq(irq),
     .stat_tx_done(tx_done), .stat_rx_done(rx_done), .stat_parity_err(parity_err));
endmodule
