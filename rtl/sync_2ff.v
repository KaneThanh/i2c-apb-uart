// Two-flop synchroniser for an asynchronous input; reset to RESET_VALUE.
module sync_2ff #(parameter RESET_VALUE = 1'b1)
  (input pclk, input presetn, input d, output q);
  reg meta_q, sync_q;
  always @(posedge pclk or negedge presetn)
    if (!presetn) begin
      meta_q <= RESET_VALUE;
      sync_q <= RESET_VALUE;
    end else begin
      meta_q <= d;
      sync_q <= meta_q;
    end
  assign q = sync_q;
endmodule
