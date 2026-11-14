// Fractional tick generator: k-th tick after clr is k*div_int + floor(k*div_frac/16) cycles later.
// div_int must be >= 1 (rejected upstream).
module baud_gen
  (input pclk, input presetn,
   input clr,
   input en,
   input [11:0] div_int, input [3:0] div_frac,
   output tick);
  reg [11:0] cnt_q;
  reg [3:0]  acc_q;
  wire [4:0]  acc_sum = {1'b0, acc_q} + {1'b0, div_frac};
  wire        carry   = acc_sum[4];                    // acc + div_frac >= 16
  wire [12:0] target  = {1'b0, div_int} + {12'd0, carry} - 13'd1;
  assign tick = en & ({1'b0, cnt_q} == target);

  always @(posedge pclk or negedge presetn)
    if (!presetn) begin
      cnt_q <= 12'd0;
      acc_q <= 4'd0;
    end else if (clr) begin
      cnt_q <= 12'd0;
      acc_q <= 4'd0;
    end else if (en) begin
      if (tick) begin
        cnt_q <= 12'd0;
        acc_q <= acc_sum[3:0];
      end else
        cnt_q <= cnt_q + 12'd1;
    end
endmodule
