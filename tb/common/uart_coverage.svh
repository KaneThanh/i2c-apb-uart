covergroup uart_format with function sample(bit is_tx, logic [4:0] cfg);
  option.per_instance = 1;
  direction: coverpoint is_tx;
  data_bits: coverpoint cfg[1:0];
  stops: coverpoint cfg[2];
  parity: coverpoint cfg[4:3] {
    bins none = {2'b00,2'b10};
    bins odd = {2'b01};
    bins even_parity = {2'b11};
  }
  formats: cross direction, data_bits, stops, parity;
endgroup

covergroup uart_baud with function sample(bit is_tx, int cycles);
  option.per_instance = 1;
  direction: coverpoint is_tx;
  speed: coverpoint cycles {
    bins required_rates[] = {10417,5208,2604,1302,651,434,217};
    bins bonus_rates[] = {109,54,27};
    bins tx_only[] = {16,65535,226};
  }
  baud_direction: cross direction, speed {
    ignore_bins rx_tx_only = binsof(direction) intersect {0} && binsof(speed.tx_only);
  }
endgroup

covergroup uart_payload with function sample(bit is_tx, logic [7:0] value, logic [4:0] cfg);
  option.per_instance = 1;
  payload: coverpoint value {
    bins vectors[] = {8'h00,8'hff,8'h55,8'ha5,8'h5a};
    bins other = default;
  }
  high_tx: coverpoint (value >> (5 + int'(cfg[1:0]))) != 0
    iff (is_tx && cfg[1:0] != 3);
  receive_ones: coverpoint (masked_byte(value, cfg) == masked_byte(8'hff, cfg))
    iff (!is_tx && cfg[1:0] != 3);
  one_parity: coverpoint ^masked_byte(value, cfg) iff (cfg[3]);
  parity_mode: coverpoint cfg[4] iff (cfg[3]);
  parity_vectors: cross one_parity, parity_mode;
endgroup

covergroup uart_skew with function sample(int skew, int length);
  option.per_instance = 1;
  speed_error: coverpoint skew { bins cases[] = {-3,-2,0,2,3}; }
  frame_length: coverpoint length { bins bits[] = {[7:12]}; }
  tolerance: cross speed_error, frame_length;
endgroup

uart_format cg01 = new;
uart_baud cg02 = new;
uart_payload cg05 = new;
uart_skew cg10 = new;
