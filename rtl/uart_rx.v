// UART receiver. On a start edge baud_gen is restarted (baud_clr), so the 8th tick lands mid-bit;
// every later sample is 16 ticks on. rx is majority-voted over rx_s and two more flip-flops.
module uart_rx
  (input pclk, input presetn, input srst,
   input rx_s,                  // from a sync_2ff
   input rx_dis,                // 1: receiver disabled
   input [1:0] data_bits,       // 00: 5, 01: 6, 10: 7, 11: 8
   input stop_bits,             // 0: 1 stop, 1: 2 stop
   input parity_en,
   input parity_type,           // 1: even, 0: odd
   input tick, output baud_en, output baud_clr,
   output rx_busy,
   output rx_valid,             // 1-cycle pulse
   output [7:0] rx_data,        // bits [7:N] = 0; valid with rx_valid
   output rx_perr, output rx_ferr);
  localparam [2:0] S_IDLE = 3'd0, S_START = 3'd1, S_DATA = 3'd2, S_PARITY = 3'd3, S_STOP = 3'd4;

  reg       rx_1_q, rx_2_q, rx_v_q;
  reg [3:0] settle_q;
  reg [2:0] state_q, bit_idx_q;
  reg [3:0] tick_cnt_q;
  reg [7:0] data_q;
  reg       par_q, stop_idx_q, busy_q, valid_q, perr_q, ferr_q;

  wire       rx_v     = (rx_s & rx_1_q) | (rx_s & rx_2_q) | (rx_1_q & rx_2_q);
  // settle_q[3]: the sync and vote flip-flops hold line values, not reset values (no edge at reset release)
  wire       start    = (state_q == S_IDLE) & ~rx_dis & settle_q[3] & rx_v_q & ~rx_v;
  wire       sample   = tick & (tick_cnt_q == 4'd7);
  wire [2:0] last_idx = {1'b0, data_bits} + 3'd4;      // N-1

  assign baud_clr = srst | start;
  assign baud_en  = (state_q != S_IDLE);
  assign rx_busy  = busy_q;
  assign rx_valid = valid_q;
  assign rx_data  = data_q;
  assign rx_perr  = perr_q;
  assign rx_ferr  = ferr_q;

  always @(posedge pclk or negedge presetn)
    if (!presetn) begin
      rx_1_q   <= 1'b1;
      rx_2_q   <= 1'b1;
      rx_v_q   <= 1'b1;
      settle_q <= 4'd0;
    end else begin
      rx_1_q   <= rx_s;
      rx_2_q   <= rx_1_q;
      rx_v_q   <= rx_v;
      settle_q <= {settle_q[2:0], 1'b1};
    end

  always @(posedge pclk or negedge presetn)
    if (!presetn) begin
      state_q    <= S_IDLE;
      bit_idx_q  <= 3'd0;
      tick_cnt_q <= 4'd0;
      data_q     <= 8'd0;
      par_q      <= 1'b0;
      stop_idx_q <= 1'b0;
      busy_q     <= 1'b0;
      valid_q    <= 1'b0;
      perr_q     <= 1'b0;
      ferr_q     <= 1'b0;
    end else if (srst) begin
      state_q    <= S_IDLE;
      bit_idx_q  <= 3'd0;
      tick_cnt_q <= 4'd0;
      data_q     <= 8'd0;
      par_q      <= 1'b0;
      stop_idx_q <= 1'b0;
      busy_q     <= 1'b0;
      valid_q    <= 1'b0;
      perr_q     <= 1'b0;
      ferr_q     <= 1'b0;
    end else if (rx_dis) begin
      state_q <= S_IDLE;
      busy_q  <= 1'b0;
      valid_q <= 1'b0;
    end else begin
      valid_q <= 1'b0;
      case (state_q)
        S_IDLE:
          if (start) begin
            state_q    <= S_START;
            tick_cnt_q <= 4'd0;
          end
        default: begin
          if (tick) tick_cnt_q <= tick_cnt_q + 4'd1;
          if (sample)
            case (state_q)
              S_START:
                if (rx_v) state_q <= S_IDLE;   // glitch, not a start bit
                else begin
                  state_q    <= S_DATA;
                  busy_q     <= 1'b1;
                  bit_idx_q  <= 3'd0;
                  data_q     <= 8'd0;
                  par_q      <= 1'b0;
                  stop_idx_q <= 1'b0;
                  perr_q     <= 1'b0;
                  ferr_q     <= 1'b0;
                end
              S_DATA: begin
                data_q[bit_idx_q] <= rx_v;
                par_q             <= par_q ^ rx_v;
                if (bit_idx_q == last_idx) state_q <= parity_en ? S_PARITY : S_STOP;
                else bit_idx_q <= bit_idx_q + 3'd1;
              end
              S_PARITY: begin
                perr_q  <= par_q ^ rx_v ^ ~parity_type;   // even: data + parity must xor to 0
                state_q <= S_STOP;
              end
              default: begin   // S_STOP
                ferr_q <= ferr_q | ~rx_v;
                if (stop_bits & ~stop_idx_q) stop_idx_q <= 1'b1;
                else begin
                  state_q <= S_IDLE;
                  busy_q  <= 1'b0;
                  valid_q <= 1'b1;
                end
              end
            endcase
        end
      endcase
    end
endmodule
