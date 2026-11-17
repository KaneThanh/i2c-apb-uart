localparam realtime CLK_NS = 40.0;
localparam realtime DEFAULT_BIT_NS = 217.0 * CLK_NS;
task automatic check(input logic ok, input string reason);
  if (ok !== 1'b1) $fatal(1, "%m @ %0t: %s", $time, reason);
endtask

function automatic int frame_size(input logic [4:0] cfg);
  return 7 + int'(cfg[1:0]) + int'(cfg[2]) + int'(cfg[3]);
endfunction

function automatic logic [11:0] frame_bits(input logic [7:0] data, input logic [4:0] cfg);
  logic [11:0] frame;
  logic parity;
  int n;
  n = 5 + int'(cfg[1:0]);
  frame = '1;
  frame[0] = 0;
  parity = 0;
  for (int i = 0; i < n; i++) begin
    frame[i+1] = data[i];
    parity ^= data[i];
  end
  if (cfg[3]) frame[n+1] = parity ^ !cfg[4];
  return frame;
endfunction

function automatic logic [7:0] masked_byte(input logic [7:0] data, input logic [4:0] cfg);
  return data & (8'hff >> (3 - int'(cfg[1:0])));
endfunction

task automatic send_rx(input logic [7:0] data, input logic [4:0] cfg,
                       input realtime bit_ns = DEFAULT_BIT_NS,
                       input bit bad_parity = 0, input bit bad_stop1 = 0,
                       input bit bad_stop2 = 0);
  logic [11:0] frame;
  int stop1;
  frame = frame_bits(data, cfg);
  stop1 = 6 + int'(cfg[1:0]) + int'(cfg[3]);
  if (bad_parity && cfg[3]) frame[stop1-1] = ~frame[stop1-1];
  if (bad_stop1) frame[stop1] = 0;
  if (bad_stop2 && cfg[2]) frame[stop1+1] = 0;
  for (int i = 0; i < frame_size(cfg); i++) begin
    rx = frame[i];
    #(bit_ns);
  end
  rx = 1;
endtask

task automatic expect_tx(input logic [7:0] data, input logic [4:0] cfg,
                         input int bit_cycles = 217, input bit require_idle = 1);
  logic [11:0] frame;
  logic expected;
  frame = frame_bits(data, cfg);
  @(negedge tx);
  #(CLK_NS / 2);
  for (int i = 0; i < frame_size(cfg); i++) begin
    expected = frame[i];
    repeat (bit_cycles) begin
      check(tx === expected, $sformatf("SB-04 bit %0d: TX=%b expected=%b", i, tx, expected));
      #(CLK_NS);
    end
  end
  if (require_idle) check(tx === 1'b1, "SB-04 TX not idle after frame");
endtask
