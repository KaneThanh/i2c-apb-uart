// SPI mode 0 slave -> APB4 master. 56-bit frame: cmd, turnaround, 32 data bits, status.
// A read runs after the 8th rising SCLK edge, a write after the 48th. SCLK is sampled in pclk, never a clock.
// One 32-bit shift register carries the command bits, pwdata in, and prdata out.
module spi2apb
  (input pclk, input presetn,
   input spi_cs_n, input spi_sclk, input spi_mosi, output spi_miso,
   output psel, output penable, output pwrite, output [11:0] paddr, output [3:0] pstrb, output [31:0] pwdata,
   input [31:0] prdata, input pready, input pslverr);
  wire cs_n_s, sclk_s, mosi_s;
  reg        sclk_q;
  reg [5:0]  cnt_q;            // rising edges seen in this frame, saturates at 63
  reg [31:0] sr_q;
  reg        rw_q, cerr_q, perr_q;
  reg [3:0]  addr_q;
  reg        psel_q, penable_q, miso_q;

  wire active  = ~cs_n_s;
  wire rise    = active & sclk_s & ~sclk_q;
  wire fall    = active & ~sclk_s & sclk_q;
  wire in_data = (cnt_q >= 6'd16) & (cnt_q < 6'd48);
  wire rd_mode = (cnt_q >= 6'd8) & ~rw_q;                       // sr_q holds prdata, no shift-in
  wire rd_go   = rise & (cnt_q == 6'd7) & ~sr_q[6] & ~(|sr_q[5:3]);
  wire wr_go   = rise & (cnt_q == 6'd47) & rw_q & ~cerr_q;
  wire access  = psel_q & penable_q & pready;

  sync_2ff #(.RESET_VALUE(1'b1)) u_sync_cs
    (.pclk(pclk), .presetn(presetn), .d(spi_cs_n), .q(cs_n_s));
  sync_2ff #(.RESET_VALUE(1'b0)) u_sync_sclk
    (.pclk(pclk), .presetn(presetn), .d(spi_sclk), .q(sclk_s));
  sync_2ff #(.RESET_VALUE(1'b0)) u_sync_mosi
    (.pclk(pclk), .presetn(presetn), .d(spi_mosi), .q(mosi_s));

  assign psel     = psel_q;
  assign penable  = penable_q;
  assign pwrite   = rw_q;
  assign paddr    = {6'd0, addr_q, 2'b00};
  assign pstrb    = {4{rw_q}};
  assign pwdata   = sr_q;
  assign spi_miso = miso_q & ~spi_cs_n;                         // 0 as soon as CS rises, no synchroniser wait

  always @(posedge pclk or negedge presetn)
    if (!presetn) begin
      sclk_q    <= 1'b0;
      cnt_q     <= 6'd0;
      sr_q      <= 32'd0;
      rw_q      <= 1'b0;
      cerr_q    <= 1'b0;
      perr_q    <= 1'b0;
      addr_q    <= 4'd0;
      psel_q    <= 1'b0;
      penable_q <= 1'b0;
      miso_q    <= 1'b0;
    end else begin
      sclk_q <= sclk_s;

      // APB transfer: starts only while CS is low; once started it completes even if CS rises,
      // so rw_q, addr_q and sr_q are not cleared by CS (each frame rewrites them before use).
      if (rd_go | wr_go) psel_q <= 1'b1;
      else if (psel_q & ~penable_q) penable_q <= 1'b1;
      else if (access) begin
        psel_q    <= 1'b0;
        penable_q <= 1'b0;
      end

      if (!active) begin
        cnt_q  <= 6'd0;
        perr_q <= 1'b0;
      end else begin
        if (rise & (cnt_q != 6'd63)) cnt_q <= cnt_q + 6'd1;
        if (access) perr_q <= pslverr;
      end

      if (rise & (cnt_q == 6'd7)) begin                         // 8th bit of cmd arrives on mosi_s
        rw_q   <= sr_q[6];
        cerr_q <= |sr_q[5:3];
        addr_q <= {sr_q[2:0], mosi_s};
      end

      if (access & ~rw_q)                       sr_q <= prdata;
      else if (rise & ~rd_mode)                 sr_q <= {sr_q[30:0], mosi_s};
      else if (fall & rd_mode & in_data)        sr_q <= {sr_q[30:0], 1'b0};

      // bit k goes out on the falling edge after k rising edges
      if (!active) miso_q <= 1'b0;
      else if (fall) begin
        if (in_data)                 miso_q <= ~rw_q & ~cerr_q & sr_q[31];
        else if (cnt_q == 6'd54)     miso_q <= cerr_q;
        else if (cnt_q == 6'd55)     miso_q <= perr_q;
        else                         miso_q <= 1'b0;
      end
    end
endmodule
