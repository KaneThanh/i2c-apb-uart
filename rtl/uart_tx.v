// UART transmitter. Every bit lasts 16 baud ticks; baud_gen is restarted (baud_clr) in step with the start bit.
module uart_tx
  (input pclk, input presetn, input srst,
   input start,                 // 1-cycle pulse, only arrives when tx_done = 1
   input [7:0] data,            // stable while tx_done = 0
   input [1:0] data_bits,       // 00: 5, 01: 6, 10: 7, 11: 8
   input stop_bits,             // 0: 1 stop, 1: 2 stop
   input parity_en,
   input parity_type,           // 1: even, 0: odd
   input cts_n_s,
   input tick, output baud_en, output baud_clr,
   output tx, output tx_done);
  localparam [2:0] S_IDLE = 3'd0, S_WAIT_CTS = 3'd1, S_START = 3'd2,
                   S_DATA = 3'd3, S_PARITY = 3'd4, S_STOP = 3'd5;

  (* fsm_encoding = "none" *) reg [2:0] state_q;  // keep binary: Yosys one-hot recoding breaks eqy name matching (LEC, G6)
  reg       tx_q, done_q, par_q, stop_idx_q;
  reg [2:0] bit_idx_q;
  reg [3:0] tick_cnt_q;

  wire       bit_end    = tick & (tick_cnt_q == 4'd15);
  wire [2:0] last_idx   = {1'b0, data_bits} + 3'd4;      // N-1
  wire [2:0] next_idx   = bit_idx_q + 3'd1;
  wire       parity_bit = par_q ^ ~parity_type;          // even: xor of data bits

  assign baud_clr = (state_q == S_WAIT_CTS) & ~cts_n_s;
  assign baud_en  = (state_q >= S_START);
  assign tx       = tx_q;
  assign tx_done  = done_q;

  always @(posedge pclk or negedge presetn)
    if (!presetn) begin
      state_q    <= S_IDLE;
      tx_q       <= 1'b1;
      done_q     <= 1'b1;
      par_q      <= 1'b0;
      stop_idx_q <= 1'b0;
      bit_idx_q  <= 3'd0;
      tick_cnt_q <= 4'd0;
    end else if (srst) begin
      state_q    <= S_IDLE;
      tx_q       <= 1'b1;
      done_q     <= 1'b1;
      par_q      <= 1'b0;
      stop_idx_q <= 1'b0;
      bit_idx_q  <= 3'd0;
      tick_cnt_q <= 4'd0;
    end else begin
      case (state_q)
        S_IDLE:
          if (start) begin
            done_q  <= 1'b0;
            state_q <= S_WAIT_CTS;
          end
        S_WAIT_CTS:
          if (!cts_n_s) begin
            state_q    <= S_START;
            tx_q       <= 1'b0;
            par_q      <= 1'b0;
            stop_idx_q <= 1'b0;
            bit_idx_q  <= 3'd0;
            tick_cnt_q <= 4'd0;
          end
        default: begin
          if (tick) tick_cnt_q <= tick_cnt_q + 4'd1;
          if (bit_end)
            case (state_q)
              S_START: begin
                state_q <= S_DATA;
                tx_q    <= data[0];
                par_q   <= data[0];
              end
              S_DATA:
                if (bit_idx_q == last_idx) begin
                  state_q <= parity_en ? S_PARITY : S_STOP;
                  tx_q    <= parity_en ? parity_bit : 1'b1;
                end else begin
                  bit_idx_q <= next_idx;
                  tx_q      <= data[next_idx];
                  par_q     <= par_q ^ data[next_idx];
                end
              S_PARITY: begin
                state_q <= S_STOP;
                tx_q    <= 1'b1;
              end
              default:   // S_STOP
                if (stop_bits & ~stop_idx_q) stop_idx_q <= 1'b1;
                else begin
                  state_q <= S_IDLE;
                  done_q  <= 1'b1;
                end
            endcase
        end
      endcase
    end
endmodule
