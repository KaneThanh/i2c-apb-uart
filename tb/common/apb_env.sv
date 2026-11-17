module apb_env #(parameter bit CORE = 0);
  timeunit 1ns;
  timeprecision 1ps;
  logic pclk = 0, presetn = 1;
  bit reset_seen = 0;
  always @(negedge presetn) reset_seen = 1;
  logic psel = 0, penable = 0, pwrite = 0;
  logic [11:0] paddr = 0;
  logic [3:0] pstrb = 0;
  logic [31:0] pwdata = 0;
  wire pready, pslverr;
  wire [31:0] prdata;
  logic rx = 1, cts_n = 0;
  wire tx, rts_n, irq;

  wire stat_tx_done, stat_rx_done, stat_parity_err;
  if (CORE) begin : core_dut
  apb_uart_core dut (
    .pclk(pclk), .presetn(presetn), .psel(psel), .penable(penable),
    .pwrite(pwrite), .paddr(paddr), .pstrb(pstrb), .pwdata(pwdata),
    .pready(pready), .pslverr(pslverr), .prdata(prdata),
    .rx(rx), .cts_n(cts_n), .tx(tx), .rts_n(rts_n), .irq(irq),
    .stat_tx_done(stat_tx_done), .stat_rx_done(stat_rx_done), .stat_parity_err(stat_parity_err)
  );
  end else begin : block_dut
  apb_uart dut (
    .pclk(pclk), .presetn(presetn), .psel(psel), .penable(penable),
    .pwrite(pwrite), .paddr(paddr), .pstrb(pstrb), .pwdata(pwdata),
    .pready(pready), .pslverr(pslverr), .prdata(prdata),
    .rx(rx), .cts_n(cts_n), .tx(tx), .rts_n(rts_n), .irq(irq)
  );
  end

  `include "uart_peer.svh"
  `include "uart_coverage.svh"
  always #(CLK_NS / 2) pclk = ~pclk;
  initial #100ms $fatal(1, "%m: timeout");

  covergroup apb_access @(posedge pclk);
    option.per_instance = 1;
    address: coverpoint paddr iff (presetn && psel && penable && pready) {
      bins registers[] = {12'h000, 12'h004, 12'h008, 12'h00c, 12'h010, 12'h014, 12'h018};
      bins unmapped = {[12'h01c:12'hfff]} with (item % 4 == 0);
      bins unaligned = {[12'h001:12'hfff]} with (item % 4 != 0);
    }
    direction: coverpoint pwrite iff (presetn && psel && penable && pready);
    address_direction: cross address, direction;
    baud_strobes: coverpoint pstrb iff (presetn && psel && penable && pready &&
                                        pwrite && paddr == 12'h014) {
      bins lanes[] = {0, 1, 2, 3, 12, 15};
    }
  endgroup
  apb_access cg03 = new;

  a01: assert property (@(posedge pclk) psel && penable |-> pready === 1'b1)
    else $fatal(1, "%m A-01");
  a02: assert property (@(posedge pclk) reset_seen && presetn |-> pready === 1'b1)
    else $fatal(1, "%m A-02");
  a03: assert property (@(posedge pclk) reset_seen && pslverr |-> psel && penable)
    else $fatal(1, "%m A-03");
  a05: assert property (@(posedge pclk) reset_seen && presetn && $past(presetn) |->
    !$isunknown({pready, pslverr, tx, rts_n, irq}) &&
    (!(psel && penable) || !$isunknown(prdata)))
    else $fatal(1, "%m A-05");
  a12: assert property (@(posedge pclk) presetn && psel && penable &&
    !pwrite && paddr == 12'h00c |-> prdata === 32'h0)
    else $fatal(1, "%m A-12");
  function automatic logic [31:0] read_field_mask(input logic [11:0] addr);
    case (addr)
      12'h000, 12'h004, 12'h010: return 32'hff;
      12'h008: return 32'h7f;
      12'h00c: return 0;
      12'h014: return 32'hffff;
      12'h018: return 32'h07;
      default: return '1;
    endcase
  endfunction

  a13: assert property (@(posedge pclk) presetn && psel && penable &&
    !pwrite && !pslverr |-> (prdata & ~read_field_mask(paddr)) === 32'h0)
    else $fatal(1, "%m A-13");
  a13_active: cover property (@(posedge pclk) presetn && psel && penable &&
    !pwrite && !pslverr);
  a01_active: cover property (@(posedge pclk) psel && penable);
  a02_active: cover property (@(posedge pclk) reset_seen && presetn);
  a03_active: cover property (@(posedge pclk) reset_seen && pslverr);
  a05_active: cover property (@(posedge pclk) reset_seen && presetn && $past(presetn));
  a12_active: cover property (@(posedge pclk) presetn && psel && penable &&
    !pwrite && paddr == 12'h00c);

  task automatic reset(input time settle = 2ns);
    @(negedge pclk);
    #1ns presetn = 0;
    #(settle);
    a04: assert ({tx, rts_n, irq, pslverr, pready} === 5'b11001)
      else $fatal(1, "%m A-04 async reset outputs");
    repeat (3) @(negedge pclk);
    #1ns presetn = 1;
    repeat (2) @(posedge pclk);
    #1ns;
  endtask

  task automatic transfer(input bit wr, input logic [11:0] addr,
                          input logic [3:0] strb, input logic [31:0] data,
                          input bit error_expected, output logic [31:0] result);
    @(negedge pclk);
    psel = 1;
    penable = 0;
    paddr = addr;
    pwrite = wr;
    pstrb = strb;
    pwdata = data;
    @(posedge pclk);
    check({pready, pslverr} === 2'b10, "APB setup");
    @(negedge pclk);
    penable = 1;
    @(posedge pclk);
    result = prdata;
    check(pslverr === error_expected,
          $sformatf("SB-02 addr=%03h pslverr=%b expected=%b", addr, pslverr, error_expected));
    #1ns;
    psel = 0;
    penable = 0;
  endtask

  task automatic wr(input logic [11:0] addr, input logic [31:0] data,
                    input logic [3:0] strb = 4'h1, input bit err = 0);
    logic [31:0] unused;
    transfer(1, addr, strb, data, err, unused);
  endtask

  task automatic rd(input logic [11:0] addr, input logic [31:0] expected,
                    input bit err = 0, input logic [31:0] mask = '1);
    logic [31:0] observed;
    transfer(0, addr, 0, 0, err, observed);
    check((observed & mask) === (expected & mask),
          $sformatf("SB-01 addr=%03h prdata=%08h expected=%08h mask=%08h",
                    addr, observed, expected, mask));
  endtask

  task automatic reset_registers;
    rd('h000, 0); rd('h004, 0); rd('h008, 0); rd('h00c, 0);
    rd('h010, 1); rd('h014, 'h900d); rd('h018, 0);
  endtask

  task automatic wait_rx_ready(input int remaining_cycles = 111);
    realtime deadline;
    deadline = $realtime + CLK_NS * remaining_cycles;
    while (rts_n !== 1'b1 && $realtime < deadline) begin
      @(negedge pclk);
    end
    check(rts_n === 1'b1, "SB-11 missing RX completion in stop-bit window");
  endtask

  task automatic receive_and_check(input logic [7:0] value, input logic [4:0] cfg,
                                   input realtime bit_ns = DEFAULT_BIT_NS);
    send_rx(value, cfg, bit_ns);
    wait_rx_ready();
    rd('h010, 'h02, 0, 'hce);
    rd('h004, {24'h0, masked_byte(value, cfg)});
    cg01.sample(0, cfg);
    cg02.sample(0, int'(bit_ns / CLK_NS));
    cg05.sample(0, value, cfg);
    cg10.sample(int'(100.0 * (DEFAULT_BIT_NS / bit_ns - 1.0)), frame_size(cfg));
  endtask

  task automatic transmit_and_check(input logic [7:0] value, input logic [4:0] cfg,
                                    input int bit_cycles = 217);
    wr('h000, {24'h0, value});
    fork
      expect_tx(value, cfg, bit_cycles);
      wr('h00c, 1);
    join
    repeat (2) @(posedge pclk);
    rd('h010, 1, 0, 1);
    cg01.sample(1, cfg);
    cg02.sample(1, bit_cycles);
    cg05.sample(1, value, cfg);
  endtask
endmodule
