# Testbench guide — APB-UART

What a testbench writer needs to know about the RTL as it stands on 2026-11-13. Behaviour is defined by `docs/APB_UART_Specification.md`; this file only lists the interfaces, the timing the RTL actually has, and the team decisions that a test must match.

Status: `sync_2ff`, `baud_gen`, `uart_tx`, `uart_rx` have passing unit tests. `uart_regs`, `apb_uart_core`, `apb_uart`, `spi2apb`, `tt_um_hust_apb_uart` are lint-clean only and have **never been simulated**.


## 2. Hierarchy

```
apb_uart                 top 1, 16 spec ports
└─ apb_uart_core
   ├─ sync_2ff ×2        u_sync_rx, u_sync_cts
   ├─ uart_regs          u_regs
   ├─ baud_gen ×2        u_baud_tx, u_baud_rx
   ├─ uart_tx            u_tx
   └─ uart_rx            u_rx
tt_um_hust_apb_uart      top 2
├─ spi2apb               u_spi2apb
└─ apb_uart_core         u_core
```

## 3. Top-level ports

```verilog
module apb_uart
  (input pclk, input presetn,
   input psel, input penable, input pwrite, input [11:0] paddr, input [3:0] pstrb, input [31:0] pwdata,
   output pready, output pslverr, output [31:0] prdata,
   input rx, input cts_n,
   output tx, output rts_n, output irq);

module apb_uart_core   // same ports as apb_uart, plus:
   output stat_tx_done, output stat_rx_done, output stat_parity_err

module tt_um_hust_apb_uart
  (input [7:0] ui_in, output [7:0] uo_out, input [7:0] uio_in, output [7:0] uio_out, output [7:0] uio_oe,
   input ena, input clk, input rst_n);
```

Wrapper pin map (`clk` = `pclk`, `rst_n` = `presetn`):

| Pin | Signal | Pin | Signal |
|---|---|---|---|
| `ui_in[0]` | `rx` | `uo_out[0]` | `tx` |
| `ui_in[1]` | `cts_n` | `uo_out[1]` | `rts_n` |
| `ui_in[2]` | `spi_cs_n` | `uo_out[2]` | `spi_miso` |
| `ui_in[3]` | `spi_sclk` | `uo_out[3]` | `tx_done` |
| `ui_in[4]` | `spi_mosi` | `uo_out[4]` | `rx_done` |
| `ui_in[7:5]` | unused in RTL | `uo_out[5]` | `parity_err` |
| | | `uo_out[6]` | `irq` |
| | | `uo_out[7]` | constant 0 |

`uio_out = 0`, `uio_oe = 0`.

## 4. Sub-module ports (for unit tests)

```verilog
module sync_2ff #(parameter RESET_VALUE = 1'b1)
  (input pclk, input presetn, input d, output q);

module baud_gen
  (input pclk, input presetn, input clr, input en,
   input [11:0] div_int, input [3:0] div_frac, output tick);

module uart_tx
  (input pclk, input presetn, input srst,
   input start, input [7:0] data,
   input [1:0] data_bits, input stop_bits, input parity_en, input parity_type,
   input cts_n_s,
   input tick, output baud_en, output baud_clr,
   output tx, output tx_done);

module uart_rx
  (input pclk, input presetn, input srst,
   input rx_s, input rx_dis,
   input [1:0] data_bits, input stop_bits, input parity_en, input parity_type,
   input tick, output baud_en, output baud_clr,
   output rx_busy, output rx_valid, output [7:0] rx_data, output rx_perr, output rx_ferr);

module uart_regs
  (input pclk, input presetn,
   input psel, input penable, input pwrite, input [11:0] paddr, input [3:0] pstrb, input [31:0] pwdata,
   output pready, output pslverr, output [31:0] prdata,
   output srst,
   output tx_start, output [7:0] tx_data, input tx_done,
   output [1:0] data_bits, output stop_bits, output parity_en, output parity_type,
   output rx_dis,
   output [11:0] div_int, output [3:0] div_frac,
   input rx_busy, input rx_valid, input [7:0] rx_data, input rx_perr, input rx_ferr,
   output rx_done, output parity_err,
   output rts_n, output irq);

module spi2apb
  (input pclk, input presetn,
   input spi_cs_n, input spi_sclk, input spi_mosi, output spi_miso,
   output psel, output penable, output pwrite, output [11:0] paddr, output [3:0] pstrb, output [31:0] pwdata,
   input [31:0] prdata, input pready, input pslverr);
```

## 5. Registers

| Addr | Name | Access | Reset | Fields |
|---|---|---|---|---|
| 0x00 | TXDATA | RW | 0x0000_0000 | [7:0] `tx_data` |
| 0x04 | RXDATA | RO | 0x0000_0000 | [7:0] `rx_data`; a read clears `rx_done`, `parity_err`, `frame_err`, `overrun` |
| 0x08 | CFG | RW | 0x0000_0000 | [1:0] `data_bits` (5+n), [2] `stop_bits`, [3] `parity_en`, [4] `parity_type` (1 even), [5] `tx_dis`, [6] `rx_dis` |
| 0x0C | CTRL | W, reads 0 | 0x0000_0000 | [0] `start_tx`, [8] `soft_rst` |
| 0x10 | STAT | RO | 0x0000_0001 | [0] `tx_done`, [1] `rx_done`, [2] `parity_err`, [3] `rx_busy`, [4] `tx_dis`, [5] `rx_dis`, [6] `frame_err`, [7] `overrun` |
| 0x14 | BAUD | RW | 0x0000_900D | [11:0] `div_int`, [15:12] `div_frac` |
| 0x18 | IER | RW | 0x0000_0000 | [0] `tx_done_ie`, [1] `rx_done_ie`, [2] `err_ie` |

One bit = `16*div_int + div_frac` `pclk` cycles. BAUD values at 25 MHz:

| Baud | BAUD | Cycles/bit | | Baud | BAUD | Cycles/bit |
|---|---|---|---|---|---|---|
| 2,400 | 0x128B | 10,417 | | 57,600 | 0x201B | 434 |
| 4,800 | 0x8145 | 5,208 | | 115,200 | 0x900D | 217 |
| 9,600 | 0xC0A2 | 2,604 | | 230,400 | 0xD006 | 109 |
| 19,200 | 0x6051 | 1,302 | | 460,800 | 0x6003 | 54 |
| 38,400 | 0xB028 | 651 | | 921,600 | 0xB001 | 27 |

`pslverr` (only with `psel & penable`), checked in this order:

| Code | Condition |
|---|---|
| E1 | `paddr` not one of the 7 addresses (also misaligned, also reads; read data 0) |
| E2 | write to RXDATA or STAT, any `pstrb` |
| E3 | `tx_done = 0` and: write TXDATA with `pstrb != 0`, or write CTRL with `pstrb[0] & pwdata[0]` and not (`pstrb[1] & pwdata[8]`) |
| E4 | (`tx_done = 0` or `rx_busy = 1`) and: write CFG with `pstrb[0]`, or write BAUD with `pstrb[1:0] != 0` |
| E5 | write BAUD where merged `div_int` (written lanes + current value of the others) is 0 |

A faulty write changes nothing. Only lane 0 is stored for TXDATA, CFG, IER; lanes 0 and 1 for BAUD.
