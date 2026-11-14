// UART core: the apb_uart ports plus three status outputs for the Tiny Tapeout wrapper pins.
// TX and RX each own a baud_gen, restarted at their start bit and enabled only while busy.
module apb_uart_core
  (input pclk, input presetn,
   input psel, input penable, input pwrite, input [11:0] paddr, input [3:0] pstrb, input [31:0] pwdata,
   output pready, output pslverr, output [31:0] prdata,
   input rx, input cts_n,
   output tx, output rts_n, output irq,
   output stat_tx_done, output stat_rx_done, output stat_parity_err);
  wire        rx_s, cts_n_s;
  wire        srst, tx_start, tx_done;
  wire [7:0]  tx_data, rx_data;
  wire [1:0]  data_bits;
  wire        stop_bits, parity_en, parity_type, rx_dis;
  wire [11:0] div_int;
  wire [3:0]  div_frac;
  wire        rx_busy, rx_valid, rx_perr, rx_ferr, rx_done, parity_err;
  wire        tx_tick, tx_baud_en, tx_baud_clr;
  wire        rx_tick, rx_baud_en, rx_baud_clr;

  assign stat_tx_done    = tx_done;
  assign stat_rx_done    = rx_done;
  assign stat_parity_err = parity_err;

  sync_2ff #(.RESET_VALUE(1'b1)) u_sync_rx
    (.pclk(pclk), .presetn(presetn), .d(rx), .q(rx_s));
  sync_2ff #(.RESET_VALUE(1'b1)) u_sync_cts
    (.pclk(pclk), .presetn(presetn), .d(cts_n), .q(cts_n_s));

  uart_regs u_regs
    (.pclk(pclk), .presetn(presetn),
     .psel(psel), .penable(penable), .pwrite(pwrite), .paddr(paddr), .pstrb(pstrb), .pwdata(pwdata),
     .pready(pready), .pslverr(pslverr), .prdata(prdata),
     .srst(srst),
     .tx_start(tx_start), .tx_data(tx_data), .tx_done(tx_done),
     .data_bits(data_bits), .stop_bits(stop_bits), .parity_en(parity_en), .parity_type(parity_type),
     .rx_dis(rx_dis),
     .div_int(div_int), .div_frac(div_frac),
     .rx_busy(rx_busy), .rx_valid(rx_valid), .rx_data(rx_data), .rx_perr(rx_perr), .rx_ferr(rx_ferr),
     .rx_done(rx_done), .parity_err(parity_err),
     .rts_n(rts_n), .irq(irq));

  baud_gen u_baud_tx
    (.pclk(pclk), .presetn(presetn), .clr(tx_baud_clr | srst), .en(tx_baud_en),
     .div_int(div_int), .div_frac(div_frac), .tick(tx_tick));

  baud_gen u_baud_rx
    (.pclk(pclk), .presetn(presetn), .clr(rx_baud_clr), .en(rx_baud_en),   // rx_baud_clr includes srst
     .div_int(div_int), .div_frac(div_frac), .tick(rx_tick));

  uart_tx u_tx
    (.pclk(pclk), .presetn(presetn), .srst(srst),
     .start(tx_start), .data(tx_data),
     .data_bits(data_bits), .stop_bits(stop_bits), .parity_en(parity_en), .parity_type(parity_type),
     .cts_n_s(cts_n_s),
     .tick(tx_tick), .baud_en(tx_baud_en), .baud_clr(tx_baud_clr),
     .tx(tx), .tx_done(tx_done));

  uart_rx u_rx
    (.pclk(pclk), .presetn(presetn), .srst(srst),
     .rx_s(rx_s), .rx_dis(rx_dis),
     .data_bits(data_bits), .stop_bits(stop_bits), .parity_en(parity_en), .parity_type(parity_type),
     .tick(rx_tick), .baud_en(rx_baud_en), .baud_clr(rx_baud_clr),
     .rx_busy(rx_busy), .rx_valid(rx_valid), .rx_data(rx_data), .rx_perr(rx_perr), .rx_ferr(rx_ferr));
endmodule
