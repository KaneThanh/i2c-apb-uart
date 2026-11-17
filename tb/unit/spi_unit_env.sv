module spi_unit_env;
  timeunit 1ns;
  timeprecision 1ps;
  logic pclk = 0, presetn = 1;
  logic cs_n = 1, sclk = 0, mosi = 0;
  wire miso;
  wire psel, penable, pwrite;
  wire [11:0] paddr;
  wire [3:0] pstrb;
  wire [31:0] pwdata;
  logic [31:0] response_data = 1;
  int edges = 0, setups = 0, transfers = 0;
  int launch_bit;
  logic [11:0] expected_addr;
  logic [31:0] expected_write;
  bit expected_direction;
  realtime last_falling;
  bit active_frame = 0;

  spi2apb dut (
    .pclk(pclk), .presetn(presetn), .spi_cs_n(cs_n), .spi_sclk(sclk),
    .spi_mosi(mosi), .spi_miso(miso), .psel(psel), .penable(penable),
    .pwrite(pwrite), .paddr(paddr), .pstrb(pstrb), .pwdata(pwdata),
    .prdata(response_data), .pready(1'b1), .pslverr(1'b0)
  );
  always #20ns pclk = ~pclk;

  always @(posedge pclk) if (presetn && psel) begin
    if (!active_frame || edges != launch_bit)
      $fatal(1, "%m SB-10 unexpected APB at SPI bit %0d expected %0d", edges, launch_bit);
    if (paddr !== expected_addr || pwrite !== expected_direction)
      $fatal(1, "%m SB-10 wrong APB address/direction");
    if (pwrite && pwdata !== expected_write)
      $fatal(1, "%m SB-10 wrong PWDATA");
    // ASSUMPTION: bridge asserts all byte strobes on SPI writes (H-10).
    if (pwrite && pstrb !== 4'hf)
      $fatal(1, "%m SB-10 wrong PSTRB");
    if (penable) transfers++;
    else setups++;
  end

  always @(miso) if (presetn && active_frame) begin
    if (last_falling == 0.0 || $realtime - last_falling > 200.0)
      $fatal(1, "%m SB-12 MISO changed outside falling-edge synchronization window");
  end

  task automatic reset;
    #1ns presetn = 0;
    repeat (4) @(negedge pclk);
    #1ns presetn = 1;
    #200ns;
  endtask

  task automatic verify(input logic [55:0] request, input logic [55:0] expected_miso,
                         input int trigger_bit);
    logic [55:0] actual;
    launch_bit = trigger_bit;
    expected_direction = request[55];
    expected_addr = {6'h0, request[51:48], 2'b00};
    expected_write = request[39:8];
    edges = 0; setups = 0; transfers = 0; last_falling = 0.0;
    active_frame = 1; cs_n = 0;
    #200ns;
    for (int i = 55; i >= 0; i--) begin
      mosi = request[i];
      #200ns;
      actual[i] = miso;
      edges++;
      sclk = 1;
      #200ns;
      last_falling = $realtime;
      sclk = 0;
    end
    #200ns;
    active_frame = 0;
    cs_n = 1;
    #200ns;
    if (transfers != 1 || setups != 1 || actual !== expected_miso)
      $fatal(1, "%m SB-10 transfers=%0d setups=%0d MISO=%014h expected=%014h",
             transfers, setups, actual, expected_miso);
  endtask
endmodule
