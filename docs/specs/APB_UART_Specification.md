# APB-UART System Specification (apb_uart + Tiny Tapeout wrapper)

| Item | Content |
|---|---|
| Source document | `HD-APB-UART-tuong-tac.html` – Specification 1.1 (01/11/2026), ET4030 |
| Reference documents | `Product Requirements - UART.pdf`, `UART Specs 3110 Product requirement.pdf` (meeting of 31/10/2026) |
| Verification plan | `UART_APB_VerificationSpecification.xlsx` (sheets Veri_spec, Test_plan) |
| Version | 1.0 – 11/11/2026 |
| Principle | Every requirement follows HTML 1.1. Where the HTML is silent, the team decided and the item is marked **[Team 11/11]**. Where the HTML only gives an implementation hint (not mandatory), the item is marked **[Hint]**. |

Conventions: each requirement has a code `REQ-xx-nn`. The "Spec ID" column at the end of each table points to the corresponding row in the Veri_spec sheet. "Shall" is mandatory; "should" is a recommendation.

---

## Table of contents

1. [Overview](#1-overview)
2. [Port interface](#2-port-interface)
3. [Architecture and RTL constraints](#3-architecture-and-rtl-constraints)
4. [Register map](#4-register-map)
5. [APB interface and pslverr](#5-apb-interface-and-pslverr)
6. [Fractional baud generator](#6-fractional-baud-generator)
7. [UART frame](#7-uart-frame)
8. [Transmitter (TX)](#8-transmitter-tx)
9. [Receiver (RX)](#9-receiver-rx)
10. [Flow control rts_n / cts_n](#10-flow-control-rts_n--cts_n)
11. [Interrupt](#11-interrupt)
12. [Reset](#12-reset)
13. [Tiny Tapeout wrapper and spi2apb](#13-tiny-tapeout-wrapper-and-spi2apb)
14. [Typical usage sequences](#14-typical-usage-sequences)
15. [Review gate schedule and completion criteria](#15-review-gate-schedule-and-completion-criteria)
16. [Inconsistencies in the HTML and open questions](#16-inconsistencies-in-the-html-and-open-questions)
17. [Appendix: quick-reference tables](#17-appendix-quick-reference-tables)

---

## 1. Overview

`apb_uart` is a full-duplex UART transceiver with an APB4 interface and hardware flow control `rts_n`/`cts_n`. Each direction buffers exactly one character (no FIFO). The design goes through the whole flow to GDS on Tiny Tapeout (sky130A, 1×1 tile). On the chip, the block is wrapped in the `tt_um_hust_apb_uart` wrapper; the RP2040 on the demo board accesses the registers through the `spi2apb` bridge.

```
RP2040 (SPI master) ──4-wire SPI──► spi2apb ──APB4──► apb_uart ──tx/rx/rts_n/cts_n──► peripheral device
        ▲                                                │
        └──────────────── irq (GPIO) ◄───────────────────┘
```

| Code | Requirement | Spec ID |
|---|---|---|
| REQ-GEN-01 | A single clock domain `pclk`, nominal **25 MHz** (the RP2040 divides 125 MHz by 5). STA at a 40 ns period. | 2.8.x |
| REQ-GEN-02 | Reset `presetn`, active low, asynchronous. There is no separate `clk` or `reset_n`. | 1.2.2, 2.6.1 |
| REQ-GEN-03 | Frame: 1 start bit; 5–8 data bits, LSB first; parity none / odd / even; 1 or 2 stop bits. All **24 formats** are mandatory for both TX and RX. | 2.9.1.5, 2.10.1.1 |
| REQ-GEN-04 | The baud rate is set through the BAUD register (fractional divider in 1/16 steps, 16× oversampling). 2 400–115 200 baud are mandatory; 230 400–921 600 baud earn bonus points. | 2.8.2.1, 2.8.2.2 |
| REQ-GEN-05 | One-character TX buffer (TXDATA), one-character RX buffer (RXDATA), no FIFO. | — |
| REQ-GEN-06 | APB4, `pready = 1` fixed (0 wait states), `pslverr` for exactly the 5 cases E1–E5. | 1.1.x, 3.1.x |

---

## 2. Port interface

### 2.1 Ports of `apb_uart`

The module name **shall** be `apb_uart`; names, widths and directions shall match the table below because the grading testbench connects by name (REQ-IO-01, Spec ID 1.2.1).

| Port | Width | Direction | Description |
|---|---|---|---|
| `pclk` | 1 | in | The only clock |
| `presetn` | 1 | in | Reset, active low, asynchronous |
| `psel` | 1 | in | Block select |
| `penable` | 1 | in | Access phase |
| `pwrite` | 1 | in | 1 write, 0 read |
| `paddr` | 12 | in | Byte address |
| `pstrb` | 4 | in | Write byte lanes |
| `pwdata` | 32 | in | Write data |
| `pready` | 1 | out | Always 1 |
| `pslverr` | 1 | out | Error, meaningful only in the access phase |
| `prdata` | 32 | out | Read data |
| `rx` | 1 | in | Serial in, asynchronous |
| `cts_n` | 1 | in | Clear-to-send, active low, asynchronous |
| `tx` | 1 | out | Serial out, idle = 1 |
| `rts_n` | 1 | out | Request-to-send, active low |
| `irq` | 1 | out | Level interrupt, active high |

### 2.2 Output values during and after reset

| Code | Requirement | Spec ID |
|---|---|---|
| REQ-IO-02 | While `presetn = 0` and right after reset: `tx = 1`, `rts_n = 1`, `irq = 0`, `pslverr = 0`, `pready = 1`. | 1.2.2 |
| REQ-IO-03 | When `presetn` goes to 0 the outputs take their reset values immediately, without needing a `pclk` edge. | 2.6.1 |
| REQ-IO-04 | `rx` and `cts_n` shall pass through at least 2 synchronizer flip-flops before the first logic (check Q6: the netlist has ≥ 2 flip-flops from the input port). | 1.2.3 |

Note: after reset is released, `rts_n` goes to 0 because `rx_dis = 0` and `rx_done = 0` (see §10).

---

## 3. Architecture and RTL constraints

### 3.1 Suggested block diagram

The team may partition the blocks differently, as long as the constraints in §3.2 are kept.

```
                 ┌──────────── tt_um_hust_apb_uart (wrapper) ────────────┐
 spi_cs_n ──►┌─────────┐ APB  ┌───────────────── apb_uart ─────────────┐│
 spi_sclk ──►│ spi2apb │─────►│ apb_if + decode ─► TXDATA, CTRL ──► uart_tx ─┼─► tx
 spi_mosi ──►│         │◄─────│        │            CFG, BAUD ──► baud_gen    ││
 spi_miso ◄──└─────────┘      │        │            RXDATA, STAT, IER ◄ uart_rx ◄─┼── rx (sync 2FF)
                              │        └──► irq                    rts_n ─┼─► rts_n
                              │                         cts_n (sync 2FF) ◄┼── cts_n
                              └────────────────────────────────────────┘│
                 └────────────────────────────────────────────────────────┘
```

| Block | Function | Implementation hint **[Hint]** |
|---|---|---|
| `spi2apb` | SPI mode 0 slave, 56-bit frame; generates 1 APB transaction per frame (read after bit 8, write after bit 48). Exists only in the wrapper. | Synchronize `cs_n`, `sclk`, `mosi` with 2 FFs, then detect `sclk` edges in the `pclk` domain. |
| `apb_if` + decode | Decodes `paddr` into the 7 registers, generates write pulses according to `pstrb`, selects `prdata`, computes `pslverr` (E1–E5) in the same access cycle. | `pslverr` and `prdata` are combinational functions of the current state; an erroneous command generates no write pulse. |
| TXDATA, CTRL | Stores `tx_data`; `start_tx` and `soft_rst` are 1-cycle pulses (read returns 0). | Mask the upper bits of `tx_data` at `uart_tx`, keep the value unchanged in the register. |
| CFG, BAUD | Frame configuration to `uart_tx`/`uart_rx`; `div_int`, `div_frac` to `baud_gen`. | Updated only when `tx_done = 1` and `rx_busy = 0` (E4), so the configuration never changes in the middle of a frame. |
| RXDATA, STAT, IER | Flags `rx_done`, `parity_err`, `frame_err`, `overrun`; IER selects interrupt sources. | Take `irq` from a flip-flop; `overrun` is set when `rx_valid` arrives while `rx_done = 1`, keeping the old RXDATA. |
| `uart_tx` | FSM IDLE → WAIT_CTS → START → DATA → PARITY → STOP; shift register; 16 ticks/bit. | `cts_n` is examined only before the start bit; `tx_done` rises at the end of the last stop bit. |
| `baud_gen` | Fractional accumulator, emits a `tick` pulse 1 `pclk` cycle wide. | `tick` is an enable pulse, not a clock. At D = 1.6875, ticks are 1 or 2 cycles apart. |
| `uart_rx` | Detects the falling edge, re-checks start at tick 8, samples every 16 ticks, computes parity, checks stop, generates `rx_valid`. | May use 3-sample majority voting around the middle of the bit. A low pulse shorter than 0.4 bit does not create a frame. |
| sync 2FF | Synchronizes `rx`, `cts_n`. | — |

### 3.2 RTL constraints (gate G2)

| Code | Requirement |
|---|---|
| REQ-RTL-01 | One clock net `pclk`; no logic-generated clocks; sub-blocks use the `tick` enable pulse. |
| REQ-RTL-02 | `verilator --lint-only -Wall`: 0 warnings. |
| REQ-RTL-03 | Yosys `proc`: no latches. |
| REQ-RTL-04 | `rx`, `cts_n` pass through 2 synchronizer flip-flops (= REQ-IO-04). |
| REQ-RTL-05 | No `initial`, `#delay`, `$display` in `rtl/`; no direct instantiation of `sky130_` cells. |
| REQ-RTL-06 | The testbench accesses `apb_uart` only through its ports. |

---

## 4. Register map

Byte addresses, 4-byte aligned. Reserved (rfu) bits read as 0, writes have no effect. Reset values are 0, except `STAT.tx_done = 1` (STAT = `0x0000_0001`) and `BAUD = 0x0000_900D`.

| Address | Name | Access | Reset | Byte lanes containing fields |
|---|---|---|---|---|
| 0x00 | TXDATA | RW | 0x0000_0000 | lane 0 |
| 0x04 | RXDATA | RO | 0x0000_0000 | lane 0 |
| 0x08 | CFG | RW | 0x0000_0000 | lane 0 |
| 0x0C | CTRL | RW (reads return 0) | 0x0000_0000 | lane 0 (start_tx), lane 1 (soft_rst) |
| 0x10 | STAT | RO | 0x0000_0001 | lane 0 |
| 0x14 | BAUD | RW | 0x0000_900D | lane 0, lane 1 |
| 0x18 | IER | RW | 0x0000_0000 | lane 0 |

### 4.1 TXDATA (0x00, RW)

| Bit | Field | Description |
|---|---|---|
| [7:0] | `tx_data` | Character to transmit. When N < 8 only `tx_data[N−1:0]` is transmitted, but the register holds and reads back all 8 bits that were written. |
| [31:8] | rfu | |

### 4.2 RXDATA (0x04, RO)

| Bit | Field | Description |
|---|---|---|
| [7:0] | `rx_data` | Received character; `rx_data[7:N] = 0`. **Reading this register clears `rx_done`, `parity_err`, `frame_err`, `overrun`.** |
| [31:8] | rfu | |

### 4.3 CFG (0x08, RW)

| Bit | Field | Description |
|---|---|---|
| [1:0] | `data_bits` | 00: 5, 01: 6, 10: 7, 11: 8 data bits |
| [2] | `stop_bits` | 0: 1 stop, 1: 2 stop |
| [3] | `parity_en` | 1: parity enabled |
| [4] | `parity_type` | 1: even, 0: odd |
| [5] | `tx_dis` | 1: transmitter disabled |
| [6] | `rx_dis` | 1: receiver disabled, `rts_n = 1` |
| [31:7] | rfu | |

The reset value CFG = 0 corresponds to the **5N1** frame. Bits per frame = 1 + N + parity_en + (stop_bits + 1).

### 4.4 CTRL (0x0C, RW, reads return 0)

| Bit | Field | Description |
|---|---|---|
| [0] | `start_tx` | Write 1: transmit TXDATA. 1-cycle pulse, reads return 0. |
| [7:1] | rfu | |
| [8] | `soft_rst` | Write 1: soft reset. 1-cycle pulse, self-clearing, reads return 0, no need to write 0 again. |
| [31:9] | rfu | |

`start_tx` (lane 0) and `soft_rst` (lane 1) are in two different bytes so they can be selected separately with `pstrb`.

### 4.5 STAT (0x10, RO)

| Bit | Field | Reset | Description |
|---|---|---|---|
| [0] | `tx_done` | 1 | 1: transmitter idle |
| [1] | `rx_done` | 0 | 1: RXDATA holds an unread character |
| [2] | `parity_err` | 0 | The character in RXDATA has a parity error |
| [3] | `rx_busy` | 0 | A frame is being received |
| [4] | `tx_dis` | 0 | Copy of `CFG.tx_dis` |
| [5] | `rx_dis` | 0 | Copy of `CFG.rx_dis` |
| [6] | `frame_err` | 0 | A stop bit equals 0 (both are checked when `stop_bits = 1`) |
| [7] | `overrun` | 0 | A new frame was dropped because `rx_done = 1` |
| [31:8] | rfu | 0 | |

### 4.6 BAUD (0x14, RW)

| Bit | Field | Description |
|---|---|---|
| [11:0] | `div_int` | Integer part of D, shall be ≥ 1 (lane 0 holds [7:0], lane 1 holds [11:8]) |
| [15:12] | `div_frac` | Fractional part of D, in units of 1/16 (lane 1) |
| [31:16] | rfu | |

### 4.7 IER (0x18, RW)

| Bit | Field | Description |
|---|---|---|
| [0] | `tx_done_ie` | Interrupt when `tx_done = 1` |
| [1] | `rx_done_ie` | Interrupt when `rx_done = 1` |
| [2] | `err_ie` | Interrupt when `parity_err`, `frame_err` or `overrun` is set |
| [31:3] | rfu | |

### 4.8 General register requirements

| Code | Requirement | Spec ID |
|---|---|---|
| REQ-REG-01 | The 7 registers are at exactly the addresses above. | 2.1.1.1 |
| REQ-REG-02 | Reset values are exactly as in the table above. | 2.1.1.2 |
| REQ-REG-03 | TXDATA[7:0], CFG[6:0], BAUD[15:0], IER[2:0] read back correctly after being written when TX and RX are idle. | 2.1.1.3 |
| REQ-REG-04 | rfu bits read as 0, writes have no effect. | 2.1.1.4 |
| REQ-REG-05 | `STAT[4] = CFG[5]`, `STAT[5] = CFG[6]` for every value. | 2.4.3.1 |
| REQ-REG-06 | Error flags STAT[2], [6], [7] reset to 0 and are cleared by reading RXDATA. | 2.4.4.x |

---

## 5. APB interface and pslverr

### 5.1 Transfers

| Code | Requirement | Spec ID |
|---|---|---|
| REQ-APB-01 | Each transfer consists of 1 setup cycle (`psel=1, penable=0`) and exactly 1 access cycle (`psel=penable=1`), with no wait states. | 1.1.1.1 |
| REQ-APB-02 | `pready = 1` in every cycle after reset, including when TX or RX is busy. | 1.1.1.2 |
| REQ-APB-03 | Registers change at the rising edge that ends the access phase; they do not change in the setup phase. | 1.1.1.3 |
| REQ-APB-04 | `prdata` and `pslverr` are meaningful only in the access phase; `pslverr` can be 1 only when `psel && penable`. | 1.1.1.4, 1.1.3.1 |
| REQ-APB-05 | `psel = 0`: no transfer, no register changes, no RXDATA read occurs. | 1.1.1.5 |
| REQ-APB-06 | Only bytes with `pstrb[i] = 1` are written. | 1.1.2.1 |
| REQ-APB-07 | Writing TXDATA, CFG, CTRL, BAUD, IER with `pstrb = 0000`: no register change, no action, `pslverr = 0`, even when busy. | 1.1.2.2 |

HTML §8 waveform example: (1) write BAUD = 0x0000_900D, passes; (2) read STAT returns 0x0000_0001; (3) write 0x020 → `pslverr = 1` (E1), no register changes.

### 5.2 pslverr cases

`pslverr = 1` **only** in the following 5 cases. A faulty command changes no register and triggers no action (REQ-ERR-06, Spec ID 3.1.6).

| Code | Condition | Spec ID |
|---|---|---|
| **E1** | `paddr` outside {0x00, 0x04, 0x08, 0x0C, 0x10, 0x14, 0x18}, including non-4-byte-aligned addresses. Reads return 0. | 3.1.1.x |
| **E2** | Write to RXDATA or STAT (regardless of `pstrb`). | 3.1.2 |
| **E3** | While `tx_done = 0`: write to TXDATA (with `pstrb ≠ 0`), or write to CTRL with `pstrb[0] = 1` and `pwdata[0] = 1`. | 3.1.3.x |
| **E4** | While `tx_done = 0` or `rx_busy = 1`: write to CFG with `pstrb[0] = 1`, or write to BAUD with `pstrb[0] = 1` or `pstrb[1] = 1`. | 3.1.4.x |
| **E5** | Write to BAUD where `div_int` **after the write** (merging the written lanes with the current value) equals 0. | 3.1.5 |

The checking order follows the HTML checker: E1 → E2 → E3 → E4 → E5. All of them produce the same `pslverr = 1`; the order is needed only for classification when writing tests.

### 5.3 Legal accesses (shall not report an error)

| Code | Requirement | Spec ID |
|---|---|---|
| REQ-ERR-07 | `rx_busy = 1`, `tx_done = 1`: writing TXDATA and `start_tx` both give `pslverr = 0`; TX and RX run simultaneously and correctly. | 3.2.1.1 |
| REQ-ERR-08 | When busy: writing CFG with `pstrb[0] = 0`, or BAUD with `pstrb[1:0] = 00` → `pslverr = 0`. | 3.2.1.2 |
| REQ-ERR-09 | `tx_done = 0`: writing CTRL with `pwdata[0] = 0` → `pslverr = 0`. | 3.2.1.3 |
| REQ-ERR-10 | Writing IER and reading any register in the table, in any state → `pslverr = 0`. | 3.2.1.4 |
| REQ-ERR-11 | Writing `soft_rst = 1` never reports `pslverr`, even when busy or combined with `start_tx = 1`. | 2.7.3, 4.1.1.x |
| REQ-ERR-12 | While waiting for `cts_n` (`tx_done = 0`): E3 and E4 still apply. | 3.1.4.3 |

---

## 6. Fractional baud generator

### 6.1 Formulas

```
D        = div_int + div_frac/16
Baud     = f_pclk / (16 · D)
1 bit    = 16 ticks = 16·div_int + div_frac pclk cycles   (exact for every bit)
D_actual = round(16 · f_pclk / (16 · baud)) / 16
Error    = (f_pclk / (16 · D_actual) − baud) / baud
```

### 6.2 Counters

| Counter | Block | What it counts | Range | Width |
|---|---|---|---|---|
| `cnt` | baud_gen | pclk cycles within one tick period; counts 0 … L−1 then emits a tick, L = div_int + carry | 0 … 4095 | 12 bits |
| `acc` | baud_gen | Accumulated fraction (units of 1/16 cycle); each tick: `acc ← (acc + div_frac) mod 16`, `carry = (acc + div_frac ≥ 16)` | 0 … 15 | 4 bits |
| `tick_cnt` | uart_tx, uart_rx | Ticks within a bit; RX samples when `tick_cnt = 8` | 0 … 15 | 4 bits |
| `bit_idx` | uart_tx, uart_rx | Bit position: 0 = start, 1…N data, then parity, stop | 0 … 11 | 4 bits |

Over 16 ticks, `acc` wraps exactly `div_frac` times and returns to its value at the start of the bit, so every bit is exactly 16·D cycles long. Example D = 14.125 (div_int = 14, div_frac = 2): 226 cycles/bit = 14 ticks of 14 cycles + 2 ticks of 15 cycles; at 25 MHz this is 9.04 µs (110 619 baud). After reset `acc = 0`.

### 6.3 BAUD table at 25 MHz

| Baud | div_int | div_frac | D | BAUD | Cycles/bit | Error | Level |
|---|---|---|---|---|---|---|---|
| 2 400 | 651 | 1 | 651.0625 | 0x128B | 10 417 | −0.003 % | Mandatory |
| 4 800 | 325 | 8 | 325.5 | 0x8145 | 5 208 | +0.01 % | Mandatory |
| 9 600 | 162 | 12 | 162.75 | 0xC0A2 | 2 604 | +0.01 % | Mandatory |
| 19 200 | 81 | 6 | 81.375 | 0x6051 | 1 302 | +0.01 % | Mandatory |
| 38 400 | 40 | 11 | 40.6875 | 0xB028 | 651 | +0.01 % | Mandatory |
| 57 600 | 27 | 2 | 27.125 | 0x201B | 434 | +0.01 % | Mandatory |
| 115 200 | 13 | 9 | 13.5625 | 0x900D | 217 | +0.01 % | Mandatory (reset) |
| 230 400 | 6 | 13 | 6.8125 | 0xD006 | 109 | −0.45 % | Bonus |
| 460 800 | 3 | 6 | 3.375 | 0x6003 | 54 | +0.47 % | Bonus |
| 921 600 | 1 | 11 | 1.6875 | 0xB001 | 27 | +0.47 % | Bonus |

For comparison: an integer divider with 16× oversampling gives −3.12 % at 115 200 baud (exceeding ±1 %), which is why a fractional divider is used.

| Code | Requirement | Spec ID |
|---|---|---|
| REQ-BAUD-01 | Every bit on `tx` is exactly `16·div_int + div_frac` pclk cycles long. | 2.8.1.1 |
| REQ-BAUD-02 | Reset BAUD = 0x900D: 217 cycles/bit, 115 200 baud at 25 MHz. | 2.8.1.2 |
| REQ-BAUD-03 | Transmit and receive correctly at the 7 mandatory rates, with error within ±1.0 %. | 2.8.2.1 |
| REQ-BAUD-04 | Transmit and receive correctly at the 3 bonus rates. | 2.8.2.2 |
| REQ-BAUD-05 | Smallest D is 1.6875: bits are still exactly 27 cycles even though ticks are 1 or 2 cycles apart. | 4.4.1 |
| REQ-BAUD-06 | `div_int = 0` is invalid → E5. | 3.1.5 |

---

## 7. UART frame

Order on the line:

```
idle(1) │ start(0) │ D0 │ D1 │ … │ D(N−1) │ [parity] │ stop(1) │ [stop2(1)] │ idle(1)
```

| Code | Requirement | Spec ID |
|---|---|---|
| REQ-FRM-01 | The start bit is 0, followed by data, LSB first. | 2.9.1.1 |
| REQ-FRM-02 | N < 8: only `tx_data[N−1:0]` is transmitted. | 2.9.1.2 |
| REQ-FRM-03 | Parity follows the data and is computed over the N transmitted bits. Even: the total number of 1s in data and parity is even; odd: it is odd. | 2.9.1.3 |
| REQ-FRM-04 | 1 or 2 stop bits at level 1, each 16·D cycles long. | 2.9.1.4 |
| REQ-FRM-05 | All 24 formats (4 lengths × 3 parities × 2 stops) are transmitted and received correctly. | 2.9.1.5, 2.10.1.1 |

Frame length n (start through last stop) = 1 + N + parity + number of stops: from 7 (5N1) to 12 (8E2/8O2). Example: 8N1 at 115 200 baud: 10 bits = 86.8 µs.

---

## 8. Transmitter (TX)

### 8.1 Operation

1. Software reads STAT and waits for `tx_done = 1` (and `rx_busy = 0` if CFG or BAUD must be changed).
2. Writes CFG and BAUD if they differ from last time; writes TXDATA.
3. Writes `CTRL.start_tx = 1` → `tx_done` drops to 0 in the next cycle.
4. The transmitter waits for `cts_n = 0` (after the 2-FF synchronizer); while waiting, `tx = 1`.
5. Transmits start, data, parity, stop. `cts_n` going to 1 in the middle of a frame does not stop the frame.
6. `tx_done` rises to 1 at the end of the last stop bit (≤ 2 pclk cycles); `irq` rises if `tx_done_ie = 1`.

### 8.2 Requirements

| Code | Requirement | Spec ID |
|---|---|---|
| REQ-TX-01 | Writing `start_tx = 1` when `tx_done = 1` → exactly 1 frame from TXDATA is transmitted. | 2.3.1.1 |
| REQ-TX-02 | `pwdata[0] = 0` or `pstrb[0] = 0` → no frame. | 2.3.1.2 |
| REQ-TX-03 | Reading CTRL[0] always returns 0, even right after writing 1. | 2.3.1.3 |
| REQ-TX-04 | `tx_done` = 1 when idle, = 0 from after `start_tx` until the end of the frame. | 2.4.1.1 |
| REQ-TX-05 | `tx_done` drops to 0 in the cycle after the `start_tx` write. | 2.9.2.1 |
| REQ-TX-06 | `tx_done` rises to 1 at the end of the last stop bit, within ≤ 2 pclk cycles. | 2.9.2.2 |
| REQ-TX-07 | When `tx_done = 1`, writing TXDATA and `start_tx` again: the next character is transmitted correctly. | 2.9.2.3 |
| REQ-TX-08 | `start_tx` while `cts_n = 1`: `tx = 1`, `tx_done = 0`, wait until `cts_n = 0` before sending the start bit. | 2.9.3.1 |
| REQ-TX-09 | `cts_n` is examined only before the start bit; if it rises to 1 in mid-frame the frame is still sent in full. | 4.2.1 |
| REQ-TX-10 | `tx_dis = 1`: writing `start_tx` creates no frame, `tx = 1`, `pslverr = 0`. `tx_dis = 0`: normal transmission. | 2.2.2.1 |
| REQ-TX-11 | Writing TXDATA or `start_tx` while `tx_done = 0` → E3, the frame in progress is unchanged, no extra frame. | 3.1.3.x |

---

## 9. Receiver (RX)

### 9.1 Sampling

- `rx` passes through 2 synchronizer FFs; the falling edge is detected.
- Start is re-checked at tick 8 (middle of the start bit); if valid, `rx_busy = 1`.
- After that it samples every 16 ticks, i.e. in the middle of each bit by the receiver clock.
- **Every stop bit is checked** according to `stop_bits`, each stop bit being sampled at tick 8. Any stop bit equal to 0 → `frame_err = 1`, so a frame missing the second stop bit is still detected.
- The first stop bit of a 2-stop frame still counts a full 16 ticks. Only the second half of the **last stop bit** is shortened: after sampling the last stop bit, the receiver sets `rx_done` and returns to IDLE immediately. Reason: when the sender is faster, the start bit of the next frame may arrive before the last stop bit ends by the receiver clock.

### 9.2 Rate tolerance

The receiver samples bit k at `t_k = (k + 0.5)·T + d·T/16`, where d ∈ [0, 1] ticks is the start-edge detection delay (d = 1 is worst; the 2-FF delay is ignored when D ≥ 2). The sender deviates by e: `T_tx = T/(1 + e)`. The last bit (k = n−1) is correct when:

```
|e| < (0.5 − 1/16) / (n − 0.5)
n = 12: 3.80 %   n = 11: 4.17 %   n = 10: 4.61 %   n = 7: 6.73 %
```

### 9.3 Requirements

| Code | Requirement | Spec ID |
|---|---|---|
| REQ-RX-01 | All 24 frame formats are received with the correct byte and no error flags. | 2.10.1.1 |
| REQ-RX-02 | N < 8: `rx_data[7:N] = 0`. | 2.10.1.2 |
| REQ-RX-03 | Parity is computed over exactly the N received bits for every N = 5–8. | 2.10.1.3 |
| REQ-RX-04 | Falling edge, re-check at tick 8; a valid start sets `rx_busy = 1`. | 2.10.2.1 |
| REQ-RX-05 | **[Hint]** A low pulse shorter than 0.4 bit does not create a frame: `rx_busy = 0`, `rx_done = 0`. | 2.10.2.2 |
| REQ-RX-06 | `rx_done = 1` within ≤ 1 bit after the last stop bit sampling point; at the same time `rx_busy = 0`. | 2.10.3.1 |
| REQ-RX-07 | `rx_done` = 1 when RXDATA holds an unread character; `rx_busy` = 1 while a frame is being received. | 2.4.2.x |
| REQ-RX-08 | Reading RXDATA clears `rx_done`, `parity_err`, `frame_err`, `overrun`. | 2.10.3.2 |
| REQ-RX-09 | **[Team 11/11]** Reading RXDATA in the cycle in which a new byte has just been received: `prdata` returns the old byte; at the edge that ends the access phase, RXDATA takes the new byte, `rx_done` stays 1, `overrun = 0`, error flags follow the new byte. No byte is lost. | 2.10.3.3 |
| REQ-RX-10 | **[Team 11/11]** Reading RXDATA while `rx_done = 0`: `pslverr = 0`, `prdata` returns the most recently received byte (0 after reset), flags stay 0, a frame being received is not affected. | 2.10.3.4 |
| REQ-RX-11 | Sender deviating by ±2.0 %, all 24 formats: received correctly, no flags. | 2.10.4.1 |
| REQ-RX-12 | Bonus F4: received correctly when the sender deviates by ±3.0 %. | 2.10.4.2 |
| REQ-RX-13 | Sender 2 % fast, back-to-back frames: the next start is not missed, every byte correct. | 4.3.1 |
| REQ-RX-14 | `rx_dis = 1`: frames on `rx` are not received (`rx_busy = 0`, `rx_done = 0`). | 2.2.2.2 |

### 9.4 Error flags

| Flag | Set when | Behavior | Spec ID |
|---|---|---|---|
| `parity_err` | The received character has a parity error | `rx_done = 1`, data can still be read | 3.3.1 |
| `frame_err` | A stop bit is sampled as 0 (both stop 1 and stop 2) | `rx_done = 1` | 3.3.2.x |
| `overrun` | A new frame completes while `rx_done = 1` | The new frame is dropped, RXDATA keeps the old character, `rx_done` stays 1 | 3.3.3 |

---

## 10. Flow control rts_n / cts_n

| Code | Requirement | Spec ID |
|---|---|---|
| REQ-FC-01 | `rts_n = 0` when `rx_dis = 0` and `rx_done = 0` (RXDATA empty, the other side may send). | 2.11.1.1 |
| REQ-FC-02 | When `rx_done` rises to 1, `rts_n = 1`; once RXDATA is read, `rts_n` returns to 0. | 2.11.1.2 |
| REQ-FC-03 | `rx_dis = 1` → `rts_n = 1`. | 2.11.1.3 |
| REQ-FC-04 | `cts_n` blocks the start of a TX frame (see REQ-TX-08, REQ-TX-09). | 2.9.3.1, 4.2.1 |
| REQ-FC-05 | During reset (hard or soft) `rts_n = 1`. | 1.2.2, 2.7.1.4 |

HTML 1.1 has no bit to enable/disable flow control: `cts_n` and `rts_n` are always active. When unused, tie `cts_n` to 0 at board/wrapper level.

---

## 11. Interrupt

`irq` is a **level interrupt, active high**, one pin for all three sources:

```
irq = (tx_done_ie & tx_done)
    | (rx_done_ie & rx_done)
    | (err_ie & (parity_err | frame_err | overrun))
```

| Code | Requirement | Spec ID |
|---|---|---|
| REQ-IRQ-01 | `irq` follows the formula above exactly; each IER bit enables only its own source. | 2.5.1, 2.12.1.1 |
| REQ-IRQ-02 | `irq` stays high until the condition ends; it is not a pulse. | 2.12.1.2 |
| REQ-IRQ-03 | `irq` reflects a change within ≤ 2 pclk cycles. **[Hint]** take `irq` from a flip-flop. | 2.12.1.3 |
| REQ-IRQ-04 | `rx_done_ie = 1`, read RXDATA → `irq` goes to 0. | 2.12.2.1 |
| REQ-IRQ-05 | `tx_done_ie = 1`, write `start_tx` → `tx_done = 0`, so `irq` goes to 0. | 2.12.2.2 |
| REQ-IRQ-06 | Enable `tx_done_ie` while `tx_done = 1` → `irq` rises to 1 immediately. | 2.12.3.1 |
| REQ-IRQ-07 | Enable `tx_done_ie` after `start_tx` (when `tx_done = 0`) → `irq` stays 0 and rises to 1 at the end of the frame. | 2.12.3.2 |

Software note: after reset `tx_done = 1`, so enabling `tx_done_ie` while idle raises an interrupt immediately.

---

## 12. Reset

### 12.1 Hard reset `presetn`

- Active low, asynchronous. Brings all registers, state machines and the APB interface to their reset values (§4).
- Outputs follow REQ-IO-02 and REQ-IO-03.

### 12.2 Soft reset `CTRL.soft_rst`

| Code | Requirement | Spec ID |
|---|---|---|
| REQ-SRST-01 | Writing 1 to CTRL[8] (`pstrb[1] = 1`): synchronous, active high. | 2.3.2.1 |
| REQ-SRST-02 | **[Team 11/11, extends the HTML]** Resets the entire UART part except the APB interface: TXDATA = 0, RXDATA = 0, CFG = 0, CTRL = 0, BAUD = 0x900D, IER = 0, STAT = 0x1, all state machines to IDLE. The CTRL write transaction completes normally, `pready = 1`. | 2.7.1.1 |
| REQ-SRST-03 | Aborts a frame being transmitted: `tx = 1`, `tx_done = 1`, the rest of the frame does not appear. | 2.7.1.2 |
| REQ-SRST-04 | Aborts a frame being received: `rx_busy = 0`, no `rx_done` from that frame. | 2.7.1.3 |
| REQ-SRST-05 | While soft reset is active: `rts_n = 1`. | 2.7.1.4 |
| REQ-SRST-06 | Completes within 2 pclk cycles; from the 3rd cycle APB commands are accepted and give correct results. | 2.7.2.1 |
| REQ-SRST-07 | The bit self-clears, reads return 0; the UART is not held in reset, no need to write 0 again. | 2.7.2.2 |
| REQ-SRST-08 | Never reports `pslverr`. | 2.7.3 |
| REQ-SRST-09 | Writing `soft_rst = 1` and `start_tx = 1` at the same time (e.g. CTRL = 0x101, `pstrb = 0011`): `soft_rst` has priority, the transmit command is dropped, `pslverr = 0`, even while transmitting. | 4.1.1.x |

---

## 13. Tiny Tapeout wrapper and spi2apb

### 13.1 Purpose

The APB interface of `apb_uart` needs 85 pins (51 in, 34 out), whereas a Tiny Tapeout tile has only 24 user pins. `spi2apb` turns each APB transaction into a 4-pin SPI frame that the RP2040 issues with its hardware SPI block. The `apb_uart` core keeps its APB interface; the grading testbench connects directly to APB, and `spi2apb` exists only in the wrapper.

### 13.2 Pins of the wrapper `tt_um_hust_apb_uart`

| Pin | Signal | Pin | Signal |
|---|---|---|---|
| `ui_in[0]` | `rx` | `uo_out[0]` | `tx` |
| `ui_in[1]` | `cts_n` | `uo_out[1]` | `rts_n` |
| `ui_in[2]` | `spi_cs_n` | `uo_out[2]` | `spi_miso` |
| `ui_in[3]` | `spi_sclk` | `uo_out[3]` | `tx_done` |
| `ui_in[4]` | `spi_mosi` | `uo_out[4]` | `rx_done` |
| `ui_in[5]` | `scan_en` (spare) | `uo_out[5]` | `parity_err` |
| `ui_in[6]` | `scan_in` (spare) | `uo_out[6]` | `irq` |
| `ui_in[7]` | `test_mode` (spare) | `uo_out[7]` | `scan_out` (spare) |

| Code | Requirement | Spec ID |
|---|---|---|
| REQ-TT-01 | Input/output pins are connected exactly as in the table above. | 1.3.1, 1.3.2 |
| REQ-TT-02 | The wrapper `clk` connects to `pclk`, `rst_n` connects to `presetn`. | 1.3.1 |
| REQ-TT-03 | `uio` is unused: `uio_oe = 0`. A team that does not implement DFT ties the spare pins to constants. | 1.3.2.2 |

The RP2040 on the demo board: supplies `clk` (125 MHz / 5 = 25 MHz), drives reset, is the SPI master accessing the registers through `spi2apb`, and receives `irq` on a GPIO.

### 13.3 SPI frame

Mode 0 (CPOL = 0, CPHA = 0), MSB first, a fixed **56-bit (7-byte)** frame for both reads and writes within one `spi_cs_n = 0`. MOSI is sampled on the rising SCLK edge and MISO changes on the falling edge. `f_SCLK ≤ f_pclk/10` (2.5 MHz at 25 MHz); one frame is 22.4 µs long.

| Byte | Bits | MOSI | MISO |
|---|---|---|---|
| B0 cmd | 0–7 | [7] rw (1 = write), [6:4] = 000, [3:0] = `paddr[5:2]` | 0x00 |
| B1 turnaround | 8–15 | 0x00 | 0x00 |
| B2–B5 data | 16–47 | write: `pwdata[31:0]` (MSB first); read: 0x00 | read: `prdata[31:0]`; write: 0x00 |
| B6 status | 48–55 | 0x00 | [1] `cmd_err`, [0] `pslverr` |

Register index in cmd[3:0]: 0 TXDATA, 1 RXDATA, 2 CFG, 3 CTRL, 4 STAT, 5 BAUD, 6 IER. `paddr = {6'b0, cmd[3:0], 2'b00}`.

| Code | Requirement | Spec ID |
|---|---|---|
| REQ-SPI-01 | The frame format is exactly as in the table above. | 2.13.1.1 |
| REQ-SPI-02 | MOSI is sampled on the rising edge, MISO changes on the falling edge. | 2.13.1.2 |
| REQ-SPI-03 | Works correctly at `f_SCLK = f_pclk/10`. | 2.13.1.3 |
| REQ-SPI-04 | `spi_cs_n = 1` → `MISO = 0`. MISO in B0 and B1 is always 0x00. | 2.13.1.4, 2.13.1.5 |
| REQ-SPI-05 | Write command: the APB transaction occurs after the 48th rising SCLK edge with `pwdata` from B2–B5; `pslverr` is output at bit 55 (B6[0]), leaving 7 spare SCLK cycles. | 2.13.2.1 |
| REQ-SPI-06 | Read command: the APB transaction occurs right after the 8th rising SCLK edge; `prdata` is latched within the 8 SCLK cycles of B1, before bit 16; it is output on MISO in B2–B5; B6[0] = `pslverr`. | 2.13.2.2 |
| REQ-SPI-07 | cmd[6:4] ≠ 000: no APB transaction is generated, B6[1] = `cmd_err` = 1. | 2.13.3.1 |
| REQ-SPI-08 | cmd[3:0] > 6: `apb_uart` returns `pslverr = 1` (E1), B6[0] = 1. | 2.13.3.2 |
| REQ-SPI-09 | `spi_cs_n` rising to 1 before bit 56 aborts the frame; a write command that has not reached bit 48 has no effect. | 2.13.4.1 |
| REQ-SPI-10 | A read command that already ran at bit 8 still has its side effects even if the frame is aborted (reading RXDATA clears the flags). | 2.13.4.2 |
| REQ-SPI-11 | `spi_cs_n`, `spi_sclk`, `spi_mosi` pass through 2 FFs in the pclk domain; SCLK shall not be used as a clock. | — |

The `f_pclk/10` limit: each half period of SCLK is 5 pclk cycles, enough for 2 synchronizer FFs and 1 edge-detect cycle.

---

## 14. Typical usage sequences

### 14.1 Transmit one character 0x41, 8N1, 115 200 baud (over SPI)

| Step | Operation | MOSI | MISO | Note |
|---|---|---|---|---|
| 1 | write CFG = 0x03 | 82 00 00 00 00 03 00 | 00 00 00 00 00 00 00 | `irq = 0` (IER = 0) |
| 2 | write BAUD = 0x900D | 85 00 00 00 90 0D 00 | 00 … 00 | |
| 3–4 | read STAT | 04 00 00 00 00 00 00 | 00 00 00 00 00 01 00 | `tx_done = 1`: TXDATA may be written |
| 5 | write TXDATA = 0x41 | 80 00 00 00 00 41 00 | 00 … 00 | |
| 6–7 | write CTRL.start_tx | 83 00 00 00 00 01 00 | 00 … 00 | `tx_done → 0` |
| 8 | write IER = 0x01 | 86 00 00 00 00 01 00 | 00 … 00 | Enabled while `tx_done = 0`, so `irq` stays 0 |
| 9–12 | (hardware) | — | — | `cts_n = 0` → 86.8 µs frame transmitted → `tx_done = 1` → `irq = 1` |
| 13–14 | read STAT | 04 00 00 00 00 00 00 | 00 00 00 00 00 01 00 | Confirms the interrupt source is `tx_done` |

Next character: repeat steps 5 and 6 → `tx_done = 0` so `irq = 0`. (Spec ID 2.14.1.1)

### 14.2 Receive one character 0x5A

| Step | Operation | MOSI | MISO | Note |
|---|---|---|---|---|
| 1 | write CFG = 0x03 | 82 00 00 00 00 03 00 | 00 … 00 | `rx_dis = 0` |
| 2 | write BAUD = 0x900D | 85 00 00 00 90 0D 00 | 00 … 00 | |
| 3 | write IER = 0x02 | 86 00 00 00 00 02 00 | 00 … 00 | `rx_done_ie` only; `tx_done = 1` does not raise an interrupt |
| 4–8 | (hardware) | — | — | `rts_n = 0` → frame received → `rx_done = 1`, `rts_n = 1` → `irq = 1` |
| 9–10 | read STAT | 04 00 00 00 00 00 00 | 00 00 00 00 00 03 00 | STAT = 0x3, no error flags |
| 11–12 | read RXDATA | 01 00 00 00 00 00 00 | 00 00 00 00 00 5A 00 | Clears `rx_done`; APB runs after bit 8 |
| 13–14 | (hardware) | — | — | `irq = 0`; `rts_n = 0` |

(Spec ID 2.14.1.2)

---

## 15. Review gate schedule and completion criteria

| Deadline | Gate | Passing threshold |
|---|---|---|
| Tue 10/11/2026 | G1 Specification | Register table, BAUD table and error at 25 MHz, fractional accumulator design, block diagram with signal names, verification plan mapping every item to a test |
| Sat 14/11/2026 | G2 RTL + lint | 0 Verilator `-Wall` warnings; 0 latches; one clock net; constraints of §3.2 |
| Wed 18/11/2026 | G3 DV, G4 netlist | 20 public tests pass on RTL and on the Yosys netlist; statement and branch coverage ≥ 90 % (Questa) |
| Sat 21/11/2026 | G6 STA, LEC (G5 DFT is bonus) | SDC 40 ns; WS setup ≥ 0 at the ss corner, hold ≥ 0 at all corners; eqy equivalent |
| Tue 24/11/2026 | G7 Layout | LibreLane full flow, 1×1 tile, post-route WS ≥ 0 |
| Thu 26/11/2026 23:59 | G8 GLS, G9 sign-off | GLS with SDF at tt, ss, ff; DRC = 0, LVS matches, antenna = 0; TT GitHub Actions green; report with all 10 items of part E |
| Sat 28/11/2026 | Defense | The committee runs 108 hidden tests and the common LibreLane configuration |

Verification completion criteria: all Priority 1 tests PASS; no SVA failures; statement and branch coverage ≥ 90 %.

---

## 16. Inconsistencies in the HTML and open questions

### 16.1 Inconsistencies in the HTML (interpretation chosen)

| # | Discrepancy | Followed |
|---|---|---|
| 1 | The `uart_rx` block in §3 says "check the first stop bit", while §7 requires checking **every** stop bit. | §7 (specification 6.2). |
| 2 | E3 catches a write to CTRL with `start_tx = 1` while busy, but §12 says `soft_rst` has priority and never reports `pslverr`. | A write with `soft_rst = 1` is not an error (REQ-SRST-09). |
| 3 | §12 lists only CFG, BAUD, IER when saying "all registers return to reset". | The team decided to reset TXDATA and RXDATA as well (REQ-SRST-02). |

### 16.2 Open questions to ask the teacher

| # | Question |
|---|---|
| Q1 | Frequency of `pclk`: keep 25 MHz as in the HTML or use 50 MHz? The Tiny Tapeout pad allows up to about 66 MHz; 50 MHz needs timing closure at 20 ns, and the whole BAUD table and the BAUD reset value (0x201B) would have to change. |
| Q2 | `tx_dis = 1` then write `start_tx`: does `tx_done` stay 1 or drop to 0? The HTML only says "transmitter disabled". |
| Q3 | Writing `tx_dis = 1` / `rx_dis = 1` while busy: the HTML blocks it with E4 (a CFG lane 0 write while busy is an error), so it can only be changed when idle. Is a way to disable immediately in mid-frame needed? |
| Q4 | REQ-RX-09 and REQ-RX-10 are team decisions and must be confirmed to match the hidden testbench. |

---

## 17. Appendix: quick-reference tables

### 17.1 Commonly used CFG values

| Frame | CFG | Bits/frame |
|---|---|---|
| 5N1 (reset) | 0x00 | 7 |
| 8N1 | 0x03 | 10 |
| 8E1 | 0x1B | 11 |
| 8O1 | 0x0B | 11 |
| 8N2 | 0x07 | 11 |
| 8E2 | 0x1F | 12 |
| 7E1 | 0x1A | 10 |

### 17.2 Key timing

| Event | Limit |
|---|---|
| `start_tx` → `tx_done = 0` | Next cycle |
| End of last stop bit → `tx_done = 1` | ≤ 2 pclk cycles |
| Last stop sampling point → `rx_done = 1` | ≤ 1 bit |
| Source change → `irq` | ≤ 2 pclk cycles |
| Soft reset completes | 2 pclk cycles, APB accepts commands from cycle 3 |
| `rx`, `cts_n` synchronization | ≥ 2 pclk cycles |
| SPI frame at 2.5 MHz | 22.4 µs |
| 8N1 character at 115 200 baud | 86.8 µs |

### 17.3 pslverr matrix by register

| Register | Read | Write when idle | Write when `tx_done = 0` | Write when `rx_busy = 1`, `tx_done = 1` |
|---|---|---|---|---|
| TXDATA | 0 | 0 | **E3** (`pstrb ≠ 0`) | 0 |
| RXDATA | 0 | **E2** | **E2** | **E2** |
| CFG | 0 | 0 | **E4** if `pstrb[0]` | **E4** if `pstrb[0]` |
| CTRL | 0 | 0 | **E3** if `pstrb[0]` & `pwdata[0]` & not combined with `soft_rst` | 0 |
| STAT | 0 | **E2** | **E2** | **E2** |
| BAUD | 0 | **E5** if new `div_int` = 0 | **E4** if `pstrb[1:0] ≠ 0` | **E4** if `pstrb[1:0] ≠ 0` |
| IER | 0 | 0 | 0 | 0 |
| Out of table / misaligned | **E1**, returns 0 | **E1** | **E1** | **E1** |
