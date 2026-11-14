# Đặc tả hệ thống APB-UART (apb_uart + wrapper Tiny Tapeout)

| Mục | Nội dung |
|---|---|
| Tài liệu gốc | `HD-APB-UART-tuong-tac.html` – Đặc tả 1.1 (01/11/2026), ET4030 |
| Tài liệu tham khảo | `Product Requirements - UART.pdf`, `UART Specs 3110 Product requirement.pdf` (buổi họp 31/10/2026) |
| Kế hoạch kiểm chứng | `UART_APB_VerificationSpecification.xlsx` (sheet Veri_spec, Test_plan) |
| Phiên bản | 1.0 – 11/11/2026 |
| Nguyên tắc | Mọi yêu cầu theo HTML 1.1. Chỗ HTML không nói, nhóm quyết định và đánh dấu **[Nhóm 11/11]**. Chỗ HTML chỉ là gợi ý hiện thực (không bắt buộc) đánh dấu **[Gợi ý]**. |

Quy ước: mỗi yêu cầu có mã `REQ-xx-nn`. Cột "Spec ID" ở cuối mỗi bảng trỏ sang dòng tương ứng trong sheet Veri_spec. "Phải" là bắt buộc; "nên" là khuyến nghị.

---

## Mục lục

1. [Tổng quan](#1-tổng-quan)
2. [Giao diện cổng](#2-giao-diện-cổng)
3. [Kiến trúc và ràng buộc RTL](#3-kiến-trúc-và-ràng-buộc-rtl)
4. [Bản đồ thanh ghi](#4-bản-đồ-thanh-ghi)
5. [Giao tiếp APB và pslverr](#5-giao-tiếp-apb-và-pslverr)
6. [Bộ sinh baud phân số](#6-bộ-sinh-baud-phân-số)
7. [Khung UART](#7-khung-uart)
8. [Bộ phát (TX)](#8-bộ-phát-tx)
9. [Bộ thu (RX)](#9-bộ-thu-rx)
10. [Điều khiển luồng rts_n / cts_n](#10-điều-khiển-luồng-rts_n--cts_n)
11. [Ngắt](#11-ngắt)
12. [Reset](#12-reset)
13. [Wrapper Tiny Tapeout và spi2apb](#13-wrapper-tiny-tapeout-và-spi2apb)
14. [Trình tự sử dụng điển hình](#14-trình-tự-sử-dụng-điển-hình)
15. [Lịch cổng duyệt và tiêu chí hoàn tất](#15-lịch-cổng-duyệt-và-tiêu-chí-hoàn-tất)
16. [Điểm không nhất quán trong HTML và câu hỏi mở](#16-điểm-không-nhất-quán-trong-html-và-câu-hỏi-mở)
17. [Phụ lục: bảng tra nhanh](#17-phụ-lục-bảng-tra-nhanh)

---

## 1. Tổng quan

`apb_uart` là bộ thu phát UART song công có giao tiếp APB4 và điều khiển luồng phần cứng `rts_n`/`cts_n`. Mỗi chiều đệm đúng một ký tự (không FIFO). Thiết kế đi hết luồng tới GDS trên Tiny Tapeout (sky130A, tile 1×1). Trên chip, khối được bọc trong wrapper `tt_um_hust_apb_uart`; RP2040 trên board demo truy cập thanh ghi qua cầu `spi2apb`.

```
RP2040 (SPI master) ──SPI 4 dây──► spi2apb ──APB4──► apb_uart ──tx/rx/rts_n/cts_n──► thiết bị ngoại vi
        ▲                                               │
        └──────────────── irq (GPIO) ◄──────────────────┘
```

| Mã | Yêu cầu | Spec ID |
|---|---|---|
| REQ-GEN-01 | Một miền clock duy nhất `pclk`, danh định **25 MHz** (RP2040 chia 125 MHz cho 5). STA ở chu kỳ 40 ns. | 2.8.x |
| REQ-GEN-02 | Reset `presetn`, tích cực mức thấp, tác động không đồng bộ. Không có `clk`, `reset_n` riêng. | 1.2.2, 2.6.1 |
| REQ-GEN-03 | Khung: 1 start bit; 5–8 bit dữ liệu, LSB trước; parity không có / lẻ / chẵn; 1 hoặc 2 stop bit. Đủ **24 dạng**, bắt buộc cho cả TX và RX. | 2.9.1.5, 2.10.1.1 |
| REQ-GEN-04 | Tốc độ cấu hình bằng thanh ghi BAUD (bộ chia phân số bước 1/16, lấy mẫu 16×). 2 400–115 200 baud bắt buộc; 230 400–921 600 baud cộng điểm. | 2.8.2.1, 2.8.2.2 |
| REQ-GEN-05 | Đệm 1 ký tự TX (TXDATA), 1 ký tự RX (RXDATA), không FIFO. | — |
| REQ-GEN-06 | APB4, `pready = 1` cố định (0 chu kỳ chờ), `pslverr` cho đúng 5 trường hợp E1–E5. | 1.1.x, 3.1.x |

---

## 2. Giao diện cổng

### 2.1 Cổng của `apb_uart`

Tên module **phải** là `apb_uart`; tên, độ rộng, hướng cổng đúng bảng dưới vì testbench chấm điểm nối theo tên (REQ-IO-01, Spec ID 1.2.1).

| Cổng | Rộng | Hướng | Mô tả |
|---|---|---|---|
| `pclk` | 1 | vào | Clock duy nhất |
| `presetn` | 1 | vào | Reset, mức thấp, không đồng bộ |
| `psel` | 1 | vào | Chọn khối |
| `penable` | 1 | vào | Pha truy cập |
| `pwrite` | 1 | vào | 1 ghi, 0 đọc |
| `paddr` | 12 | vào | Địa chỉ byte |
| `pstrb` | 4 | vào | Byte lane ghi |
| `pwdata` | 32 | vào | Dữ liệu ghi |
| `pready` | 1 | ra | Luôn 1 |
| `pslverr` | 1 | ra | Lỗi, chỉ có nghĩa ở pha truy cập |
| `prdata` | 32 | ra | Dữ liệu đọc |
| `rx` | 1 | vào | Nối tiếp vào, không đồng bộ |
| `cts_n` | 1 | vào | Clear-to-send, tích cực thấp, không đồng bộ |
| `tx` | 1 | ra | Nối tiếp ra, nghỉ = 1 |
| `rts_n` | 1 | ra | Request-to-send, tích cực thấp |
| `irq` | 1 | ra | Ngắt mức, tích cực cao |

### 2.2 Giá trị output khi và sau reset

| Mã | Yêu cầu | Spec ID |
|---|---|---|
| REQ-IO-02 | Khi `presetn = 0` và ngay sau reset: `tx = 1`, `rts_n = 1`, `irq = 0`, `pslverr = 0`, `pready = 1`. | 1.2.2 |
| REQ-IO-03 | `presetn` xuống 0 thì output về giá trị reset ngay, không cần sườn `pclk`. | 2.6.1 |
| REQ-IO-04 | `rx`, `cts_n` phải qua ít nhất 2 flip-flop đồng bộ trước logic đầu tiên (kiểm tra Q6: netlist có ≥ 2 flip-flop từ cổng vào). | 1.2.3 |

Lưu ý: sau khi thả reset, `rts_n` chuyển sang 0 vì `rx_dis = 0` và `rx_done = 0` (xem §10).

---

## 3. Kiến trúc và ràng buộc RTL

### 3.1 Sơ đồ khối gợi ý

Đội được chia khối khác, miễn giữ các ràng buộc ở §3.2.

```
                 ┌──────────── tt_um_hust_apb_uart (wrapper) ────────────┐
 spi_cs_n ──►┌─────────┐ APB  ┌───────────────── apb_uart ─────────────┐│
 spi_sclk ──►│ spi2apb │─────►│ apb_if + giải mã ─► TXDATA, CTRL ──► uart_tx ─┼─► tx
 spi_mosi ──►│         │◄─────│        │            CFG, BAUD ──► baud_gen    ││
 spi_miso ◄──└─────────┘      │        │            RXDATA, STAT, IER ◄ uart_rx ◄─┼── rx (sync 2FF)
                              │        └──► irq                    rts_n ─┼─► rts_n
                              │                         cts_n (sync 2FF) ◄┼── cts_n
                              └────────────────────────────────────────┘│
                 └────────────────────────────────────────────────────────┘
```

| Khối | Chức năng | Gợi ý hiện thực **[Gợi ý]** |
|---|---|---|
| `spi2apb` | SPI mode 0 slave, khung 56 bit; sinh 1 giao dịch APB mỗi khung (đọc sau bit 8, ghi sau bit 48). Chỉ có trong wrapper. | Đồng bộ `cs_n`, `sclk`, `mosi` bằng 2 FF rồi phát hiện sườn `sclk` trong miền `pclk`. |
| `apb_if` + giải mã | Giải mã `paddr` thành 7 thanh ghi, sinh xung ghi theo `pstrb`, chọn `prdata`, tính `pslverr` (E1–E5) trong cùng chu kỳ truy cập. | `pslverr`, `prdata` là tổ hợp của trạng thái hiện tại; lệnh lỗi không sinh xung ghi. |
| TXDATA, CTRL | Lưu `tx_data`; `start_tx`, `soft_rst` là xung 1 chu kỳ (đọc trả 0). | Che bit cao của `tx_data` tại `uart_tx`, giữ nguyên giá trị trong thanh ghi. |
| CFG, BAUD | Cấu hình khung tới `uart_tx`/`uart_rx`; `div_int`, `div_frac` tới `baud_gen`. | Chỉ cập nhật khi `tx_done = 1` và `rx_busy = 0` (E4) nên cấu hình không đổi giữa khung. |
| RXDATA, STAT, IER | Cờ `rx_done`, `parity_err`, `frame_err`, `overrun`; IER chọn nguồn ngắt. | Lấy `irq` từ flip-flop; `overrun` đặt khi `rx_valid` đến lúc `rx_done = 1`, giữ RXDATA cũ. |
| `uart_tx` | FSM IDLE → WAIT_CTS → START → DATA → PARITY → STOP; thanh ghi dịch; 16 tick/bit. | `cts_n` chỉ xét trước start bit; `tx_done` lên ở cuối stop bit cuối. |
| `baud_gen` | Bộ tích luỹ phân số, phát xung `tick` rộng 1 chu kỳ `pclk`. | `tick` là xung cho phép, không phải clock. Ở D = 1,6875, tick cách nhau 1 hoặc 2 chu kỳ. |
| `uart_rx` | Phát hiện sườn xuống, kiểm tra lại start ở tick 8, lấy mẫu mỗi 16 tick, tính parity, kiểm tra stop, sinh `rx_valid`. | Có thể lấy đa số 3 mẫu quanh giữa bit. Xung thấp ngắn hơn 0,4 bit không tạo khung. |
| sync 2FF | Đồng bộ `rx`, `cts_n`. | — |

### 3.2 Ràng buộc RTL (cổng G2)

| Mã | Yêu cầu |
|---|---|
| REQ-RTL-01 | Một net clock `pclk`; không có clock sinh bằng logic; các khối con dùng xung cho phép `tick`. |
| REQ-RTL-02 | `verilator --lint-only -Wall`: 0 cảnh báo. |
| REQ-RTL-03 | Yosys `proc`: không có latch. |
| REQ-RTL-04 | `rx`, `cts_n` qua 2 flip-flop đồng bộ (= REQ-IO-04). |
| REQ-RTL-05 | Trong `rtl/` không dùng `initial`, `#delay`, `$display`; không gọi trực tiếp ô `sky130_`. |
| REQ-RTL-06 | Testbench chỉ truy cập `apb_uart` qua cổng. |

---

## 4. Bản đồ thanh ghi

Địa chỉ byte, căn 4 byte. Bit rfu đọc trả 0, ghi không tác dụng. Giá trị reset bằng 0, trừ `STAT.tx_done = 1` (STAT = `0x0000_0001`) và `BAUD = 0x0000_900D`.

| Địa chỉ | Tên | Quyền | Reset | Byte lane có trường |
|---|---|---|---|---|
| 0x00 | TXDATA | RW | 0x0000_0000 | lane 0 |
| 0x04 | RXDATA | RO | 0x0000_0000 | lane 0 |
| 0x08 | CFG | RW | 0x0000_0000 | lane 0 |
| 0x0C | CTRL | RW (đọc trả 0) | 0x0000_0000 | lane 0 (start_tx), lane 1 (soft_rst) |
| 0x10 | STAT | RO | 0x0000_0001 | lane 0 |
| 0x14 | BAUD | RW | 0x0000_900D | lane 0, lane 1 |
| 0x18 | IER | RW | 0x0000_0000 | lane 0 |

### 4.1 TXDATA (0x00, RW)

| Bit | Trường | Mô tả |
|---|---|---|
| [7:0] | `tx_data` | Ký tự cần phát. Khi N < 8 chỉ `tx_data[N−1:0]` được phát, nhưng thanh ghi giữ và đọc lại đủ 8 bit đã ghi. |
| [31:8] | rfu | |

### 4.2 RXDATA (0x04, RO)

| Bit | Trường | Mô tả |
|---|---|---|
| [7:0] | `rx_data` | Ký tự đã nhận; `rx_data[7:N] = 0`. **Đọc thanh ghi này xoá `rx_done`, `parity_err`, `frame_err`, `overrun`.** |
| [31:8] | rfu | |

### 4.3 CFG (0x08, RW)

| Bit | Trường | Mô tả |
|---|---|---|
| [1:0] | `data_bits` | 00: 5, 01: 6, 10: 7, 11: 8 bit dữ liệu |
| [2] | `stop_bits` | 0: 1 stop, 1: 2 stop |
| [3] | `parity_en` | 1: có parity |
| [4] | `parity_type` | 1: chẵn, 0: lẻ |
| [5] | `tx_dis` | 1: tắt bộ phát |
| [6] | `rx_dis` | 1: tắt bộ thu, `rts_n = 1` |
| [31:7] | rfu | |

Giá trị reset CFG = 0 ứng với khung **5N1**. Số bit mỗi khung = 1 + N + parity_en + (stop_bits + 1).

### 4.4 CTRL (0x0C, RW, đọc trả 0)

| Bit | Trường | Mô tả |
|---|---|---|
| [0] | `start_tx` | Ghi 1: phát TXDATA. Xung 1 chu kỳ, đọc trả 0. |
| [7:1] | rfu | |
| [8] | `soft_rst` | Ghi 1: reset mềm. Xung 1 chu kỳ, tự về 0, đọc trả 0, không cần ghi lại 0. |
| [31:9] | rfu | |

`start_tx` (lane 0) và `soft_rst` (lane 1) nằm ở hai byte khác nhau để chọn riêng bằng `pstrb`.

### 4.5 STAT (0x10, RO)

| Bit | Trường | Reset | Mô tả |
|---|---|---|---|
| [0] | `tx_done` | 1 | 1: bộ phát rảnh |
| [1] | `rx_done` | 0 | 1: RXDATA có ký tự chưa đọc |
| [2] | `parity_err` | 0 | Ký tự trong RXDATA sai parity |
| [3] | `rx_busy` | 0 | Đang nhận khung |
| [4] | `tx_dis` | 0 | Bản sao `CFG.tx_dis` |
| [5] | `rx_dis` | 0 | Bản sao `CFG.rx_dis` |
| [6] | `frame_err` | 0 | Có stop bit bằng 0 (kiểm tra cả hai khi `stop_bits = 1`) |
| [7] | `overrun` | 0 | Khung mới bị bỏ vì `rx_done = 1` |
| [31:8] | rfu | 0 | |

### 4.6 BAUD (0x14, RW)

| Bit | Trường | Mô tả |
|---|---|---|
| [11:0] | `div_int` | Phần nguyên của D, phải ≥ 1 (lane 0 chứa [7:0], lane 1 chứa [11:8]) |
| [15:12] | `div_frac` | Phần phân số của D, đơn vị 1/16 (lane 1) |
| [31:16] | rfu | |

### 4.7 IER (0x18, RW)

| Bit | Trường | Mô tả |
|---|---|---|
| [0] | `tx_done_ie` | Ngắt khi `tx_done = 1` |
| [1] | `rx_done_ie` | Ngắt khi `rx_done = 1` |
| [2] | `err_ie` | Ngắt khi có `parity_err`, `frame_err` hoặc `overrun` |
| [31:3] | rfu | |

### 4.8 Yêu cầu chung về thanh ghi

| Mã | Yêu cầu | Spec ID |
|---|---|---|
| REQ-REG-01 | 7 thanh ghi ở đúng địa chỉ trên. | 2.1.1.1 |
| REQ-REG-02 | Giá trị reset đúng bảng trên. | 2.1.1.2 |
| REQ-REG-03 | TXDATA[7:0], CFG[6:0], BAUD[15:0], IER[2:0] ghi rồi đọc lại đúng khi TX, RX rảnh. | 2.1.1.3 |
| REQ-REG-04 | Bit rfu đọc trả 0, ghi không tác dụng. | 2.1.1.4 |
| REQ-REG-05 | `STAT[4] = CFG[5]`, `STAT[5] = CFG[6]` ở mọi giá trị. | 2.4.3.1 |
| REQ-REG-06 | Cờ lỗi STAT[2], [6], [7] reset 0, xoá khi đọc RXDATA. | 2.4.4.x |

---

## 5. Giao tiếp APB và pslverr

### 5.1 Giao dịch

| Mã | Yêu cầu | Spec ID |
|---|---|---|
| REQ-APB-01 | Mỗi truyền gồm 1 chu kỳ setup (`psel=1, penable=0`) và đúng 1 chu kỳ truy cập (`psel=penable=1`), không chờ. | 1.1.1.1 |
| REQ-APB-02 | `pready = 1` ở mọi chu kỳ sau reset, kể cả khi TX, RX bận. | 1.1.1.2 |
| REQ-APB-03 | Thanh ghi đổi ở sườn lên kết thúc pha truy cập; ở pha setup chưa đổi. | 1.1.1.3 |
| REQ-APB-04 | `prdata`, `pslverr` chỉ có nghĩa trong pha truy cập; `pslverr` chỉ có thể bằng 1 khi `psel && penable`. | 1.1.1.4, 1.1.3.1 |
| REQ-APB-05 | `psel = 0`: không có truyền, không thanh ghi nào đổi, đọc RXDATA không xảy ra. | 1.1.1.5 |
| REQ-APB-06 | Chỉ byte có `pstrb[i] = 1` được ghi. | 1.1.2.1 |
| REQ-APB-07 | Ghi TXDATA, CFG, CTRL, BAUD, IER với `pstrb = 0000`: không đổi thanh ghi, không có hành động, `pslverr = 0`, kể cả khi đang bận. | 1.1.2.2 |

Ví dụ giản đồ HTML §8: (1) ghi BAUD = 0x0000_900D, đạt; (2) đọc STAT trả 0x0000_0001; (3) ghi 0x020 → `pslverr = 1` (E1), không thanh ghi nào đổi.

### 5.2 Các trường hợp pslverr

`pslverr = 1` **chỉ** trong 5 trường hợp sau. Lệnh bị lỗi: không thanh ghi nào đổi, không hành động nào được kích hoạt (REQ-ERR-06, Spec ID 3.1.6).

| Mã | Điều kiện | Spec ID |
|---|---|---|
| **E1** | `paddr` ngoài {0x00, 0x04, 0x08, 0x0C, 0x10, 0x14, 0x18}, kể cả không căn 4 byte. Đọc trả 0. | 3.1.1.x |
| **E2** | Ghi RXDATA hoặc STAT (bất kể `pstrb`). | 3.1.2 |
| **E3** | Khi `tx_done = 0`: ghi TXDATA (có `pstrb ≠ 0`), hoặc ghi CTRL có `pstrb[0] = 1` và `pwdata[0] = 1`. | 3.1.3.x |
| **E4** | Khi `tx_done = 0` hoặc `rx_busy = 1`: ghi CFG có `pstrb[0] = 1`, hoặc ghi BAUD có `pstrb[0] = 1` hoặc `pstrb[1] = 1`. | 3.1.4.x |
| **E5** | Ghi BAUD mà `div_int` **sau khi ghi** (gộp lane được ghi với giá trị hiện tại) bằng 0. | 3.1.5 |

Thứ tự kiểm tra theo bộ kiểm tra của HTML: E1 → E2 → E3 → E4 → E5. Tất cả đều cho cùng một `pslverr = 1`, thứ tự chỉ cần cho việc phân loại khi viết test.

### 5.3 Các truy cập hợp lệ (không được báo lỗi)

| Mã | Yêu cầu | Spec ID |
|---|---|---|
| REQ-ERR-07 | `rx_busy = 1`, `tx_done = 1`: ghi TXDATA và `start_tx` đều `pslverr = 0`; TX và RX chạy cùng lúc đúng. | 3.2.1.1 |
| REQ-ERR-08 | Khi bận: ghi CFG với `pstrb[0] = 0`, ghi BAUD với `pstrb[1:0] = 00` → `pslverr = 0`. | 3.2.1.2 |
| REQ-ERR-09 | `tx_done = 0`: ghi CTRL với `pwdata[0] = 0` → `pslverr = 0`. | 3.2.1.3 |
| REQ-ERR-10 | Ghi IER và đọc mọi thanh ghi trong bảng ở mọi trạng thái → `pslverr = 0`. | 3.2.1.4 |
| REQ-ERR-11 | Ghi `soft_rst = 1` không bao giờ báo `pslverr`, kể cả khi bận hoặc kèm `start_tx = 1`. | 2.7.3, 4.1.1.x |
| REQ-ERR-12 | Đang chờ `cts_n` (`tx_done = 0`): E3, E4 vẫn áp dụng. | 3.1.4.3 |

---

## 6. Bộ sinh baud phân số

### 6.1 Công thức

```
D        = div_int + div_frac/16
Baud     = f_pclk / (16 · D)
1 bit    = 16 tick = 16·div_int + div_frac chu kỳ pclk   (đúng tuyệt đối cho mọi bit)
D_thực   = round(16 · f_pclk / (16 · baud)) / 16
Sai số   = (f_pclk / (16 · D_thực) − baud) / baud
```

### 6.2 Bộ đếm

| Bộ đếm | Khối | Đếm gì | Phạm vi | Rộng |
|---|---|---|---|---|
| `cnt` | baud_gen | Chu kỳ pclk trong một chu kỳ tick; đếm 0 … L−1 rồi phát tick, L = div_int + carry | 0 … 4095 | 12 bit |
| `acc` | baud_gen | Phần lẻ tích luỹ (đơn vị 1/16 chu kỳ); mỗi tick: `acc ← (acc + div_frac) mod 16`, `carry = (acc + div_frac ≥ 16)` | 0 … 15 | 4 bit |
| `tick_cnt` | uart_tx, uart_rx | Tick trong một bit; RX lấy mẫu khi `tick_cnt = 8` | 0 … 15 | 4 bit |
| `bit_idx` | uart_tx, uart_rx | Vị trí bit: 0 = start, 1…N dữ liệu, rồi parity, stop | 0 … 11 | 4 bit |

Trong 16 tick, `acc` tràn đúng `div_frac` lần và quay về giá trị đầu bit, nên mọi bit dài đúng 16·D chu kỳ. Ví dụ D = 14,125 (div_int = 14, div_frac = 2): 226 chu kỳ/bit = 14 tick dài 14 + 2 tick dài 15; ở 25 MHz là 9,04 µs (110 619 baud). Sau reset `acc = 0`.

### 6.3 Bảng BAUD ở 25 MHz

| Baud | div_int | div_frac | D | BAUD | Chu kỳ/bit | Sai số | Mức |
|---|---|---|---|---|---|---|---|
| 2 400 | 651 | 1 | 651,0625 | 0x128B | 10 417 | −0,003 % | Bắt buộc |
| 4 800 | 325 | 8 | 325,5 | 0x8145 | 5 208 | +0,01 % | Bắt buộc |
| 9 600 | 162 | 12 | 162,75 | 0xC0A2 | 2 604 | +0,01 % | Bắt buộc |
| 19 200 | 81 | 6 | 81,375 | 0x6051 | 1 302 | +0,01 % | Bắt buộc |
| 38 400 | 40 | 11 | 40,6875 | 0xB028 | 651 | +0,01 % | Bắt buộc |
| 57 600 | 27 | 2 | 27,125 | 0x201B | 434 | +0,01 % | Bắt buộc |
| 115 200 | 13 | 9 | 13,5625 | 0x900D | 217 | +0,01 % | Bắt buộc (reset) |
| 230 400 | 6 | 13 | 6,8125 | 0xD006 | 109 | −0,45 % | Cộng điểm |
| 460 800 | 3 | 6 | 3,375 | 0x6003 | 54 | +0,47 % | Cộng điểm |
| 921 600 | 1 | 11 | 1,6875 | 0xB001 | 27 | +0,47 % | Cộng điểm |

So sánh: bộ chia nguyên lấy mẫu 16× cho −3,12 % ở 115 200 baud (vượt ±1 %), lý do dùng bộ chia phân số.

| Mã | Yêu cầu | Spec ID |
|---|---|---|
| REQ-BAUD-01 | Mọi bit trên `tx` dài đúng `16·div_int + div_frac` chu kỳ pclk. | 2.8.1.1 |
| REQ-BAUD-02 | Reset BAUD = 0x900D: 217 chu kỳ/bit, 115 200 baud ở 25 MHz. | 2.8.1.2 |
| REQ-BAUD-03 | Phát và nhận đúng ở 7 tốc độ bắt buộc, sai số trong ±1,0 %. | 2.8.2.1 |
| REQ-BAUD-04 | Phát và nhận đúng ở 3 tốc độ cộng điểm. | 2.8.2.2 |
| REQ-BAUD-05 | D nhỏ nhất 1,6875: bit vẫn đúng 27 chu kỳ dù tick cách nhau 1 hoặc 2 chu kỳ. | 4.4.1 |
| REQ-BAUD-06 | `div_int = 0` không hợp lệ → E5. | 3.1.5 |

---

## 7. Khung UART

Thứ tự trên đường truyền:

```
idle(1) │ start(0) │ D0 │ D1 │ … │ D(N−1) │ [parity] │ stop(1) │ [stop2(1)] │ idle(1)
```

| Mã | Yêu cầu | Spec ID |
|---|---|---|
| REQ-FRM-01 | Start bit bằng 0, sau đó dữ liệu LSB trước. | 2.9.1.1 |
| REQ-FRM-02 | N < 8: chỉ `tx_data[N−1:0]` được phát. | 2.9.1.2 |
| REQ-FRM-03 | Parity đứng sau dữ liệu, tính trên N bit được phát. Chẵn: tổng số bit 1 của dữ liệu và parity là số chẵn; lẻ: số lẻ. | 2.9.1.3 |
| REQ-FRM-04 | 1 hoặc 2 stop bit mức 1, mỗi bit dài 16·D chu kỳ. | 2.9.1.4 |
| REQ-FRM-05 | Đủ 24 dạng (4 độ dài × 3 parity × 2 stop) đều phát và nhận đúng. | 2.9.1.5, 2.10.1.1 |

Độ dài khung n (start tới stop cuối) = 1 + N + parity + số stop: từ 7 (5N1) tới 12 (8E2/8O2). Ví dụ 8N1 ở 115 200 baud: 10 bit = 86,8 µs.

---

## 8. Bộ phát (TX)

### 8.1 Hoạt động

1. Phần mềm đọc STAT, chờ `tx_done = 1` (và `rx_busy = 0` nếu cần đổi CFG, BAUD).
2. Ghi CFG, BAUD nếu khác lần trước; ghi TXDATA.
3. Ghi `CTRL.start_tx = 1` → `tx_done` xuống 0 ở chu kỳ sau.
4. Bộ phát chờ `cts_n = 0` (sau đồng bộ 2 FF), trong lúc chờ `tx = 1`.
5. Phát start, dữ liệu, parity, stop. `cts_n` lên 1 giữa khung không dừng khung.
6. `tx_done` lên 1 ở cuối stop bit cuối (≤ 2 chu kỳ pclk); `irq` lên nếu `tx_done_ie = 1`.

### 8.2 Yêu cầu

| Mã | Yêu cầu | Spec ID |
|---|---|---|
| REQ-TX-01 | Ghi `start_tx = 1` khi `tx_done = 1` → phát đúng 1 khung từ TXDATA. | 2.3.1.1 |
| REQ-TX-02 | `pwdata[0] = 0` hoặc `pstrb[0] = 0` → không có khung. | 2.3.1.2 |
| REQ-TX-03 | Đọc CTRL[0] luôn trả 0, kể cả ngay sau khi ghi 1. | 2.3.1.3 |
| REQ-TX-04 | `tx_done` = 1 khi rảnh, = 0 từ sau `start_tx` tới hết khung. | 2.4.1.1 |
| REQ-TX-05 | `tx_done` xuống 0 ở chu kỳ sau lệnh ghi `start_tx`. | 2.9.2.1 |
| REQ-TX-06 | `tx_done` lên 1 ở cuối stop bit cuối, trong ≤ 2 chu kỳ pclk. | 2.9.2.2 |
| REQ-TX-07 | `tx_done = 1` thì ghi TXDATA, `start_tx` tiếp: ký tự kế phát đúng. | 2.9.2.3 |
| REQ-TX-08 | `start_tx` khi `cts_n = 1`: `tx = 1`, `tx_done = 0`, chờ tới khi `cts_n = 0` mới phát start bit. | 2.9.3.1 |
| REQ-TX-09 | `cts_n` chỉ xét trước start bit; lên 1 giữa khung thì khung vẫn phát hết. | 4.2.1 |
| REQ-TX-10 | `tx_dis = 1`: ghi `start_tx` không tạo khung, `tx = 1`, `pslverr = 0`. `tx_dis = 0`: phát bình thường. | 2.2.2.1 |
| REQ-TX-11 | Ghi TXDATA hoặc `start_tx` khi `tx_done = 0` → E3, khung đang phát không đổi, không có khung phụ. | 3.1.3.x |

---

## 9. Bộ thu (RX)

### 9.1 Lấy mẫu

- `rx` qua 2 FF đồng bộ, phát hiện sườn xuống.
- Kiểm tra lại start ở tick 8 (giữa start bit); hợp lệ thì `rx_busy = 1`.
- Sau đó lấy mẫu mỗi 16 tick, tức ở giữa mỗi bit theo đồng hồ bộ thu.
- **Kiểm tra mọi stop bit** theo `stop_bits`, mỗi stop bit lấy mẫu ở tick 8. Có stop bit bằng 0 → `frame_err = 1`, nên khung thiếu stop bit thứ hai vẫn bị phát hiện.
- Stop bit thứ nhất của khung 2 stop vẫn đếm đủ 16 tick. Chỉ nửa sau của **stop bit cuối** bị rút ngắn: lấy mẫu xong stop bit cuối, bộ thu đặt `rx_done` và về IDLE ngay. Lý do: khi bên phát nhanh hơn, start bit của khung kế có thể đến trước khi stop bit cuối theo đồng hồ bộ thu kết thúc.

### 9.2 Dung sai tốc độ

Bộ thu lấy mẫu bit k tại `t_k = (k + 0,5)·T + d·T/16`, với d ∈ [0, 1] tick là trễ phát hiện sườn start (d = 1 xấu nhất; trễ 2 FF bỏ qua khi D ≥ 2). Bên phát lệch e: `T_tx = T/(1 + e)`. Bit cuối (k = n−1) đúng khi:

```
|e| < (0,5 − 1/16) / (n − 0,5)
n = 12: 3,80 %   n = 11: 4,17 %   n = 10: 4,61 %   n = 7: 6,73 %
```

### 9.3 Yêu cầu

| Mã | Yêu cầu | Spec ID |
|---|---|---|
| REQ-RX-01 | Đủ 24 dạng khung đều nhận đúng byte, không có cờ lỗi. | 2.10.1.1 |
| REQ-RX-02 | N < 8: `rx_data[7:N] = 0`. | 2.10.1.2 |
| REQ-RX-03 | Parity tính trên đúng N bit nhận ở mọi N = 5–8. | 2.10.1.3 |
| REQ-RX-04 | Sườn xuống, kiểm tra lại ở tick 8; start hợp lệ thì `rx_busy = 1`. | 2.10.2.1 |
| REQ-RX-05 | **[Gợi ý]** Xung thấp ngắn hơn 0,4 bit không tạo khung: `rx_busy = 0`, `rx_done = 0`. | 2.10.2.2 |
| REQ-RX-06 | `rx_done = 1` trong ≤ 1 bit sau điểm lấy mẫu stop bit cuối; đồng thời `rx_busy = 0`. | 2.10.3.1 |
| REQ-RX-07 | `rx_done` = 1 khi RXDATA có ký tự chưa đọc; `rx_busy` = 1 trong lúc nhận khung. | 2.4.2.x |
| REQ-RX-08 | Đọc RXDATA xoá `rx_done`, `parity_err`, `frame_err`, `overrun`. | 2.10.3.2 |
| REQ-RX-09 | **[Nhóm 11/11]** Đọc RXDATA trong chu kỳ byte mới vừa nhận xong: `prdata` trả byte cũ; tại sườn kết thúc pha truy cập, RXDATA nhận byte mới, `rx_done` giữ 1, `overrun = 0`, cờ lỗi theo byte mới. Không mất byte nào. | 2.10.3.3 |
| REQ-RX-10 | **[Nhóm 11/11]** Đọc RXDATA khi `rx_done = 0`: `pslverr = 0`, `prdata` trả byte nhận gần nhất (0 sau reset), cờ giữ 0, khung đang nhận không bị ảnh hưởng. | 2.10.3.4 |
| REQ-RX-11 | Bên phát lệch ±2,0 %, mọi 24 dạng: nhận đúng, không cờ lỗi. | 2.10.4.1 |
| REQ-RX-12 | F4 cộng điểm: nhận đúng khi bên phát lệch ±3,0 %. | 2.10.4.2 |
| REQ-RX-13 | Bên phát nhanh 2 %, khung nối liền: không bỏ lỡ start kế, mọi byte đúng. | 4.3.1 |
| REQ-RX-14 | `rx_dis = 1`: khung trên `rx` không được nhận (`rx_busy = 0`, `rx_done = 0`). | 2.2.2.2 |

### 9.4 Cờ lỗi

| Cờ | Đặt khi | Hành vi | Spec ID |
|---|---|---|---|
| `parity_err` | Ký tự nhận sai parity | `rx_done = 1`, dữ liệu vẫn đọc được | 3.3.1 |
| `frame_err` | Có stop bit lấy mẫu ra 0 (cả stop 1 và stop 2) | `rx_done = 1` | 3.3.2.x |
| `overrun` | Khung mới nhận xong khi `rx_done = 1` | Khung mới bị bỏ, RXDATA giữ ký tự cũ, `rx_done` giữ 1 | 3.3.3 |

---

## 10. Điều khiển luồng rts_n / cts_n

| Mã | Yêu cầu | Spec ID |
|---|---|---|
| REQ-FC-01 | `rts_n = 0` khi `rx_dis = 0` và `rx_done = 0` (RXDATA trống, cho phép bên kia gửi). | 2.11.1.1 |
| REQ-FC-02 | `rx_done` lên 1 thì `rts_n = 1`; đọc RXDATA xong `rts_n` về 0. | 2.11.1.2 |
| REQ-FC-03 | `rx_dis = 1` thì `rts_n = 1`. | 2.11.1.3 |
| REQ-FC-04 | `cts_n` chặn việc bắt đầu khung TX (xem REQ-TX-08, REQ-TX-09). | 2.9.3.1, 4.2.1 |
| REQ-FC-05 | Trong reset (cứng hoặc mềm) `rts_n = 1`. | 1.2.2, 2.7.1.4 |

HTML 1.1 không có bit bật/tắt điều khiển luồng: `cts_n` và `rts_n` luôn hoạt động. Khi không dùng, nối `cts_n` xuống 0 ở mức board/wrapper.

---

## 11. Ngắt

`irq` là **ngắt mức, tích cực cao**, một chân cho cả ba nguồn:

```
irq = (tx_done_ie & tx_done)
    | (rx_done_ie & rx_done)
    | (err_ie & (parity_err | frame_err | overrun))
```

| Mã | Yêu cầu | Spec ID |
|---|---|---|
| REQ-IRQ-01 | `irq` đúng công thức trên; mỗi bit IER chỉ mở đúng nguồn của nó. | 2.5.1, 2.12.1.1 |
| REQ-IRQ-02 | `irq` giữ mức cao tới khi điều kiện hết, không phải xung. | 2.12.1.2 |
| REQ-IRQ-03 | `irq` phản ánh thay đổi trong ≤ 2 chu kỳ pclk. **[Gợi ý]** lấy `irq` từ flip-flop. | 2.12.1.3 |
| REQ-IRQ-04 | `rx_done_ie = 1`, đọc RXDATA → `irq` về 0. | 2.12.2.1 |
| REQ-IRQ-05 | `tx_done_ie = 1`, ghi `start_tx` → `tx_done = 0` nên `irq` về 0. | 2.12.2.2 |
| REQ-IRQ-06 | Bật `tx_done_ie` khi `tx_done = 1` → `irq` lên 1 ngay. | 2.12.3.1 |
| REQ-IRQ-07 | Bật `tx_done_ie` sau `start_tx` (khi `tx_done = 0`) → `irq` giữ 0, lên 1 khi hết khung. | 2.12.3.2 |

Lưu ý phần mềm: sau reset `tx_done = 1`, nên bật `tx_done_ie` lúc rảnh sẽ cho ngắt ngay.

---

## 12. Reset

### 12.1 Reset cứng `presetn`

- Tích cực mức thấp, không đồng bộ. Đưa mọi thanh ghi, máy trạng thái và giao diện APB về giá trị reset (§4).
- Output theo REQ-IO-02, REQ-IO-03.

### 12.2 Reset mềm `CTRL.soft_rst`

| Mã | Yêu cầu | Spec ID |
|---|---|---|
| REQ-SRST-01 | Ghi 1 vào CTRL[8] (`pstrb[1] = 1`): đồng bộ, tích cực cao. | 2.3.2.1 |
| REQ-SRST-02 | **[Nhóm 11/11, mở rộng HTML]** Reset toàn bộ phần UART, trừ giao diện APB: TXDATA = 0, RXDATA = 0, CFG = 0, CTRL = 0, BAUD = 0x900D, IER = 0, STAT = 0x1, mọi máy trạng thái về IDLE. Giao dịch ghi CTRL hoàn tất bình thường, `pready = 1`. | 2.7.1.1 |
| REQ-SRST-03 | Huỷ khung đang phát: `tx = 1`, `tx_done = 1`, phần còn lại không xuất hiện. | 2.7.1.2 |
| REQ-SRST-04 | Huỷ khung đang nhận: `rx_busy = 0`, không có `rx_done` từ khung đó. | 2.7.1.3 |
| REQ-SRST-05 | Khi reset mềm tác động: `rts_n = 1`. | 2.7.1.4 |
| REQ-SRST-06 | Hoàn tất trong 2 chu kỳ pclk; từ chu kỳ thứ 3 lệnh APB được nhận và cho kết quả đúng. | 2.7.2.1 |
| REQ-SRST-07 | Bit tự về 0, đọc trả 0; UART không bị giữ trong reset, không cần ghi lại 0. | 2.7.2.2 |
| REQ-SRST-08 | Không bao giờ báo `pslverr`. | 2.7.3 |
| REQ-SRST-09 | Ghi đồng thời `soft_rst = 1` và `start_tx = 1` (ví dụ CTRL = 0x101, `pstrb = 0011`): `soft_rst` ưu tiên, lệnh phát bị bỏ, `pslverr = 0`, kể cả khi đang phát. | 4.1.1.x |

---

## 13. Wrapper Tiny Tapeout và spi2apb

### 13.1 Mục tiêu

Giao tiếp APB của `apb_uart` cần 85 chân (51 vào, 34 ra), trong khi một tile Tiny Tapeout chỉ có 24 chân người dùng. `spi2apb` chuyển mỗi giao dịch APB thành một khung SPI 4 chân mà RP2040 phát bằng khối SPI phần cứng. Lõi `apb_uart` giữ nguyên giao tiếp APB; testbench chấm điểm nối thẳng vào APB, `spi2apb` chỉ nằm trong wrapper.

### 13.2 Chân wrapper `tt_um_hust_apb_uart`

| Chân | Tín hiệu | Chân | Tín hiệu |
|---|---|---|---|
| `ui_in[0]` | `rx` | `uo_out[0]` | `tx` |
| `ui_in[1]` | `cts_n` | `uo_out[1]` | `rts_n` |
| `ui_in[2]` | `spi_cs_n` | `uo_out[2]` | `spi_miso` |
| `ui_in[3]` | `spi_sclk` | `uo_out[3]` | `tx_done` |
| `ui_in[4]` | `spi_mosi` | `uo_out[4]` | `rx_done` |
| `ui_in[5]` | `scan_en` (dự phòng) | `uo_out[5]` | `parity_err` |
| `ui_in[6]` | `scan_in` (dự phòng) | `uo_out[6]` | `irq` |
| `ui_in[7]` | `test_mode` (dự phòng) | `uo_out[7]` | `scan_out` (dự phòng) |

| Mã | Yêu cầu | Spec ID |
|---|---|---|
| REQ-TT-01 | Nối chân vào/ra đúng bảng trên. | 1.3.1, 1.3.2 |
| REQ-TT-02 | `clk` của wrapper nối `pclk`, `rst_n` nối `presetn`. | 1.3.1 |
| REQ-TT-03 | `uio` không dùng: `uio_oe = 0`. Đội không làm DFT thì nối chân dự phòng về hằng. | 1.3.2.2 |

RP2040 trên board demo: cấp `clk` (125 MHz / 5 = 25 MHz), điều khiển reset, là SPI master truy cập thanh ghi qua `spi2apb`, nhận `irq` trên một GPIO.

### 13.3 Khung SPI

Mode 0 (CPOL = 0, CPHA = 0), MSB trước, khung cố định **56 bit (7 byte)** cho cả đọc và ghi trong một lần `spi_cs_n = 0`. Lấy mẫu MOSI ở sườn lên SCLK, đổi MISO ở sườn xuống. `f_SCLK ≤ f_pclk/10` (2,5 MHz ở 25 MHz); một khung dài 22,4 µs.

| Byte | Bit | MOSI | MISO |
|---|---|---|---|
| B0 cmd | 0–7 | [7] rw (1 ghi), [6:4] = 000, [3:0] = `paddr[5:2]` | 0x00 |
| B1 turnaround | 8–15 | 0x00 | 0x00 |
| B2–B5 dữ liệu | 16–47 | ghi: `pwdata[31:0]` (MSB trước); đọc: 0x00 | đọc: `prdata[31:0]`; ghi: 0x00 |
| B6 trạng thái | 48–55 | 0x00 | [1] `cmd_err`, [0] `pslverr` |

Chỉ số thanh ghi trong cmd[3:0]: 0 TXDATA, 1 RXDATA, 2 CFG, 3 CTRL, 4 STAT, 5 BAUD, 6 IER. `paddr = {6'b0, cmd[3:0], 2'b00}`.

| Mã | Yêu cầu | Spec ID |
|---|---|---|
| REQ-SPI-01 | Định dạng khung đúng bảng trên. | 2.13.1.1 |
| REQ-SPI-02 | MOSI lấy mẫu ở sườn lên, MISO đổi ở sườn xuống. | 2.13.1.2 |
| REQ-SPI-03 | Hoạt động đúng ở `f_SCLK = f_pclk/10`. | 2.13.1.3 |
| REQ-SPI-04 | `spi_cs_n = 1` → `MISO = 0`. MISO ở B0, B1 luôn 0x00. | 2.13.1.4, 2.13.1.5 |
| REQ-SPI-05 | Lệnh ghi: giao dịch APB sau sườn lên SCLK thứ 48 với `pwdata` từ B2–B5; `pslverr` ra ở bit 55 (B6[0]), còn 7 chu kỳ SCLK dự phòng. | 2.13.2.1 |
| REQ-SPI-06 | Lệnh đọc: giao dịch APB ngay sau sườn lên SCLK thứ 8; `prdata` chốt trong 8 chu kỳ SCLK của B1, trước bit 16; ra MISO ở B2–B5; B6[0] = `pslverr`. | 2.13.2.2 |
| REQ-SPI-07 | cmd[6:4] ≠ 000: không sinh giao dịch APB, B6[1] = `cmd_err` = 1. | 2.13.3.1 |
| REQ-SPI-08 | cmd[3:0] > 6: `apb_uart` trả `pslverr = 1` (E1), B6[0] = 1. | 2.13.3.2 |
| REQ-SPI-09 | `spi_cs_n` lên 1 trước bit 56 huỷ khung; lệnh ghi chưa tới bit 48 không có tác dụng. | 2.13.4.1 |
| REQ-SPI-10 | Lệnh đọc đã chạy ở bit 8 vẫn có tác dụng phụ dù khung bị huỷ (đọc RXDATA xoá cờ). | 2.13.4.2 |
| REQ-SPI-11 | `spi_cs_n`, `spi_sclk`, `spi_mosi` qua 2 FF trong miền pclk; SCLK không được dùng làm clock. | — |

Giới hạn `f_pclk/10`: mỗi nửa chu kỳ SCLK dài 5 chu kỳ pclk, đủ cho 2 FF đồng bộ và 1 chu kỳ phát hiện sườn.

---

## 14. Trình tự sử dụng điển hình

### 14.1 Phát một ký tự 0x41, 8N1, 115 200 baud (qua SPI)

| Bước | Thao tác | MOSI | MISO | Ghi chú |
|---|---|---|---|---|
| 1 | ghi CFG = 0x03 | 82 00 00 00 00 03 00 | 00 00 00 00 00 00 00 | `irq = 0` (IER = 0) |
| 2 | ghi BAUD = 0x900D | 85 00 00 00 90 0D 00 | 00 … 00 | |
| 3–4 | đọc STAT | 04 00 00 00 00 00 00 | 00 00 00 00 00 01 00 | `tx_done = 1`: được ghi TXDATA |
| 5 | ghi TXDATA = 0x41 | 80 00 00 00 00 41 00 | 00 … 00 | |
| 6–7 | ghi CTRL.start_tx | 83 00 00 00 00 01 00 | 00 … 00 | `tx_done → 0` |
| 8 | ghi IER = 0x01 | 86 00 00 00 00 01 00 | 00 … 00 | Bật khi `tx_done = 0` nên `irq` giữ 0 |
| 9–12 | (phần cứng) | — | — | `cts_n = 0` → phát khung 86,8 µs → `tx_done = 1` → `irq = 1` |
| 13–14 | đọc STAT | 04 00 00 00 00 00 00 | 00 00 00 00 00 01 00 | Xác nhận nguồn ngắt là `tx_done` |

Ký tự kế: lặp bước 5, 6 → `tx_done = 0` nên `irq = 0`. (Spec ID 2.14.1.1)

### 14.2 Nhận một ký tự 0x5A

| Bước | Thao tác | MOSI | MISO | Ghi chú |
|---|---|---|---|---|
| 1 | ghi CFG = 0x03 | 82 00 00 00 00 03 00 | 00 … 00 | `rx_dis = 0` |
| 2 | ghi BAUD = 0x900D | 85 00 00 00 90 0D 00 | 00 … 00 | |
| 3 | ghi IER = 0x02 | 86 00 00 00 00 02 00 | 00 … 00 | Chỉ `rx_done_ie`; `tx_done = 1` không gây ngắt |
| 4–8 | (phần cứng) | — | — | `rts_n = 0` → nhận khung → `rx_done = 1`, `rts_n = 1` → `irq = 1` |
| 9–10 | đọc STAT | 04 00 00 00 00 00 00 | 00 00 00 00 00 03 00 | STAT = 0x3, không cờ lỗi |
| 11–12 | đọc RXDATA | 01 00 00 00 00 00 00 | 00 00 00 00 00 5A 00 | Xoá `rx_done`; APB chạy sau bit 8 |
| 13–14 | (phần cứng) | — | — | `irq = 0`; `rts_n = 0` |

(Spec ID 2.14.1.2)

---

## 15. Lịch cổng duyệt và tiêu chí hoàn tất

| Hạn | Cổng | Ngưỡng đạt |
|---|---|---|
| T3 10/11/2026 | G1 Đặc tả | Bảng thanh ghi, bảng BAUD và sai số ở 25 MHz, thiết kế bộ tích luỹ phân số, sơ đồ khối có tên tín hiệu, kế hoạch kiểm chứng ánh xạ từng mục sang test |
| T7 14/11/2026 | G2 RTL + lint | 0 cảnh báo Verilator `-Wall`; 0 latch; một net clock; ràng buộc §3.2 |
| T4 18/11/2026 | G3 DV, G4 netlist | 20 test công khai đạt trên RTL và netlist Yosys; độ phủ statement, branch ≥ 90 % (Questa) |
| T7 21/11/2026 | G6 STA, LEC (G5 DFT cộng điểm) | SDC 40 ns; WS setup ≥ 0 ở corner ss, hold ≥ 0 mọi corner; eqy tương đương |
| T3 24/11/2026 | G7 Layout | LibreLane hết flow, tile 1×1, WS sau route ≥ 0 |
| T5 26/11/2026 23:59 | G8 GLS, G9 sign-off | GLS có SDF ở tt, ss, ff; DRC = 0, LVS khớp, antenna = 0; GitHub Actions TT xanh; báo cáo đủ 10 mục phần E |
| T7 28/11/2026 | Bảo vệ | Ban chấm chạy 108 test ẩn và LibreLane cấu hình chung |

Tiêu chí hoàn tất kiểm chứng: mọi test Priority 1 PASS; không SVA fail; độ phủ statement, branch ≥ 90 %.

---

## 16. Điểm không nhất quán trong HTML và câu hỏi mở

### 16.1 Không nhất quán trong HTML (đã chọn cách hiểu)

| # | Chỗ lệch | Chọn theo |
|---|---|---|
| 1 | Khối `uart_rx` ở §3 ghi "kiểm tra stop thứ nhất", còn §7 yêu cầu kiểm tra **mọi** stop bit. | §7 (đặc tả 6.2). |
| 2 | E3 bắt lỗi ghi CTRL có `start_tx = 1` khi bận, nhưng §12 nói `soft_rst` ưu tiên và không bao giờ báo `pslverr`. | Ghi kèm `soft_rst = 1` thì không lỗi (REQ-SRST-09). |
| 3 | §12 chỉ liệt kê CFG, BAUD, IER khi nói "mọi thanh ghi về reset". | Nhóm chốt reset cả TXDATA, RXDATA (REQ-SRST-02). |

### 16.2 Câu hỏi mở cần hỏi thầy

| # | Câu hỏi |
|---|---|
| Q1 | Tần số `pclk`: giữ 25 MHz theo HTML hay dùng 50 MHz? Pad Tiny Tapeout cho tối đa khoảng 66 MHz; 50 MHz cần đóng timing ở 20 ns và toàn bộ bảng BAUD, giá trị reset BAUD (0x201B) phải đổi. |
| Q2 | `tx_dis = 1` rồi ghi `start_tx`: `tx_done` giữ 1 hay xuống 0? HTML chỉ nói "tắt bộ phát". |
| Q3 | Ghi `tx_dis = 1` / `rx_dis = 1` khi đang bận: HTML chặn bằng E4 (ghi CFG lane 0 khi bận bị lỗi), nên chỉ đổi được khi rảnh. Có cần cách tắt ngay giữa khung không? |
| Q4 | REQ-RX-09, REQ-RX-10 là quyết định của nhóm, cần xác nhận khớp với testbench ẩn. |

---

## 17. Phụ lục: bảng tra nhanh

### 17.1 Giá trị CFG thường dùng

| Khung | CFG | Bit/khung |
|---|---|---|
| 5N1 (reset) | 0x00 | 7 |
| 8N1 | 0x03 | 10 |
| 8E1 | 0x1B | 11 |
| 8O1 | 0x0B | 11 |
| 8N2 | 0x07 | 11 |
| 8E2 | 0x1F | 12 |
| 7E1 | 0x1A | 10 |

### 17.2 Thời gian quan trọng

| Sự kiện | Giới hạn |
|---|---|
| `start_tx` → `tx_done = 0` | Chu kỳ sau |
| Hết stop bit cuối → `tx_done = 1` | ≤ 2 chu kỳ pclk |
| Điểm lấy mẫu stop cuối → `rx_done = 1` | ≤ 1 bit |
| Thay đổi nguồn → `irq` | ≤ 2 chu kỳ pclk |
| Reset mềm hoàn tất | 2 chu kỳ pclk, APB nhận lệnh từ chu kỳ 3 |
| Đồng bộ `rx`, `cts_n` | ≥ 2 chu kỳ pclk |
| Khung SPI ở 2,5 MHz | 22,4 µs |
| Ký tự 8N1 ở 115 200 baud | 86,8 µs |

### 17.3 Ma trận pslverr theo thanh ghi

| Thanh ghi | Đọc | Ghi khi rảnh | Ghi khi `tx_done = 0` | Ghi khi `rx_busy = 1`, `tx_done = 1` |
|---|---|---|---|---|
| TXDATA | 0 | 0 | **E3** (`pstrb ≠ 0`) | 0 |
| RXDATA | 0 | **E2** | **E2** | **E2** |
| CFG | 0 | 0 | **E4** nếu `pstrb[0]` | **E4** nếu `pstrb[0]` |
| CTRL | 0 | 0 | **E3** nếu `pstrb[0]` & `pwdata[0]` & không kèm `soft_rst` | 0 |
| STAT | 0 | **E2** | **E2** | **E2** |
| BAUD | 0 | **E5** nếu `div_int` mới = 0 | **E4** nếu `pstrb[1:0] ≠ 0` | **E4** nếu `pstrb[1:0] ≠ 0` |
| IER | 0 | 0 | 0 | 0 |
| Ngoài bảng / lệch | **E1**, trả 0 | **E1** | **E1** | **E1** |
