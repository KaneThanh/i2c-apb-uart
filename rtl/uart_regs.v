// APB4 register block: address decode, pslverr (E1-E5), the 7 registers, RX flags, irq, rts_n, soft reset.
// prdata and pslverr are combinational; irq and rts_n are registered (one cycle behind their sources).
module uart_regs
  (input pclk, input presetn,
   input psel, input penable, input pwrite, input [11:0] paddr, input [3:0] pstrb, input [31:0] pwdata,
   output pready, output pslverr, output [31:0] prdata,
   output srst,                 // 1 in the cycle after an accepted soft_rst write
   output tx_start, output [7:0] tx_data, input tx_done,
   output [1:0] data_bits, output stop_bits, output parity_en, output parity_type,
   output rx_dis,
   output [11:0] div_int, output [3:0] div_frac,
   input rx_busy, input rx_valid, input [7:0] rx_data, input rx_perr, input rx_ferr,
   output rx_done, output parity_err,
   output rts_n, output irq);
  localparam [2:0] A_TXDATA = 3'd0, A_RXDATA = 3'd1, A_CFG = 3'd2, A_CTRL = 3'd3,
                   A_STAT = 3'd4, A_BAUD = 3'd5, A_IER = 3'd6;
  localparam [15:0] BAUD_RESET = 16'h900D;

  reg [7:0]  txdata_q, rxdata_q;
  reg [6:0]  cfg_q;
  reg [15:0] baud_q;
  reg [2:0]  ier_q;
  reg        rx_done_q, perr_q, ferr_q, ovr_q, irq_q, rts_n_q, srst_q;
  reg [31:0] prdata_r;

  wire       access     = psel & penable;
  wire [2:0] idx        = paddr[4:2];
  wire       addr_ok    = (paddr[11:5] == 7'd0) & (paddr[1:0] == 2'd0) & (idx != 3'd7);
  wire       sel_txdata = addr_ok & (idx == A_TXDATA);
  wire       sel_rxdata = addr_ok & (idx == A_RXDATA);
  wire       sel_cfg    = addr_ok & (idx == A_CFG);
  wire       sel_ctrl   = addr_ok & (idx == A_CTRL);
  wire       sel_stat   = addr_ok & (idx == A_STAT);
  wire       sel_baud   = addr_ok & (idx == A_BAUD);
  wire       sel_ier    = addr_ok & (idx == A_IER);

  wire        soft_rst_req = sel_ctrl & pstrb[1] & pwdata[8];
  wire        start_req    = sel_ctrl & pstrb[0] & pwdata[0];
  wire        busy         = ~tx_done | rx_busy;
  wire [15:0] baud_d       = {pstrb[1] ? pwdata[15:8] : baud_q[15:8],
                              pstrb[0] ? pwdata[7:0]  : baud_q[7:0]};

  wire e1 = ~addr_ok;
  wire e2 = pwrite & (sel_rxdata | sel_stat);
  wire e3 = pwrite & ~tx_done & ((sel_txdata & (|pstrb)) | (start_req & ~soft_rst_req));
  wire e4 = pwrite & busy & ((sel_cfg & pstrb[0]) | (sel_baud & (|pstrb[1:0])));
  wire e5 = pwrite & sel_baud & (baud_d[11:0] == 12'd0);

  wire wr          = access & pwrite & ~pslverr;
  wire soft_rst_wr = wr & soft_rst_req;
  wire rd_rx       = access & ~pwrite & sel_rxdata;
  wire err_any     = perr_q | ferr_q | ovr_q;
  wire [7:0] stat  = {ovr_q, ferr_q, cfg_q[6], cfg_q[5], rx_busy, perr_q, rx_done_q, tx_done};

  wire unused = &{1'b0, pwdata[31:16]};

  assign pready      = 1'b1;
  assign pslverr = access & presetn & (e1 | e2 | e3 | e4 | e5);
  assign prdata      = prdata_r;
  assign srst        = srst_q;
  // tx_dis = 1: start_tx is dropped and tx_done stays 1 (team decision on open question Q2)
  assign tx_start    = wr & start_req & ~soft_rst_req & ~cfg_q[5];
  assign tx_data     = txdata_q;
  assign data_bits   = cfg_q[1:0];
  assign stop_bits   = cfg_q[2];
  assign parity_en   = cfg_q[3];
  assign parity_type = cfg_q[4];
  assign rx_dis      = cfg_q[6];
  assign div_int     = baud_q[11:0];
  assign div_frac    = baud_q[15:12];
  assign rx_done     = rx_done_q;
  assign parity_err  = perr_q;
  assign rts_n       = rts_n_q;
  assign irq         = irq_q;

  always @* begin
    prdata_r = 32'd0;
    if (access & ~pwrite & addr_ok)
      case (idx)
        A_TXDATA: prdata_r = {24'd0, txdata_q};
        A_RXDATA: prdata_r = {24'd0, rxdata_q};
        A_CFG:    prdata_r = {25'd0, cfg_q};
        A_STAT:   prdata_r = {24'd0, stat};
        A_BAUD:   prdata_r = {16'd0, baud_q};
        A_IER:    prdata_r = {29'd0, ier_q};
        default:  prdata_r = 32'd0;   // CTRL reads 0
      endcase
  end

  always @(posedge pclk or negedge presetn)
    if (!presetn) begin
      txdata_q  <= 8'd0;
      rxdata_q  <= 8'd0;
      cfg_q     <= 7'd0;
      baud_q    <= BAUD_RESET;
      ier_q     <= 3'd0;
      rx_done_q <= 1'b0;
      perr_q    <= 1'b0;
      ferr_q    <= 1'b0;
      ovr_q     <= 1'b0;
      irq_q     <= 1'b0;
      rts_n_q   <= 1'b1;
      srst_q    <= 1'b0;
    end else begin
      srst_q  <= soft_rst_wr;
      rts_n_q <= cfg_q[6] | rx_done_q | srst_q | soft_rst_wr;
      irq_q   <= (ier_q[0] & tx_done) | (ier_q[1] & rx_done_q) | (ier_q[2] & err_any);
      // srst_q also clears: uart_rx may still raise rx_valid in the cycle before it sees srst
      if (soft_rst_wr | srst_q) begin
        txdata_q  <= 8'd0;
        rxdata_q  <= 8'd0;
        cfg_q     <= 7'd0;
        baud_q    <= BAUD_RESET;
        ier_q     <= 3'd0;
        rx_done_q <= 1'b0;
        perr_q    <= 1'b0;
        ferr_q    <= 1'b0;
        ovr_q     <= 1'b0;
      end else begin
        if (wr) begin
          if (sel_txdata & pstrb[0]) txdata_q <= pwdata[7:0];
          if (sel_cfg & pstrb[0])    cfg_q    <= pwdata[6:0];
          if (sel_baud)              baud_q   <= baud_d;
          if (sel_ier & pstrb[0])    ier_q    <= pwdata[2:0];
        end
        if (rx_valid) begin
          if (rx_done_q & ~rd_rx) ovr_q <= 1'b1;   // new frame dropped, old byte kept
          else begin                               // also a read in this cycle: old byte went out, take the new one
            rxdata_q  <= rx_data;
            rx_done_q <= 1'b1;
            perr_q    <= rx_perr;
            ferr_q    <= rx_ferr;
            ovr_q     <= 1'b0;
          end
        end else if (rd_rx) begin
          rx_done_q <= 1'b0;
          perr_q    <= 1'b0;
          ferr_q    <= 1'b0;
          ovr_q     <= 1'b0;
        end
      end
    end
endmodule
