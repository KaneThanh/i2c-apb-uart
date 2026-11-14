# Testplan APB_UART

Testplan cho `apb_uart` (lõi APB) và wrapper `tt_um_hust_apb_uart` (spi2apb). Chỉ mô tả kịch bản kiểm tra, **không có code testbench**.

## 0. Quy ước

**Nguồn.** `HD` = `HD-APB-UART-tuong-tac.html` (Đặc tả 1.1). `SPEC` = `APB_UART_Specification.md` (mã `REQ-xx-nn`). `XLSX` = `UART_APB_VerificationSpecification (1).xlsx` (Spec ID dạng `2.10.3.3`, Test ID dạng `T-x.x.x`). `TBG` = `TB_GUIDE.md` (cổng module, phân cấp, trạng thái RTL ngày 2026-11-13).

**Phần của tài liệu.**

| Phần | ID | Nội dung | Ưu tiên chấm |
|---|---|---|---|
| 1 | `H-NN` | Mỗi ví dụ trong HD §2, §4–§12 thành một test bắt buộc, giữ đúng giá trị của HD | PASS bắt buộc |
| 2 | `T-x.x.x` | 51 test của XLSX, viết lại với vector cụ thể. Test trùng `H-NN` chỉ ghi `covered by` | Theo cột Priority của XLSX |
| 3 | `C-NN` | Corner case bổ sung | Bổ sung |
| 4 | — | Ma trận trace Spec ID ↔ REQ ↔ Test | — |
| 5 | `A-NN`, `SB-NN`, `CG-NN` | Yêu cầu môi trường kiểm chứng: thành phần testbench, SVA, scoreboard, coverage, tiêu chí kết thúc | Bắt buộc khi viết testbench |

**Ký hiệu stimulus / kết quả.**
- `W <addr> <pstrb> <pwdata>`: ghi APB (1 chu kỳ setup + 1 chu kỳ access). `R <addr>`: đọc APB. Địa chỉ viết hex 12 bit.
- `→ pslverr=x prdata=y`: kết quả đo ở chu kỳ access.
- Pin: `rx`, `cts_n`, `tx`, `rts_n`, `irq`. Thời gian đo bằng chu kỳ `pclk` (25 MHz, 40 ns).
- Sau reset: `CFG=0x00` (5N1), `BAUD=0x900D` (217 chu kỳ/bit). Mọi test dùng cts_n=0 và peer lý tưởng trừ khi ghi khác.
- Muốn đổi `CFG`/`BAUD` phải chờ `tx_done=1` và `rx_busy=0` (nếu không gặp E4).
- `ASSUMPTION: …` đánh dấu test dựa trên quyết định nhóm 11/11 hoặc câu hỏi mở Q2–Q4 của SPEC §16.2.

**Mỗi test gồm:** dòng `Source | Trace | Spec ID | Priority | Check`, `Precondition`, bảng `| Step | Input | Expected output |`, `Pass criteria`.

**Thanh ghi.** TXDATA 0x00, RXDATA 0x04, CFG 0x08, CTRL 0x0C, STAT 0x10, BAUD 0x14, IER 0x18.

---

# Phần 1. Test bắt buộc từ file HTML (`H-NN`)

### H-01 Cổng và giá trị output sau reset
Source: HD §2 | Trace: REQ-IO-01, REQ-IO-02 | Spec ID: 1.2.1, 1.2.2 | Priority: 1 | Check: Elaboration, SVA
Precondition: Không cần. Sau đó áp `presetn=0` rồi nhả.

| Step | Input | Expected output |
|---|---|---|
| 1 | Elaborate testbench nối theo tên với module `apb_uart` | Đủ 16 cổng: `pclk`1 `presetn`1 `psel`1 `penable`1 `pwrite`1 `paddr`12 `pstrb`4 `pwdata`32 (vào); `pready`1 `pslverr`1 `prdata`32 (ra); `rx`1 `cts_n`1 (vào); `tx`1 `rts_n`1 `irq`1 (ra) |
| 2 | `presetn=0`, psel=0 | `tx=1 rts_n=1 irq=0 pslverr=0 pready=1` |
| 3 | Nhả `presetn=1`, chờ 2 chu kỳ | `tx=1 irq=0 pslverr=0 pready=1`; `rts_n=0` (rx_dis=0, rx_done=0) |

Pass criteria: tên, độ rộng, hướng cổng đúng bảng; 5 giá trị reset đúng ở bước 2.

### H-20 Chân của wrapper tt_um_hust_apb_uart (phần tĩnh)
Source: HD §2; TBG §3 | Trace: REQ-TT-01, REQ-TT-02, REQ-TT-03 | Spec ID: 1.3.1, 1.3.2, 1.3.2.2 | Priority: 1 | Check: Scoreboard, SVA
Precondition: Wrapper, `clk=25 MHz`. Theo TBG §3: `ui_in[7:5]` không dùng trong RTL, `uo_out[7]` hằng 0, `uio_out = 0`, `uio_oe = 0`. Phần động (SPI, rx, cts_n): T-1.3.1.

| Step | Input | Expected output |
|---|---|---|
| 1 | `rst_n=0` | `uo_out[0]=1` (tx), `uo_out[1]=1` (rts_n), `uo_out[3]=1` (tx_done), `uo_out[6]=0` (irq); `uo_out[4]=0`, `uo_out[5]=0` |
| 2 | Kiểm kết nối | `ui_in[0..4]` = rx, cts_n, spi_cs_n, spi_sclk, spi_mosi; `uo_out[0..6]` = tx, rts_n, spi_miso, tx_done, rx_done, parity_err, irq; `clk` → `pclk`, `rst_n` → `presetn` |
| 3 | Toàn bộ mô phỏng | `uio_oe=0x00`; `uio_out=0x00`; `uo_out[7]=0`; đảo `ui_in[5..7]` không đổi hành vi |

Pass criteria: mọi chân đúng bảng HD §2.

### H-02 Giá trị reset của 7 thanh ghi
Source: HD §4 | Trace: REQ-REG-01, REQ-REG-02 | Spec ID: 2.1.1.1, 2.1.1.2, 1.1.1.4 | Priority: 1 | Check: Scoreboard
Precondition: Ngay sau `presetn`.

| Step | Input | Expected output |
|---|---|---|
| 1 | `R 000` | `prdata=0x00000000 pslverr=0` (TXDATA) |
| 2 | `R 004` | `prdata=0x00000000 pslverr=0` (RXDATA) |
| 3 | `R 008` | `prdata=0x00000000` (CFG) |
| 4 | `R 00C` | `prdata=0x00000000` (CTRL, luôn đọc 0) |
| 5 | `R 010` | `prdata=0x00000001` (STAT: tx_done=1) |
| 6 | `R 014` | `prdata=0x0000900D` (BAUD) |
| 7 | `R 018` | `prdata=0x00000000` (IER) |

Pass criteria: 7 giá trị đúng như trên, `pslverr=0` ở cả 7 lần đọc.

### H-03 Bảng BAUD ở 25 MHz (10 tốc độ)
Source: HD §5 | Trace: REQ-BAUD-01..05 | Spec ID: 2.8.1.2, 2.8.2.1, 2.8.2.2, 4.4.1 | Priority: 1 (7 tốc độ đầu), 2 (3 tốc độ cuối, cộng điểm) | Check: Scoreboard
Precondition: `tx_done=1`, `rx_busy=0`, cts_n=0, CFG=0x03 (8N1), TXDATA=0x55.

Lặp lại cho từng dòng: `W 014 0011 <BAUD>`, `W 00C 0001 0x1`, đo độ dài mọi bit trên `tx` (từ cạnh xuống start bit); sau đó peer gửi 0x55 vào `rx` với cùng bit time, host đọc RXDATA.

| Baud | `W 014` pwdata | div_int | div_frac | Chu kỳ pclk / bit | Sai số | Mức |
|---|---|---|---|---|---|---|
| 2 400 | 0x0000128B | 651 | 1 | 10417 | −0,003 % | Bắt buộc |
| 4 800 | 0x00008145 | 325 | 8 | 5208 | +0,01 % | Bắt buộc |
| 9 600 | 0x0000C0A2 | 162 | 12 | 2604 | +0,01 % | Bắt buộc |
| 19 200 | 0x00006051 | 81 | 6 | 1302 | +0,01 % | Bắt buộc |
| 38 400 | 0x0000B028 | 40 | 11 | 651 | +0,01 % | Bắt buộc |
| 57 600 | 0x0000201B | 27 | 2 | 434 | +0,01 % | Bắt buộc |
| 115 200 | 0x0000900D | 13 | 9 | 217 | +0,01 % | Bắt buộc (reset) |
| 230 400 | 0x0000D006 | 6 | 13 | 109 | −0,45 % | Cộng điểm |
| 460 800 | 0x00006003 | 3 | 6 | 54 | +0,47 % | Cộng điểm |
| 921 600 | 0x0000B001 | 1 | 11 | 27 | +0,47 % | Cộng điểm |

| Step | Input | Expected output |
|---|---|---|
| 1 | `W 014 0011 <BAUD>` | `pslverr=0`; `R 014 → prdata=<BAUD>` |
| 2 | `W 000 0001 0x55`, `W 00C 0001 0x1` | `tx` có 10 bit `0 1 0 1 0 1 0 1 0 1`, mỗi bit đúng số chu kỳ ở cột "Chu kỳ / bit" |
| 3 | Peer gửi 0x55 (8N1) vào `rx` ở cùng baud | `R 004 → prdata=0x00000055`; `R 010` trước đó có `rx_done=1`, các cờ lỗi = 0 |

Pass criteria: 10 tốc độ đều đúng độ dài bit (không lệch dù 1 chu kỳ), 0 lỗi nhận. Riêng 921 600 baud: bit đúng 27 chu kỳ dù tick cách nhau 1 hoặc 2 chu kỳ (REQ-BAUD-05).

### H-04 Ví dụ D = 14,125: bit dài 226 chu kỳ
Source: HD §5 | Trace: REQ-BAUD-01 | Spec ID: 2.8.1.1 | Priority: 1 | Check: Scoreboard
Precondition: cts_n=0, CFG=0x03, TXDATA=0x55.

| Step | Input | Expected output |
|---|---|---|
| 1 | `W 014 0011 0x0000200E` (div_int=14, div_frac=2) | `pslverr=0`; `R 014 → 0x0000200E` |
| 2 | `W 00C 0001 0x1` | Mọi bit trên `tx` dài đúng `16·14 + 2 = 226` chu kỳ (9,04 µs, 110 619 baud) |
| 3 | Đo khoảng cách giữa 32 tick liên tiếp của một bit | Trong 16 tick của một bit: 14 tick cách 14 chu kỳ và 2 tick cách 15 chu kỳ, `acc` về giá trị đầu bit |

Pass criteria: 10 bit × 226 chu kỳ, không bit nào lệch. Frame 8N1 dài 2260 chu kỳ.

### H-05 24 dạng khung UART (TX và RX)
Source: HD §6 | Trace: REQ-FRM-01..05, REQ-RX-01..03 | Spec ID: 2.2.1.1, 2.2.1.2, 2.2.1.3, 2.2.1.4, 2.9.1.1, 2.9.1.3, 2.9.1.4, 2.9.1.5, 2.10.1.1, 2.10.1.2, 2.10.1.3 | Priority: 1 | Check: Scoreboard, COV
Precondition: cts_n=0, BAUD=0x900D, mặc định data = `0xA5` (ví dụ của HD §6). CFG giá trị theo bảng.

Bảng dưới là chuỗi bit mong đợi trên `tx` cho data 0xA5 (LSB trước, chỉ N bit thấp được phát): `start | data | [parity] | stop`. `n` = số bit start→stop cuối.

| Khung | CFG | n | N bit phát | Chuỗi trên `tx` |
|---|---|---|---|---|
| 5N1 | 0x00 | 7 | 0x05 | `0 10100 1` |
| 5N2 | 0x04 | 8 | 0x05 | `0 10100 11` |
| 5O1 | 0x08 | 8 | 0x05 | `0 10100 1 1` |
| 5O2 | 0x0C | 9 | 0x05 | `0 10100 1 11` |
| 5E1 | 0x18 | 8 | 0x05 | `0 10100 0 1` |
| 5E2 | 0x1C | 9 | 0x05 | `0 10100 0 11` |
| 6N1 | 0x01 | 8 | 0x25 | `0 101001 1` |
| 6N2 | 0x05 | 9 | 0x25 | `0 101001 11` |
| 6O1 | 0x09 | 9 | 0x25 | `0 101001 0 1` |
| 6O2 | 0x0D | 10 | 0x25 | `0 101001 0 11` |
| 6E1 | 0x19 | 9 | 0x25 | `0 101001 1 1` |
| 6E2 | 0x1D | 10 | 0x25 | `0 101001 1 11` |
| 7N1 | 0x02 | 9 | 0x25 | `0 1010010 1` |
| 7N2 | 0x06 | 10 | 0x25 | `0 1010010 11` |
| 7O1 | 0x0A | 10 | 0x25 | `0 1010010 0 1` |
| 7O2 | 0x0E | 11 | 0x25 | `0 1010010 0 11` |
| 7E1 | 0x1A | 10 | 0x25 | `0 1010010 1 1` |
| 7E2 | 0x1E | 11 | 0x25 | `0 1010010 1 11` |
| 8N1 | 0x03 | 10 | 0xA5 | `0 10100101 1` |
| 8N2 | 0x07 | 11 | 0xA5 | `0 10100101 11` |
| 8O1 | 0x0B | 11 | 0xA5 | `0 10100101 1 1` |
| 8O2 | 0x0F | 12 | 0xA5 | `0 10100101 1 11` |
| 8E1 | 0x1B | 11 | 0xA5 | `0 10100101 0 1` |
| 8E2 | 0x1F | 12 | 0xA5 | `0 10100101 0 11` |

| Step | Input | Expected output |
|---|---|---|
| 1 | Với mỗi dòng: `W 008 0001 <CFG>`, `R 008` | `pslverr=0`, `prdata=<CFG>` |
| 2 | `W 000 0001 0xA5`, `W 00C 0001 0x1` | `tx` đúng chuỗi trong bảng, mỗi bit 217 chu kỳ; `R 000 → 0x000000A5` (TXDATA giữ đủ 8 bit) |
| 3 | Chờ `tx_done=1`, `R 010` | `STAT=0x00000001` |
| 4 | Peer gửi đúng chuỗi trong bảng vào `rx` (lặp với các byte có cả số bit 1 chẵn và lẻ) | `R 010` có `rx_done=1`, `parity_err=0`, `frame_err=0`, `overrun=0`; `R 004 → prdata=<N bit thấp của data>`, `rx_data[7:N]=0` (ví dụ 5N1: `0x05`) |

Pass criteria: 24/24 dạng đúng cả TX và RX; parity chẵn: tổng số bit 1 của data và parity chẵn, parity lẻ: số lẻ; coverage đạt 4 độ dài × 3 parity × 2 stop.

### H-06 Dung sai bộ thu ±2 %
Source: HD §7 | Trace: REQ-RX-11 | Spec ID: 2.10.4.1 | Priority: 1 | Check: Scoreboard
Precondition: BAUD=0x900D (T = 217 chu kỳ), 24 dạng khung, peer có thể phát bit time thực.

| Step | Input | Expected output |
|---|---|---|
| 1 | Peer nhanh `e=+2 %`: bit time = 217 / 1,02 = **212,75** chu kỳ. Gửi 24 dạng, data 0x00, 0xFF, 0xA5, 0x5A | `rx_done=1`, mọi cờ lỗi = 0, `RXDATA` = N bit thấp của data |
| 2 | Peer chậm `e=−2 %`: bit time = 217 / 0,98 = **221,43** chu kỳ. Gửi lại như bước 1 | Như bước 1 |

Giới hạn lý thuyết `|e| < (0,5 − 1/16)/(n − 0,5)`: n=7: 6,73 %; n=8: 5,83 %; n=9: 5,15 %; n=10: 4,61 %; n=11: 4,17 %; n=12: 3,80 %. ±2 % nằm trong giới hạn của mọi khung.

Pass criteria: 24 dạng × 2 hướng lệch, nhận đúng byte, không cờ lỗi.

### H-07 Quy tắc stop bit và về IDLE sớm
Source: HD §7 | Trace: REQ-RX-06, REQ-RX-13, §9.1 | Spec ID: 3.3.2.1, 3.3.2.2, 2.10.3.1, 4.3.1 | Priority: 1 | Check: Scoreboard
Precondition: BAUD=0x900D, rx_dis=0; giữa các khung `rx=1` ít nhất 1 bit time (trừ bước 4).

| Step | Input | Expected output |
|---|---|---|
| 1 | CFG=0x07 (8N2). Peer gửi 0x41 với stop1=1, **stop2=0** | `rx_done=1`, `frame_err=1`, `RXDATA=0x41` (khung thiếu stop thứ hai vẫn bị phát hiện) |
| 2 | `R 004`; peer gửi 0x41 với **stop1=0**, stop2=1 | `frame_err=1` |
| 3 | `R 004`; peer gửi 0x41 với stop1=1, stop2=1 | `frame_err=0`, `rx_done=1` |
| 4 | CFG=0x03 (8N1). Peer nhanh +2 %, gửi 3 khung nối liền (stop bit đúng 1 bit time, start kế ngay sau). Cạnh xuống của khung kế đến sau `10 × 212,75 = 2127,5` chu kỳ kể từ cạnh xuống khung trước. Host đọc RXDATA ngay sau mỗi `rx_done` | Bộ thu đã về IDLE sau mẫu stop cuối (≈ 9,5 bit = 2061,5 chu kỳ), nên thấy cả 3 cạnh xuống: nhận đủ 3 byte đúng, `overrun=0`, `frame_err=0` |

Pass criteria: mọi stop bit đều được kiểm; stop bit thứ nhất của khung 2 stop vẫn đếm đủ 16 tick; không bỏ lỡ start của khung liền kề.

### H-08 Ba giao dịch APB của HD §8
Source: HD §8 | Trace: REQ-APB-01..04 | Spec ID: 1.1.1.1, 1.1.1.2, 1.1.1.3, 1.1.1.4, 1.1.3.1 | Priority: 1 | Check: SVA, Scoreboard
Precondition: Sau reset; `BAUD=0x900D`.

| Step | Input | Expected output |
|---|---|---|
| 1 | `W 014 1111 0x0000900D`. Chu kỳ setup: psel=1 penable=0; chu kỳ access: psel=penable=1 | `pready=1` ở cả hai chu kỳ; `pslverr=0`; `R 014 → 0x0000900D` (giá trị ghi trùng giá trị reset nên chưa quan sát được thời điểm đổi: xem bước 4) |
| 2 | `R 010` | `prdata=0x00000001` (tx_done=1), `pslverr=0` |
| 3 | `W 020 1111 0x00000055` (địa chỉ ngoài bảng; pwdata theo giản đồ HD) | `pslverr=1` (E1) chỉ ở chu kỳ access; không thanh ghi nào đổi (đọc lại cả 7: như trước bước 3) |

| 4 | `W 014 1111 0x0000B028` (giá trị khác reset), rồi `R 014` ngay giao dịch kế | Scoreboard nội bộ: thanh ghi BAUD vẫn `0x0000900D` trong chu kỳ setup và đổi thành `0x0000B028` ở sườn kết thúc access; `R 014 → 0x0000B028`. Sau đó khôi phục `0x0000900D` |

Pass criteria: `pready=1` mọi chu kỳ; `pslverr=1` chỉ khi `psel && penable`; kết quả 3 giao dịch đúng như HD; thanh ghi đổi đúng sườn kết thúc access.

### H-09 Bộ kiểm tra lỗi pslverr E1–E5 và truy cập hợp lệ
Source: HD §8 | Trace: REQ-ERR-01..12, REQ-APB-05..07 | Spec ID: 3.1.1.1, 3.1.1.2, 3.1.2, 3.1.3.1, 3.1.3.2, 3.1.4.1, 3.1.4.2, 3.1.5, 3.1.6, 3.2.1.1, 3.2.1.2, 3.2.1.3, 3.2.1.4 | Priority: 1 | Check: Scoreboard
Precondition: Lấy mẫu trạng thái ban đầu: `CFG=0x03`, `BAUD=0x900D`, `TXDATA=0x41`, `IER=0x00`. Mỗi lệnh lỗi: đọc lại toàn bộ 7 thanh ghi, không đổi.

| Step | Input | Expected output |
|---|---|---|
| E1a (rảnh) | `R 01C`, `R 020`, `R FFC` | `pslverr=1`, `prdata=0x00000000` |
| E1b (rảnh) | `W 001/002/003/00D 1111 0xFFFFFFFF` (không căn 4 byte) | `pslverr=1`, không thanh ghi đổi |
| E2 (rảnh) | `W 004 1111 0x55`, `W 010 0000 0x00`, `W 010 1111 0xFF` | `pslverr=1` cả 3 lệnh (bất kể pstrb); RXDATA, STAT không đổi |
| E3a (`tx_done=0` (đang phát 0x41)) | `W 000 0001 0x7F` | `pslverr=1`; `R 000 → 0x41`; khung đang phát không đổi |
| E3b (`tx_done=0`) | `W 00C 0001 0x1` | `pslverr=1`; không có khung phụ |
| E3c (`tx_done=0`) | `W 00C 0001 0x0`; `W 000 0000 0x7F` | `pslverr=0` cả hai (pwdata[0]=0; pstrb=0000) |
| E4a (`tx_done=0` hoặc `rx_busy=1`) | `W 008 0001 0x1B` | `pslverr=1`; `R 008 → 0x03` |
| E4b (`tx_done=0` hoặc `rx_busy=1`) | `W 014 0001 0x000000AB`; `W 014 0010 0x00002000`; `W 014 0011 0x0000201B` | `pslverr=1` cả ba; `R 014 → 0x0000900D` |
| E4c (bận) | `W 008 0010 0x0000FF00`; `W 014 1100 0xFFFF0000` | `pslverr=0` (không chạm lane 0 của CFG, lane 0/1 của BAUD); thanh ghi không đổi |
| E5a (rảnh) | `W 014 0011 0x00000000` | `pslverr=1`; `R 014 → 0x0000900D` |
| E5b (rảnh, BAUD=0x900D) | `W 014 0001 0x00000000` (ghi riêng lane 0: div_int = {0x0, 0x00} = 0) | `pslverr=1`; `R 014 → 0x0000900D` (từng lane: xem T-3.1.5) |
| E5c (rảnh) | `W 014 0011 0x00000001` | `pslverr=0`; `R 014 → 0x00000001` (div_int=1 hợp lệ); khôi phục `0x900D` |
| OK1 (`rx_busy=1`, `tx_done=1`) | `W 000 0001 0x42`, `W 00C 0001 0x1` | `pslverr=0` cả hai; TX và RX chạy đồng thời, cả hai đúng |
| OK2 (mọi trạng thái) | `W 018 0001 0x07`; đọc cả 7 thanh ghi | `pslverr=0` |

Pass criteria: `pslverr=1` đúng 5 trường hợp E1–E5, `0` ở mọi trường hợp hợp lệ; lệnh lỗi không đổi thanh ghi và không kích hoạt hành động.

### H-10 SPI: ghi BAUD (khung 56 bit)
Source: HD §9 | Trace: REQ-SPI-01..05 | Spec ID: 2.13.1.1, 2.13.1.2, 2.13.1.3, 2.13.1.4, 2.13.1.5, 2.13.2.1 | Priority: 1 | Check: Scoreboard, SVA
Precondition: Wrapper, `spi_cs_n=1`, `f_SCLK = f_pclk/10 = 2,5 MHz`. ASSUMPTION: spi2apb lái `pstrb=1111` cho mọi lệnh (SPEC §13.3 không nêu).

| Step | Input | Expected output |
|---|---|---|
| 1 | `spi_cs_n=1`, SCLK đảo | `MISO=0` |
| 2 | `spi_cs_n=0`, MOSI = `85 00 00 00 90 0D 00` (MSB trước, mode 0) | Khung dài 56 bit = 22,4 µs; MOSI lấy mẫu ở sườn lên, MISO đổi ở sườn xuống |
| 3 | Theo dõi giao dịch APB | Xảy ra sau sườn lên SCLK thứ **48**, với `paddr=0x014`, `pwrite=1`, `pwdata=0x0000900D`; trước bit 48 không có giao dịch |
| 4 | MISO | B0 = B1 = B2–B5 = `0x00`; B6 = `0x00` (bit 0 = pslverr=0, bit 1 = cmd_err=0), `pslverr` xuất ở bit 55 |

Pass criteria: MISO toàn `00 00 00 00 00 00 00`; BAUD = 0x900D sau khung.

### H-11 SPI: đọc STAT
Source: HD §9 | Trace: REQ-SPI-06 | Spec ID: 2.13.2.2 | Priority: 1 | Check: Scoreboard
Precondition: Wrapper, sau reset.

| Step | Input | Expected output |
|---|---|---|
| 1 | MOSI = `04 00 00 00 00 00 00` (cmd=0x04 → paddr=0x010) | Giao dịch APB đọc xảy ra **ngay sau sườn lên SCLK thứ 8**; `prdata` được chốt trong 8 chu kỳ SCLK của B1, trước bit 16 |
| 2 | MISO | `00 00 00 00 00 01 00`: B2–B5 = `00 00 00 01` (STAT=0x00000001), B6 = `00` |

Pass criteria: MISO đúng `00 00 00 00 00 01 00`.

### H-12 SPI: lỗi lệnh
Source: HD §9 | Trace: REQ-SPI-07, REQ-SPI-08 | Spec ID: 2.13.3.1, 2.13.3.2 | Priority: 1 | Check: Scoreboard
Precondition: Wrapper, thanh ghi có giá trị đã biết.

| Step | Input | Expected output |
|---|---|---|
| 1 | MOSI B0 = `0x90` (cmd[6:4]=001), `00 00 00 00 12 34 00` | Không sinh giao dịch APB; B6 = `0x02` (cmd_err=1); thanh ghi không đổi |
| 2 | B0 = `0x87` (ghi, cmd[3:0]=7), `00 00 00 00 12 34 00` | Giao dịch APB tới `paddr=0x01C`: `pslverr=1` (E1); B6 = `0x01`; thanh ghi không đổi |
| 3 | B0 = `0x07` (đọc, cmd[3:0]=7) | B2–B5 = `00 00 00 00`, B6 = `0x01` |

Pass criteria: B6 = 0x02 ở bước 1, 0x01 ở bước 2 và 3.

### H-13 SPI: hủy khung giữa chừng
Source: HD §9 | Trace: REQ-SPI-09, REQ-SPI-10 | Spec ID: 2.13.4.1, 2.13.4.2 | Priority: 1 | Check: Scoreboard
Precondition: Wrapper; đạt trạng thái `rx_done=1`, `RXDATA=0x5A`, `parity_err=1` bằng cách nhận 0x5A sai parity với `CFG=0x1B`, rồi `W 008 0001 0x03` khi rảnh (hợp lệ vì `rx_busy=0`, `tx_done=1`).

| Step | Input | Expected output |
|---|---|---|
| 1 | Khung ghi CFG=0x1B (`82 00 00 00 00 1B 00`), kéo `spi_cs_n=1` trước bit 48 (sau bit 40) | Không có giao dịch APB; `CFG` vẫn 0x03 |
| 2 | Khung đọc RXDATA (`01 00 00 00 00 00 00`), kéo `spi_cs_n=1` sau bit 8 (trước bit 56) | Giao dịch đọc đã chạy: `rx_done`, `parity_err`, `frame_err`, `overrun` được xóa (đọc STAT qua khung đầy đủ: `STAT[2]=0`, `STAT[1]=0`) |

Pass criteria: ghi hủy trước bit 48 không có tác dụng; đọc hủy sau bit 8 vẫn xóa cờ.

### H-14 Chuỗi host phát một ký tự 0x41 (8N1, 115 200 baud)
Source: HD §10 | Trace: SPEC §14.1 | Spec ID: 2.14.1.1 | Priority: 1 | Check: Scoreboard
Precondition: Wrapper, vừa reset, cts_n=0.

| Step | Input | Expected output |
|---|---|---|
| 1 | MOSI `82 00 00 00 00 03 00` (ghi CFG=0x03) | MISO `00 00 00 00 00 00 00`; `irq=0` |
| 2 | MOSI `85 00 00 00 90 0D 00` (ghi BAUD=0x900D) | MISO `00 00 00 00 00 00 00` |
| 3–4 | MOSI `04 00 00 00 00 00 00` (đọc STAT) | MISO `00 00 00 00 00 01 00`; `tx_done=1` |
| 5 | MOSI `80 00 00 00 00 41 00` (ghi TXDATA=0x41) | MISO `00 00 00 00 00 00 00` |
| 6–7 | MOSI `83 00 00 00 00 01 00` (ghi CTRL, start_tx) | MISO `00 00 00 00 00 00 00`; `tx_done → 0` ở chu kỳ kế |
| 8 | MOSI `86 00 00 00 00 01 00` (ghi IER=0x01) | MISO `00 00 00 00 00 00 00`; `tx_done=0` nên `irq` giữ 0 |
| 9–12 | MOSI `(phần cứng)` | MISO —; Khung 0x41 8N1 trên `tx` dài 10 bit × 217 = 2170 chu kỳ = **86,8 µs**; `tx_done=1` ≤ 2 chu kỳ sau stop; `irq=1` |
| 13–14 | MOSI `04 00 00 00 00 00 00` (đọc STAT) | MISO `00 00 00 00 00 01 00`; Xác nhận nguồn ngắt là tx_done |

Chuỗi `tx` mong đợi cho 0x41: `0 1 0 0 0 0 0 1 0 1` (start, 0x41 LSB trước = `1 0 0 0 0 0 1 0`, stop).

Pass criteria: MOSI/MISO từng khung khớp bảng; `irq=1` khi hết khung; ký tự kế: ghi TXDATA + start_tx → `tx_done=0`, `irq=0`.

### H-15 Chuỗi host nhận một ký tự 0x5A
Source: HD §10 | Trace: SPEC §14.2 | Spec ID: 2.14.1.2 | Priority: 1 | Check: Scoreboard
Precondition: Wrapper, vừa reset, 8N1, 115 200 baud.

| Step | Input | Expected output |
|---|---|---|
| 1 | MOSI `82 00 00 00 00 03 00` (CFG=0x03) | MISO `00 00 00 00 00 00 00`; `rx_dis=0` |
| 2 | MOSI `85 00 00 00 90 0D 00` (BAUD) | MISO `00 00 00 00 00 00 00` |
| 3 | MOSI `86 00 00 00 00 02 00` (IER=0x02) | MISO `00 00 00 00 00 00 00`; chỉ rx_done_ie; `irq=0` dù tx_done=1 |
| 4–8 | MOSI `(phần cứng)` | MISO —; `rts_n=0`; peer gửi 0x5A (`0 0 1 0 1 1 0 1 0 1` trên `rx`); `rx_done=1`, `rts_n=1`, `irq=1` |
| 9–10 | MOSI `04 00 00 00 00 00 00` (đọc STAT) | MISO `00 00 00 00 00 03 00`; STAT=0x3: tx_done=1, rx_done=1, không cờ lỗi |
| 11–12 | MOSI `01 00 00 00 00 00 00` (đọc RXDATA) | MISO `00 00 00 00 00 5A 00`; Xóa `rx_done`; APB chạy sau bit 8 |
| 13–14 | MOSI `(phần cứng)` | MISO —; `irq=0`, `rts_n=0` |

Chuỗi `rx` cho 0x5A: `0` | `0 1 0 1 1 0 1 0` (0x5A LSB trước) | `1`.

Pass criteria: MISO khớp bảng; `irq` và `rts_n` đổi đúng bước.

### H-16 Giản đồ phát 8N1 0x55 với chờ cts_n
Source: HD §11 | Trace: REQ-TX-04..09 | Spec ID: 2.4.1.1, 2.9.1.1, 2.9.2.1, 2.9.2.2, 2.9.3.1, 4.2.1 | Priority: 1 | Check: Scoreboard
Precondition: CFG=0x03, BAUD=0x900D, TXDATA=0x55, **cts_n=1**.

| Step | Input | Expected output |
|---|---|---|
| 1 | `W 00C 0001 0x1` (start_tx) | Chu kỳ kế: `tx_done=0` (đọc STAT = 0x00); `tx=1` (chờ cts_n) |
| 2 | Giữ cts_n=1 thêm 500 chu kỳ, sau đó hạ `cts_n=0` | `tx=1` suốt thời gian chờ; start bit xuất hiện sau ≥ 2 chu kỳ pclk kể từ khi cts_n hạ (2 FF đồng bộ) |
| 3 | Sau start bit 1000 chu kỳ, kéo `cts_n=1` giữa khung | Khung vẫn phát hết |
| 4 | Quan sát `tx` | `0 1 0 1 0 1 0 1 0 1`, mỗi bit 217 chu kỳ (tổng 2170) |
| 5 | Quan sát `tx_done` | Lên 1 ở cuối stop bit cuối, ≤ 2 chu kỳ pclk; `R 010 → 0x00000001` |

| 6 | Lặp bước 1–5 với `IER=0x01` (`W 018 0001 0x01` khi `tx_done=1`) | Khi ghi IER: `irq=1` ngay; sau start_tx: `irq=0` ở chu kỳ `tx_done` xuống; `irq=1` trong ≤ 2 chu kỳ sau stop bit cuối |

Pass criteria: không phát khi cts_n=1; `cts_n` chỉ xét trước start bit; frame đủ 10 bit; `irq` theo `tx_done` khi `tx_done_ie=1`.

### H-17 Giản đồ nhận 8N1 0x55 và rts_n
Source: HD §11 | Trace: REQ-RX-04..08, REQ-FC-01, REQ-FC-02 | Spec ID: 2.4.2.1, 2.4.2.2, 2.10.2.1, 2.10.3.1, 2.11.1.1, 2.11.1.2 | Priority: 1 | Check: Scoreboard, SVA
Precondition: CFG=0x03, BAUD=0x900D, rx_dis=0, `rts_n=0`.

| Step | Input | Expected output |
|---|---|---|
| 1 | Peer gửi 0x55 trên `rx`: `0 1 0 1 0 1 0 1 0 1`, mỗi bit 217 chu kỳ | Sau cạnh xuống + kiểm tra lại start ở tick 8 (≈ 108,5 chu kỳ): `rx_busy=1` |
| 2 | Quan sát sau mẫu stop cuối (≈ 9,5 bit sau cạnh xuống) | Trong ≤ 1 bit (217 chu kỳ): `rx_done=1`, đồng thời `rx_busy=0`; `rts_n=1` |
| 3 | `R 010` | `prdata=0x00000003` (tx_done=1, rx_done=1) |
| 4 | `R 004` | `prdata=0x00000055`, `pslverr=0` |
| 5 | Sau lần đọc | `rx_done=0`, `rts_n=0` |

| 6 | `IER=0x02`; lặp bước 1 khi chưa đọc: ngay khi `rx_done=1` | `irq=1`; sau `R 004` → `irq=0` |
| 7 | Khi `rx_done=1` (chưa đọc 0x55), peer gửi khung mới 0xAA | `overrun=1` (`R 010 → 0x00000083`), RXDATA giữ `0x55`, `rx_done` giữ 1, `rts_n=1` |

Pass criteria: trình tự `rx_busy` → `rx_done` + `rts_n=1` → đọc → `rts_n=0` đúng thời điểm; `irq` theo `rx_done`; khung đến khi đầy bị bỏ với `overrun=1`.

### H-18 Bảng chân lý ngắt irq
Source: HD §12 | Trace: REQ-IRQ-01..07 | Spec ID: 2.5.1, 2.12.1.1, 2.12.1.2, 2.12.1.3, 2.12.2.1, 2.12.2.2, 2.12.3.1, 2.12.3.2 | Priority: 1 | Check: Scoreboard, SVA
Precondition: Wrapper hoặc lõi, sau reset, BAUD=0x900D, cts_n=0.
Công thức: `irq = (tx_done_ie & tx_done) | (rx_done_ie & rx_done) | (err_ie & (parity_err | frame_err | overrun))`.

| # | IER (hex) | tx_done | rx_done | parity_err | frame_err | overrun | irq mong đợi |
|---|---|---|---|---|---|---|---|
| 1 | 0x00 | 1 | 0 | 0 | 0 | 0 | 0 |
| 2 | 0x01 | 1 | 0 | 0 | 0 | 0 | 1 |
| 3 | 0x01 | 0 | 1 | 1 | 1 | 1 | 0 |
| 4 | 0x02 | 1 | 0 | 0 | 0 | 0 | 0 |
| 5 | 0x02 | 0 | 1 | 0 | 0 | 0 | 1 |
| 6 | 0x04 | 1 | 1 | 0 | 0 | 0 | 0 |
| 7 | 0x04 | 1 | 1 | 1 | 0 | 0 | 1 |
| 8 | 0x04 | 1 | 1 | 0 | 1 | 0 | 1 |
| 9 | 0x04 | 1 | 1 | 0 | 0 | 1 | 1 |
| 10 | 0x07 | 0 | 0 | 0 | 0 | 0 | 0 |

| Step | Input | Expected output |
|---|---|---|
| 1 | Tạo từng nguồn (tx_done, rx_done, parity_err, frame_err, overrun) bằng khung thật; đo `irq` | Khớp bảng; `irq` giữ mức cao đến khi điều kiện hết (không phải xung); đổi trong ≤ 2 chu kỳ pclk sau khi nguồn đổi |
| 2 | `IER=0x02`, `rx_done=1` (`irq=1`), `R 004` | `irq=0` |
| 3 | `IER=0x01`, `tx_done=1` (`irq=1`), `W 00C 0001 0x1` | `tx_done=0` chu kỳ kế, `irq=0` |
| 4 | `tx_done=1`, `IER=0`; `W 018 0001 0x01` | `irq=1` ngay |
| 5 | `W 00C 0001 0x1` rồi `W 018 0001 0x01` khi `tx_done=0` | `irq=0`; lên 1 khi hết khung |

Pass criteria: 10 dòng bảng, 4 kịch bản chuyển đổi đều đúng; mỗi bit IER chỉ mở đúng nguồn của nó.

### H-19 Reset mềm CTRL.soft_rst
Source: HD §12 | Trace: REQ-SRST-01..09, REQ-ERR-11 | Spec ID: 2.3.2.1, 2.7.1.1, 2.7.1.2, 2.7.1.3, 2.7.1.4, 2.7.2.1, 2.7.2.2, 2.7.3, 4.1.1.1, 4.1.1.2 | Priority: 1 | Check: Scoreboard, SVA
Precondition: `CFG=0x1B`, `BAUD=0xB028`, `IER=0x07`, `TXDATA=0x41`, rx_done=1 trước, cts_n=0. ASSUMPTION: SPEC §12.2 REQ-SRST-02 (reset cả TXDATA, RXDATA, CFG, CTRL, BAUD, IER, STAT) là quyết định nhóm 11/11 mở rộng HD. ASSUMPTION (bước 7): HD §8 (bộ kiểm tra) cho E3 với CTRL=0x101 khi `tx_done=0`, còn HD §12 và SPEC §16.1 #2 chọn soft_rst ưu tiên và không báo lỗi; test theo HD §12. RTL hiện tại (TBG §5, E3) loại trừ trường hợp `pstrb[1] & pwdata[8]`, tức khớp với expected `pslverr=0`.

| Step | Input | Expected output |
|---|---|---|
| 1 | `W 00C 0010 0x00000100` (soft_rst=1, pstrb[1]=1) | `pslverr=0`, `pready=1`; giao dịch hoàn tất bình thường |
| 2 | `R 00C` từ chu kỳ thứ 3 | `prdata=0x00000000` (tự về 0, không cần ghi lại 0) |
| 3 | Từ chu kỳ thứ 3 sau lệnh ghi: đọc 7 thanh ghi | TXDATA=0, RXDATA=0, CFG=0, CTRL=0, STAT=0x00000001, BAUD=0x0000900D, IER=0; `pslverr=0` |
| 4 | Quan sát trong 2 chu kỳ reset | `rts_n=1`; sau đó (rx_dis=0, rx_done=0) `rts_n=0` |
| 5 | Đang phát 0x41 (ở bit giữa khung): `W 00C 0010 0x100` | `pslverr=0`; `tx=1` ngay, `tx_done=1`; phần còn lại của khung không xuất hiện |
| 6 | Đang nhận (rx_busy=1): `W 00C 0010 0x100` | `pslverr=0`; `rx_busy=0`; không có `rx_done` từ khung đó |
| 7 | `W 00C 0011 0x00000101` (soft_rst=1 và start_tx=1), khi `tx_done=1` rồi khi `tx_done=0` | `pslverr=0` cả hai lần; soft_rst ưu tiên: không có khung mới, khung đang phát bị hủy, `tx=1` |
| 8 | Sau reset mềm: `W 008 0001 0x03`, `R 008`, `W 000 0001 0x41`, `W 00C 0001 0x1` | `R 008 → 0x03` (UART không bị giữ reset); khung 0x41 8N1 phát đủ, 10 bit × 217 chu kỳ |

Pass criteria: reset trong ≤ 2 chu kỳ, từ chu kỳ 3 nhận lệnh, không bao giờ `pslverr`, soft_rst ưu tiên hơn start_tx.

---

# Phần 2. Test từ XLSX (`T-x.x.x`)

Thứ tự theo sheet Test_plan. Dòng `covered by H-NN` nghĩa là H-NN đã chứa đủ stimulus và expected của các Spec ID liệt kê; không viết lại.

## 2.1 Interface

### T-1.1.1.1 t1_1_1_1_apb_transfer
Source: XLSX Test_plan | Trace: REQ-APB-01, REQ-APB-02, REQ-APB-04 | Spec ID: 1.1.1.1, 1.1.1.2, 1.1.3.1 | Priority: 1 | Check: SVA
Precondition: Sau reset; lặp lại khi TX đang phát (8N1 0x41) và RX đang nhận (peer gửi 0x5A).

| Step | Input | Expected output |
|---|---|---|
| 1 | `R`/`W` lần lượt cả 7 thanh ghi (0x00…0x18), theo dõi psel, penable, pready, pslverr | Mỗi giao dịch: 1 chu kỳ setup (`psel=1 penable=0`) + đúng 1 chu kỳ access (`psel=penable=1`); `pready=1` ở cả hai |
| 2 | `W 020 1111 0x0` (địa chỉ ngoài bảng) | Chu kỳ setup: `pslverr=0`; chu kỳ access: `pslverr=1` |
| 3 | Lặp bước 1 khi `tx_done=0` và khi `rx_busy=1` | `pready=1` mọi chu kỳ, không có chu kỳ chờ |
| 4 | SVA suốt mô phỏng | `psel && penable \|-> pready`; `presetn \|-> pready`; `pslverr \|-> psel && penable` không bao giờ vi phạm |

Pass criteria: 0 vi phạm SVA; 0 chu kỳ chờ.

### T-1.1.1.3 t1_1_1_3_apb_write_read
covered by H-08 | Trace: REQ-APB-03 | Spec ID: 1.1.1.3, 1.1.1.4 | Priority: 1

### T-1.1.1.5 t1_1_1_5_apb_idle
Source: XLSX Test_plan; HD §8; Arm IHI 0024C | Trace: REQ-APB-05 | Spec ID: 1.1.1.5 | Priority: 2 | Check: Scoreboard
Precondition: `rx_done=1`, `RXDATA=0x5A`, `parity_err=1` (nhận 0x5A sai parity với `CFG=0x1B`, rồi `W 008 0001 0x03` khi rảnh); `TXDATA=0x41`, `tx_done=1`, cts_n=0. Ghi lại giá trị 7 thanh ghi (STAT=0x00000007).

| Step | Input | Expected output |
|---|---|---|
| 1 | `psel=0`, `penable=1`, `pwrite=1`, `paddr=0x00C`, `pstrb=1111`, `pwdata=0x00000101` giữ 100 chu kỳ | Không khung trên `tx` (quan sát 2300 chu kỳ), không soft reset, `pslverr=0` |
| 2 | `psel=0`, `penable=1`, `pwrite=0`, `paddr=0x004` giữ 100 chu kỳ | RXDATA không bị xóa cờ |
| 3 | Chỉ pha setup: `psel=1 penable=0 pwrite=0 paddr=0x004`, 1 chu kỳ, rồi `psel=0` (không có pha access) | RXDATA không bị xóa cờ |
| 4 | Đảo ngẫu nhiên `paddr`, `pwdata`, `pwrite`, `pstrb`, `penable` khi `psel=0` (1000 chu kỳ); gồm `paddr=0x020` | `pslverr=0` |
| 5 | `R 010`, `R 004` | `STAT=0x00000007` (không đổi), `RXDATA=0x5A`; 7 thanh ghi như ghi lại ở Precondition |

Pass criteria: không thanh ghi nào đổi, không cờ nào bị xóa, không khung trên `tx`.

### T-1.1.2.1 t1_1_2_1_apb_pstrb
Source: XLSX Test_plan; HD §2, §8 | Trace: REQ-APB-06, REQ-APB-07 | Spec ID: 1.1.2.1, 1.1.2.2 | Priority: 1 | Check: Scoreboard
Precondition: TX, RX rảnh, `BAUD=0x900D`, `CFG=0x03`, `IER=0x00`.

| Step | Input | Expected output |
|---|---|---|
| 1 | `W 014 0001 0x000000AB`, `R 014` | `pslverr=0`, `prdata=0x000090AB` (chỉ lane 0 đổi) |
| 2 | `W 014 0010 0x00005500`, `R 014` | `pslverr=0`, `prdata=0x000055AB` (chỉ lane 1 đổi) |
| 3 | `W 014 0011 0x0000900D` | Khôi phục `0x0000900D` |
| 4 | `W 014 1100 0xFFFF0000`, `R 014` | `pslverr=0`, `0x0000900D` (lane 2, 3 không có field) |
| 5 | `W 008 0010 0x0000FF00`, `R 008` | `pslverr=0`, `0x00000003` (lane 1 của CFG không có field) |
| 6 | pstrb=0000: `W 000 0000 0xFFFFFFFF`, `W 008 0000 0xFFFFFFFF`, `W 00C 0000 0x00000101`, `W 014 0000 0xFFFFFFFF`, `W 018 0000 0xFFFFFFFF`; đọc lại cả 7 thanh ghi | `pslverr=0` cả 5 lệnh; không thanh ghi đổi; không khung; không soft reset |
| 7 | Lặp bước 6 khi `tx_done=0` rồi khi `rx_busy=1` | `pslverr=0` (pstrb=0000 không bị E3/E4), khung đang chạy không đổi |

Pass criteria: lane ghi độc lập; pstrb=0000 không tác dụng và không báo lỗi, kể cả khi bận.

### T-1.2.1 t1_2_1_port_list
covered by H-01 | Trace: REQ-IO-01 | Spec ID: 1.2.1 | Priority: 1

### T-1.2.2 t1_2_2_reset_async
Source: XLSX Test_plan; HD §1, §2 | Trace: REQ-IO-02, REQ-IO-03, REQ-GEN-02 | Spec ID: 1.2.2, 2.6.1 | Priority: 1 | Check: SVA
Precondition: Đang chạy: `CFG=0x1B`, `IER=0x07`, TX giữa khung 0x41, `rx_done=1` (`rts_n=1`), `irq=1`.

| Step | Input | Expected output |
|---|---|---|
| 1 | Hạ `presetn=0` ở 10 ns sau sườn lên `pclk` (giữa hai sườn) | Trước sườn `pclk` kế tiếp: `tx=1 rts_n=1 irq=0 pslverr=0 pready=1` |
| 2 | Hạ `presetn=0` giữa pha access của một lệnh ghi lỗi | `pslverr=0` ngay (không cần sườn pclk) |
| 3 | Giữ reset 3 chu kỳ rồi nhả `presetn=1`; đọc 7 thanh ghi | TXDATA=0, RXDATA=0, CFG=0, CTRL=0, STAT=`0x00000001`, BAUD=`0x0000900D`, IER=0; khung đang phát không xuất hiện lại |

Pass criteria: output về giá trị reset không phụ thuộc sườn `pclk`; mọi thanh ghi và FSM về reset.

### T-1.3.1 t1_3_1_wrapper_pins
Source: XLSX Test_plan; HD §2 | Trace: REQ-TT-01..03 | Spec ID: 1.3.1, 1.3.2, 1.3.2.2 | Priority: 1 | Check: Scoreboard, SVA
Precondition: Wrapper `tt_um_hust_apb_uart`, `clk=25 MHz`, `rst_n=0` rồi 1.

| Step | Input | Expected output |
|---|---|---|
| 1 | Chân tĩnh, reset, `clk`, `rst_n` | Xem H-20 |
| 2 | Qua SPI: CFG=0x03; peer gửi 0x5A vào `ui_in[0]` | `uo_out[4]=1` (rx_done); `uo_out[1]=1` (rts_n); đọc RXDATA qua SPI → `0x5A` |
| 3 | Peer gửi khung sai parity (CFG=0x0B) | `uo_out[5]=1` (parity_err) |
| 4 | `ui_in[1]=1` (cts_n), SPI ghi TXDATA=0x41 và start_tx | `uo_out[0]=1` giữ nguyên, `uo_out[3]=0`; hạ `ui_in[1]=0` → `uo_out[0]` phát khung 0x41 |
| 5 | Một khung SPI đọc STAT, thực hiện ngay sau bước 3 (TX rảnh, `rx_done=1`, `parity_err=1`) | `uo_out[2]` (spi_miso) trùng MISO của khung: `00 00 00 00 00 07 00` (STAT=0x07) |
| 6 | IER=0x01, chờ hết khung | `uo_out[6]=1` trùng `irq` của lõi |
| 7 | Chân dự phòng, `uio_oe` | Xem H-20 |

Pass criteria: mọi chân đúng bảng SPEC §13.2; `clk→pclk`, `rst_n→presetn`.

## 2.2 Register map

### T-2.1.1.1 t2_1_1_1_reg_rw
Source: XLSX Test_plan; HD §4 | Trace: REQ-REG-01, REQ-REG-03 | Spec ID: 2.1.1.1, 2.1.1.3 | Priority: 1 | Check: Scoreboard
Precondition: TX, RX rảnh, sau reset.

| Step | Input | Expected output |
|---|---|---|
| 1 | `W 000 1111 0x000000A5`, `R 000`; lặp `0x55`, `0xAA`, `0xFF`, `0x00` | `prdata` = giá trị vừa ghi (8 bit), `pslverr=0` |
| 2 | `W 008 1111 0x0000001B`, `R 008`; lặp `0x00`, `0x55`, `0x2A`, `0x03` | `prdata` = giá trị ghi (CFG[6:0]) |
| 3 | `W 014 1111 0x0000B028`, `R 014`; lặp `0x00000001`, `0x0000FFFF`, `0x0000900D` | `prdata` = giá trị ghi (BAUD[15:0]) |
| 4 | `W 018 1111 0x00000005`, `R 018`; lặp `0x02`, `0x07`, `0x00` | `prdata` = giá trị ghi (IER[2:0]) |
| 5 | Sau mỗi lần ghi, đọc cả 7 địa chỉ | Chỉ thanh ghi vừa ghi đổi; không alias giữa các địa chỉ |
| 6 | Khôi phục `CFG=0x00`, `BAUD=0x900D`, `IER=0x00` | Về giá trị reset |

Pass criteria: 7 địa chỉ đúng (TXDATA 0x00, RXDATA 0x04, CFG 0x08, CTRL 0x0C, STAT 0x10, BAUD 0x14, IER 0x18); readback đúng.

### T-2.1.1.2 t2_1_1_2_reg_reset
covered by H-02 | Trace: REQ-REG-02 | Spec ID: 2.1.1.2 | Priority: 1

### T-2.1.1.4 t2_1_1_4_reg_rfu
Source: XLSX Test_plan; HD §4 | Trace: REQ-REG-04 | Spec ID: 2.1.1.4 | Priority: 1 | Check: Scoreboard
Precondition: TX, RX rảnh, sau reset.

| Step | Input | Expected output |
|---|---|---|
| 1 | `W 000 1111 0xFFFFFFFF`, `R 000` | `0x000000FF` (TXDATA[31:8] đọc 0) |
| 2 | `W 008 1111 0xFFFFFFFF`, `R 008`, rồi `W 008 1111 0x03` | `0x0000007F`; khôi phục `0x03` |
| 3 | `W 014 1111 0xFFFFFFFF`, `R 014`, rồi `W 014 1111 0x0000900D` | `0x0000FFFF`; khôi phục |
| 4 | `W 018 1111 0xFFFFFFFF`, `R 018`, rồi `W 018 1111 0x0` | `0x00000007` |
| 5 | `W 00C 1111 0xFFFFFEFE` (bit 0 = 0 và bit 8 = 0, các bit rfu = 1), `R 00C` | `pslverr=0`, `0x00000000`; không có khung, không soft reset |
| 6 | `R 004`, `R 010` | `prdata[31:8]=0` cả hai |

Pass criteria: bit rfu đọc 0, ghi không tác dụng, không báo lỗi.

## 2.3 CFG, CTRL, STAT

### T-2.2.1.1 t2_2_1_1_tx_24_formats
covered by H-05 | Trace: REQ-FRM-01, REQ-FRM-04, REQ-FRM-05 | Spec ID: 2.2.1.1, 2.2.1.2, 2.2.1.3, 2.2.1.4, 2.9.1.1, 2.9.1.4, 2.9.1.5 | Priority: 1

### T-2.2.2.1 t2_2_2_1_tx_dis
Source: XLSX Test_plan; HD §4; A4 | Trace: REQ-TX-10 | Spec ID: 2.2.2.1 | Priority: 1 | Check: Scoreboard
Precondition: `CFG=0x23` (8N1, `tx_dis=1`), TX rảnh, cts_n=0, `TXDATA=0x41`. ASSUMPTION: Q2 trong SPEC §16.2 chưa được xác nhận: khi `tx_dis=1`, `start_tx` không làm `tx_done` xuống 0.

| Step | Input | Expected output |
|---|---|---|
| 1 | `W 00C 0001 0x1` | `pslverr=0`; `tx=1` suốt 2300 chu kỳ (không khung); `R 010 → 0x00000011` (tx_done=1, STAT[4]=1) |
| 2 | `W 008 0001 0x03` (`tx_dis=0`) | `pslverr=0`; `R 010 → 0x00000001` |
| 3 | `W 00C 0001 0x1` | Khung 0x41 8N1 phát bình thường (`0 1 0 0 0 0 0 1 0 1`); `tx_done` 0 → 1 |

Pass criteria: `tx_dis=1` không tạo khung, `pslverr=0`; `tx_dis=0` phát đúng.

### T-2.2.2.2 t2_2_2_2_rx_dis
Source: XLSX Test_plan; HD §4 | Trace: REQ-RX-14, REQ-FC-03 | Spec ID: 2.2.2.2, 2.11.1.3 | Priority: 1 | Check: Scoreboard, SVA
Precondition: `CFG=0x43` (8N1, `rx_dis=1`), BAUD=0x900D.

| Step | Input | Expected output |
|---|---|---|
| 1 | Quan sát sau ghi CFG | `rts_n=1` ngay khi `rx_dis=1` và giữ 1 suốt thời gian rx_dis |
| 2 | Peer gửi 0x5A (`0 0 1 0 1 1 0 1 0 1`) vào `rx` | `rx_busy=0`, `rx_done=0` mọi chu kỳ; `R 010 → 0x00000021` (tx_done=1, STAT[5]=1); RXDATA = 0 |
| 3 | `W 008 0001 0x03` (`rx_dis=0`) | `rts_n=0` trong ≤ 2 chu kỳ; `R 010 → 0x00000001` |
| 4 | Peer gửi 0x5A | `rx_done=1`, `rts_n=1`, `R 004 → 0x5A` |

Pass criteria: `rx_dis=1`: không nhận, `rts_n=1`; `rx_dis=0`: nhận đúng.

### T-2.3.1.1 t2_3_1_1_tx_start
Source: XLSX Test_plan; HD §4, §10, §11 | Trace: REQ-TX-01..03, REQ-TX-07 | Spec ID: 2.3.1.1, 2.3.1.2, 2.3.1.3, 2.9.2.3 | Priority: 1 | Check: Scoreboard
Precondition: TX rảnh, cts_n=0, `CFG=0x03`, BAUD=0x900D, `TXDATA=0x41`.

| Step | Input | Expected output |
|---|---|---|
| 1 | `W 00C 0001 0x00000000` | `pslverr=0`; không khung (quan sát 2300 chu kỳ) |
| 2 | `W 00C 1110 0x00000001` (pstrb[0]=0) | `pslverr=0`; không khung |
| 3 | `W 00C 0001 0x00000001`, rồi `R 00C` ngay | Đúng 1 khung 0x41 8N1; `R 00C → 0x00000000`; `tx_done=0` ở chu kỳ kế |
| 4 | Chờ `tx_done=1`; `W 000 0001 0x42`, `W 00C 0001 0x1` | Khung kế 0x42 phát đúng; đếm tổng đúng 2 khung trong 3 × thời gian khung |

Pass criteria: đúng 1 khung mỗi lệnh `start_tx=1`; ghi 0 hoặc pstrb[0]=0 không tạo khung.

### T-2.3.2.1 t2_3_2_1_soft_reset_regs
covered by H-19 | Trace: REQ-SRST-01, REQ-SRST-02, REQ-SRST-06, REQ-SRST-07 | Spec ID: 2.3.2.1, 2.7.1.1, 2.7.2.1, 2.7.2.2 | Priority: 1

### T-2.4.1.1 t2_4_1_1_tx_done_timing
covered by H-16 | Trace: REQ-TX-04..06 | Spec ID: 2.4.1.1, 2.9.2.1, 2.9.2.2 | Priority: 1

### T-2.4.2.1 t2_4_2_1_rx_flags
covered by H-17 | Trace: REQ-RX-04, REQ-RX-06, REQ-RX-07 | Spec ID: 2.4.2.1, 2.4.2.2, 2.10.2.1, 2.10.3.1 | Priority: 1

### T-2.4.3.1 t2_4_3_1_stat_copy
Source: XLSX Test_plan; HD §4 | Trace: REQ-REG-05 | Spec ID: 2.4.3.1 | Priority: 1 | Check: Scoreboard
Precondition: TX, RX rảnh.

| Step | Input | Expected output |
|---|---|---|
| 1 | `W 008 0001 0x03`, `R 010` | `0x00000001` (STAT[5:4]=00) |
| 2 | `W 008 0001 0x23`, `R 010` | `0x00000011` (STAT[4]=CFG[5]=1) |
| 3 | `W 008 0001 0x43`, `R 010` | `0x00000021` (STAT[5]=CFG[6]=1) |
| 4 | `W 008 0001 0x63`, `R 010` | `0x00000031` |
| 5 | `W 008 0001 0x03` | Khôi phục |

Pass criteria: `STAT[4]=CFG[5]`, `STAT[5]=CFG[6]` ở cả 4 tổ hợp.

### T-2.5.1 t2_5_1_irq_sources
covered by H-18 | Trace: REQ-IRQ-01..03 | Spec ID: 2.5.1, 2.12.1.1, 2.12.1.2, 2.12.1.3 | Priority: 1

## 2.4 Reset mềm, baud

### T-2.7.1.2 t2_7_1_2_soft_reset_busy
covered by H-19 | Trace: REQ-SRST-03..05, REQ-SRST-08 | Spec ID: 2.7.1.2, 2.7.1.3, 2.7.1.4, 2.7.3 | Priority: 1

### T-2.8.1.1 t2_8_1_1_baud_formula
covered by H-04 và H-03 | Trace: REQ-BAUD-01, REQ-BAUD-02 | Spec ID: 2.8.1.1, 2.8.1.2 | Priority: 1

### T-2.8.2.1 t2_8_2_1_baud_required
covered by H-03 | Trace: REQ-BAUD-03 | Spec ID: 2.8.2.1 | Priority: 1

### T-2.8.2.2 t2_8_2_2_baud_bonus
covered by H-03 | Trace: REQ-BAUD-04, REQ-BAUD-05 | Spec ID: 2.8.2.2, 4.4.1 | Priority: 2

## 2.5 UART TX

### T-2.9.1.2 t2_9_1_2_tx_mask
Source: XLSX Test_plan; HD §6 | Trace: REQ-FRM-02 | Spec ID: 2.9.1.2, 2.9.1.6 | Priority: 1 | Check: Scoreboard
Precondition: cts_n=0, BAUD=0x900D, `TXDATA=0xE0`.

| Step | Input | Expected output |
|---|---|---|
| 1 | `CFG=0x00` (N=5); `W 000 0001 0xE0`; start_tx | `tx`: `0 00000 1` (`0xE0 & 0x1F = 0x00`); `R 000 → 0x000000E0` trước và sau khung |
| 2 | `CFG=0x01` (N=6); `0xE0` | `tx`: `0 000001 1` (`0xE0 & 0x3F = 0x20`); `R 000 → 0xE0` |
| 3 | `CFG=0x02` (N=7); `0xE0` | `tx`: `0 0000011 1` (`0xE0 & 0x7F = 0x60`); `R 000 → 0xE0` |
| 4 | `CFG=0x00` (N=5); `0xFF` | `tx`: `0 11111 1`; `R 000 → 0xFF` |

Pass criteria: chỉ `tx_data[N−1:0]` được phát; TXDATA đọc lại đủ 8 bit.

### T-2.9.1.3 t2_9_1_3_tx_parity
Source: XLSX Test_plan; HD §6 | Trace: REQ-FRM-03 | Spec ID: 2.9.1.3 | Priority: 1 | Check: Scoreboard
Precondition: cts_n=0, BAUD=0x900D. Bit parity mong đợi trên `tx` (ngay sau bit data cuối):

| N | CFG chẵn / lẻ | Data ghi | N bit phát | Số bit 1 | Parity chẵn | Parity lẻ |
|---|---|---|---|---|---|---|
| 8 | 0x1B / 0x0B | 0x00 | 0x00 | 0 | 0 | 1 |
| 8 | 0x1B / 0x0B | 0x01 | 0x01 | 1 | 1 | 0 |
| 8 | 0x1B / 0x0B | 0xA5 | 0xA5 | 4 | 0 | 1 |
| 8 | 0x1B / 0x0B | 0x7F | 0x7F | 7 | 1 | 0 |
| 8 | 0x1B / 0x0B | 0xFF | 0xFF | 8 | 0 | 1 |
| 8 | 0x1B / 0x0B | 0xE5 | 0xE5 | 5 | 1 | 0 |
| 7 | 0x1A / 0x0A | 0xE5 | 0x65 | 4 | 0 | 1 |
| 6 | 0x19 / 0x09 | 0xE5 | 0x25 | 3 | 1 | 0 |
| 5 | 0x18 / 0x08 | 0xE5 | 0x05 | 2 | 0 | 1 |

| Step | Input | Expected output |
|---|---|---|
| 1 | Với mỗi dòng và mỗi loại parity: ghi CFG, TXDATA, start_tx | Chuỗi `tx` = start `0`, N bit data LSB trước, bit parity theo bảng, stop `1`; tổng số bit 1 của data và parity chẵn (parity chẵn) hoặc lẻ (parity lẻ) |
| 2 | N < 8, data có bit cao khác nhau (0xE5 so với 0x05 ở N=5) | Parity giống nhau (chỉ tính N bit được phát) |

Pass criteria: 18 tổ hợp đúng bit parity, parity đứng sau data.

### T-2.9.3.1 t2_9_3_1_tx_cts
Source: XLSX Test_plan; HD §11, §3, §13 (Q6) | Trace: REQ-TX-08, REQ-TX-09, REQ-IO-04, REQ-ERR-12 | Spec ID: 2.9.3.1, 4.2.1, 1.2.3 | Priority: 1 | Check: Scoreboard, SVA
Precondition: `CFG=0x03`, BAUD=0x900D, `TXDATA=0x55`, `cts_n=1`, TX rảnh. Chuỗi chờ/giữa khung xem thêm H-16.

| Step | Input | Expected output |
|---|---|---|
| 1 | `W 00C 0001 0x1` | Chu kỳ kế: `tx_done=0`, `tx=1`; `R 010 → 0x00000000` |
| 2 | Giữ `cts_n=1` 3000 chu kỳ; `W 000 0001 0x7F`, `W 00C 0001 0x1`, `W 008 0001 0x1B` | `tx=1`, `tx_done=0` suốt thời gian chờ; cả 3 lệnh `pslverr=1` (E3, E3, E4); không khung phụ |
| 3 | Hạ `cts_n=0` tại thời điểm `t0` bất kỳ giữa hai sườn pclk | Start bit (tx 1→0) không xuất hiện sớm hơn 2 chu kỳ pclk sau `t0` (2 FF đồng bộ) |
| 4 | Kéo `cts_n=1` sau 1 bit (217 chu kỳ) | Khung vẫn phát đủ `0 1 0 1 0 1 0 1 0 1`; `tx_done` chỉ lên ở cuối stop bit cuối |
| 5 | Kiểm tra netlist/RTL | Từ cổng `rx` và `cts_n` có ≥ 2 flip-flop trước logic đầu tiên |

Pass criteria: không phát khi `cts_n=1`; thay đổi `cts_n` có tác dụng sau ≥ 2 chu kỳ pclk.

## 2.6 UART RX

### T-2.10.1.1 t2_10_1_1_rx_24_formats
covered by H-05 (đúng parity) và T-3.3.1 (sai parity theo từng N) | Trace: REQ-RX-01..03 | Spec ID: 2.10.1.1, 2.10.1.2, 2.10.1.3 | Priority: 1

### T-2.10.2.2 t2_10_2_2_rx_glitch
Source: XLSX Test_plan; HD §3 | Trace: REQ-RX-05 | Spec ID: 2.10.2.2 | Priority: 1 | Check: Scoreboard
Precondition: RX rảnh, `CFG=0x03`, BAUD=0x900D (T = 217 chu kỳ), `RXDATA=0x00`. Ghi chú: REQ-RX-05 là [Hint]. ASSUMPTION: ngưỡng 0,4 bit (bước 3) chỉ là gợi ý; bước 1 và 2 là bắt buộc.

| Step | Input | Expected output |
|---|---|---|
| 1 | `rx=0` đúng 5 chu kỳ pclk rồi về 1; chờ 2170 chu kỳ | `rx_busy=0` và `rx_done=0` mọi chu kỳ; `R 010 → 0x00000001` |
| 2 | `rx=0` 65 chu kỳ (0,3 bit); chờ 2170 chu kỳ | Như bước 1 |
| 3 | `rx=0` 84 chu kỳ (0,39 bit < 0,4 bit); chờ 2170 chu kỳ | Như bước 1; `RXDATA` vẫn 0 |
| 4 | Ngay sau đó peer gửi 0x55 hợp lệ | `rx_done=1`, `R 004 → 0x55`, mọi cờ lỗi 0 (bộ thu đã về IDLE) |

Pass criteria: xung thấp ngắn hơn 0,4 bit không tạo khung; khung kế tiếp nhận đúng.

### T-2.10.3.2 t2_10_3_2_rx_read_clear
Source: XLSX Test_plan; HD §4, §11, §12 | Trace: REQ-RX-08..10 | Spec ID: 2.10.3.2, 2.10.3.3, 2.10.3.4 | Priority: 1 (2.10.3.2), 2 (2.10.3.3, 2.10.3.4) | Check: Scoreboard
Precondition: `CFG=0x0B` (8O1), BAUD=0x900D; trước bước 4 và 5 luôn đưa về `rx_done=1`, `RXDATA=` byte cũ X chưa đọc. Peer gửi 0x41 với bit parity sai và stop=0 (`parity_err=1`, `frame_err=1`), rồi gửi thêm 0x42 hợp lệ khi chưa đọc (`overrun=1`). ASSUMPTION (bước 4, 5): REQ-RX-09 và REQ-RX-10 là quyết định nhóm 11/11, chưa xác nhận với hidden testbench (Q4).

| Step | Input | Expected output |
|---|---|---|
| 1 | `R 010` ba lần liên tiếp | `0x000000C7` cả 3 lần (tx_done, rx_done, parity_err, frame_err, overrun); đọc STAT không xóa cờ |
| 2 | `R 004` | `pslverr=0`, `prdata=0x00000041` (byte cũ được giữ) |
| 3 | `R 010` | `0x00000001`: `rx_done`, `parity_err`, `frame_err`, `overrun` đều về 0; `rts_n=0` |
| 4 | Khi `rx_done=0`: `R 004` | `pslverr=0`, `prdata=0x00000041` (byte nhận gần nhất; sau reset là 0); các cờ giữ 0. Lặp lại khi peer đang gửi giữa khung: khung vẫn hoàn tất, `RXDATA=` byte mới, `rx_done=1` |
| 5 | Căn peer sao cho mẫu stop cuối của byte mới (0x77) rơi đúng chu kỳ access của `R 004` (quét lệch −3…+3 chu kỳ) | Với căn đúng trùng chu kỳ: `prdata` = byte cũ; sau sườn kết thúc pha access RXDATA = 0x77, `rx_done=1`, `overrun=0`, cờ lỗi theo byte mới; không mất byte nào |

Pass criteria: đọc RXDATA xóa 4 cờ; đọc khi `rx_done=0` không lỗi; trường hợp trùng chu kỳ không mất byte.

### T-2.10.4.1 t2_10_4_1_rx_tolerance
covered by H-06 | Trace: REQ-RX-11 | Spec ID: 2.10.4.1 | Priority: 1

### T-2.10.4.2 t2_10_4_2_rx_tolerance_bonus
Source: XLSX Test_plan; HD §7 | Trace: REQ-RX-12 | Spec ID: 2.10.4.2 | Priority: 2 (cộng điểm F4) | Check: Scoreboard
Precondition: BAUD=0x900D (T = 217 chu kỳ).

| Step | Input | Expected output |
|---|---|---|
| 1 | Peer nhanh `+3 %`: bit time = 217 / 1,03 = **210,68** chu kỳ. Gửi 24 dạng khung, data 0x00, 0xFF, 0xA5, 0x5A | Nhận đúng, mọi cờ lỗi 0 |
| 2 | Peer chậm `−3 %`: bit time = 217 / 0,97 = **223,71** chu kỳ. Như bước 1 | Nhận đúng, mọi cờ lỗi 0 |

Pass criteria: 24 dạng × 2 hướng đúng (giới hạn lý thuyết n=12: 3,80 %).

## 2.7 Flow control, ngắt

### T-2.11.1.1 t2_11_1_1_rts_sequence
covered by H-17 | Trace: REQ-FC-01, REQ-FC-02 | Spec ID: 2.11.1.1, 2.11.1.2 | Priority: 1

### T-2.12.2.1 t2_12_2_1_irq_clear
covered by H-18 | Trace: REQ-IRQ-04, REQ-IRQ-05 | Spec ID: 2.12.2.1, 2.12.2.2 | Priority: 1

### T-2.12.3.1 t2_12_3_1_irq_enable
covered by H-18 | Trace: REQ-IRQ-06, REQ-IRQ-07 | Spec ID: 2.12.3.1, 2.12.3.2 | Priority: 1

## 2.8 spi2apb và host

### T-2.13.1.1 t2_13_1_1_spi_write
covered by H-10 | Trace: REQ-SPI-01..05 | Spec ID: 2.13.1.1, 2.13.1.2, 2.13.1.3, 2.13.1.4, 2.13.1.5, 2.13.2.1 | Priority: 1

### T-2.13.2.2 t2_13_2_2_spi_read
covered by H-11 | Trace: REQ-SPI-06 | Spec ID: 2.13.2.2 | Priority: 1

### T-2.13.3.1 t2_13_3_1_spi_errors
covered by H-12 | Trace: REQ-SPI-07, REQ-SPI-08 | Spec ID: 2.13.3.1, 2.13.3.2 | Priority: 1

### T-2.13.4.1 t2_13_4_1_spi_abort
covered by H-13 | Trace: REQ-SPI-09, REQ-SPI-10 | Spec ID: 2.13.4.1, 2.13.4.2 | Priority: 1

### T-2.14.1.1 t2_14_1_1_seq_tx
covered by H-14 | Trace: SPEC §14.1 | Spec ID: 2.14.1.1 | Priority: 1

### T-2.14.1.2 t2_14_1_2_seq_rx
covered by H-15 | Trace: SPEC §14.2 | Spec ID: 2.14.1.2 | Priority: 1

## 2.9 Lỗi APB và lỗi đường truyền

### T-3.1.1.1 t3_1_1_1_err_e1
Source: XLSX Test_plan; HD §8; PR 4.1 | Trace: REQ-ERR (E1) | Spec ID: 3.1.1.1, 3.1.1.2 | Priority: 1 | Check: Scoreboard
Precondition: TX, RX rảnh; `CFG=0x03`, `BAUD=0x900D`, `TXDATA=0x41`, `IER=0x05`; `rx_done=1`, `RXDATA=0x5A`.

| Step | Input | Expected output |
|---|---|---|
| 1 | `R` tại `0x01C`, `0x020`, `0xFFC` | `pslverr=1`, `prdata=0x00000000` |
| 2 | `R` tại `0x001`, `0x002`, `0x003`, `0x00D`, `0x015`, `0x005` (lệch của RXDATA) | `pslverr=1`, `prdata=0x00000000`; riêng `R 005`: `rx_done` không bị xóa |
| 3 | `W` (`pstrb=1111`, `pwdata=0xFFFFFFFF`) tại các địa chỉ ở bước 1 và 2 | `pslverr=1`; không khung, không soft reset |
| 4 | Đọc 7 thanh ghi hợp lệ (0x00…0x18) | Giá trị như Precondition (không đổi); `pslverr=0` |

Pass criteria: mọi địa chỉ ngoài bảng hoặc không căn 4 byte báo E1; đọc trả 0; không tác dụng phụ.

### T-3.1.2 t3_1_2_err_e2
Source: XLSX Test_plan; HD §4, §8 | Trace: REQ-ERR (E2) | Spec ID: 3.1.2 | Priority: 1 | Check: Scoreboard
Precondition: `rx_done=1`, `RXDATA=0x5A`, `STAT=0x00000003`.

| Step | Input | Expected output |
|---|---|---|
| 1 | `W 004 1111 0xFFFFFFFF`; `W 004 0000 0x0` | `pslverr=1` cả hai (bất kể pstrb) |
| 2 | `W 010 1111 0xFFFFFFFF`; `W 010 0000 0x0` | `pslverr=1` cả hai |
| 3 | `R 010` | `0x00000003` (`rx_done` vẫn 1: lệnh ghi không xóa cờ) |
| 4 | `R 004`, rồi `R 010` | `prdata=0x5A`, `pslverr=0`; sau đó `0x00000001` (chỉ do lần đọc RXDATA) |

Pass criteria: ghi RXDATA/STAT luôn E2; giá trị và cờ không đổi do lệnh ghi.

### T-3.1.3.1 t3_1_3_1_err_e3
covered by H-09 (E3a–E3c) | Trace: REQ-ERR (E3), REQ-ERR-06 | Spec ID: 3.1.3.1, 3.1.3.2, 3.1.6 | Priority: 1

### T-3.1.4.1 t3_1_4_1_err_e4
Source: XLSX Test_plan; HD §8, §11; PR 4.1 | Trace: REQ-ERR (E4), REQ-ERR-12 | Spec ID: 3.1.4.1, 3.1.4.2, 3.1.4.3 | Priority: 1 | Check: Scoreboard
Precondition: `CFG=0x03`, `BAUD=0x900D`. Chạy các lệnh E4a–E4c của H-09 trong 3 trạng thái: (a) TX đang phát 0x41; (b) `rx_busy=1` (peer đang gửi 0x5A, `tx_done=1`); (c) đang chờ cts_n (`cts_n=1`, start_tx đã ghi, `tx_done=0`).

| Step | Input | Expected output |
|---|---|---|
| 1 | Mỗi trạng thái: `W 008 0001 0x1B`; `W 014 0001 0x000000AB`; `W 014 0010 0x00002000`; `W 014 0011 0x0000201B` | `pslverr=1` cả 4 lệnh; `R 008 → 0x03`, `R 014 → 0x900D` |
| 2 | Mỗi trạng thái: `W 008 0010 0x0000FF00`; `W 008 0000 0x0`; `W 014 1100 0xFFFF0000`; `W 014 0000 0x0` | `pslverr=0`; thanh ghi không đổi |
| 3 | Kết thúc từng trạng thái | (a) khung 0x41 phát đủ; (b) khung 0x5A nhận đúng `RXDATA=0x5A`, không cờ lỗi; (c) hạ cts_n=0 → khung phát đủ. Cả 3 dùng cấu hình cũ (217 chu kỳ/bit, 8N1) |

Pass criteria: E4 đúng ở cả `tx_done=0`, `rx_busy=1` và khi chờ cts_n; khung đang chạy không đổi.

### T-3.1.5 t3_1_5_err_e5
Source: XLSX Test_plan; HD §4, §8; PR 4.1 | Trace: REQ-ERR (E5), REQ-BAUD-06 | Spec ID: 3.1.5 | Priority: 1 | Check: Scoreboard
Precondition: TX, RX rảnh, `BAUD=0x900D`.

| Step | Input | Expected output |
|---|---|---|
| 1 | `W 014 0011 0x00000000` | `pslverr=1`; `R 014 → 0x0000900D` |
| 2 | `W 014 0001 0x00000000` (chỉ lane 0; `div_int` = {0x0, 0x00} = 0) | `pslverr=1`; `R 014 → 0x0000900D` |
| 3 | `W 014 0011 0x00009000` (div_int = 0, div_frac = 9) | `pslverr=1` (div_frac khác 0 không cứu div_int = 0); BAUD không đổi |
| 4 | `W 014 0011 0x00009100` (div_int = 0x100) rồi `W 014 0010 0x00000000` (chỉ lane 1; div_int = {0x0, 0x00} = 0) | Lệnh đầu `pslverr=0`, `R 014 → 0x00009100`; lệnh sau `pslverr=1`, BAUD vẫn `0x00009100` |
| 5 | `W 014 0001 0x00000001` (lane 0 → div_int = 0x101) | `pslverr=0`; `R 014 → 0x00009101` |
| 6 | `W 014 0011 0x00000001` (div_int = 1, div_frac = 0) | `pslverr=0`; `R 014 → 0x00000001`; khôi phục `0x0000900D` |

Pass criteria: `pslverr=1` khi và chỉ khi div_int sau ghi (gộp lane ghi với giá trị hiện tại) bằng 0; BAUD không đổi khi lỗi.

### T-3.2.1.1 t3_2_1_1_err_none
Source: XLSX Test_plan; HD §1, §8; PR 5.3 | Trace: REQ-ERR-07..11 | Spec ID: 3.2.1.1, 3.2.1.2, 3.2.1.3, 3.2.1.4 | Priority: 1 | Check: Scoreboard
Precondition: `CFG=0x03`, `BAUD=0x900D`, cts_n=0.

| Step | Input | Expected output |
|---|---|---|
| 1 | Peer đang gửi 0x5A (`rx_busy=1`), `tx_done=1`: `W 000 0001 0x42`, `W 00C 0001 0x1` | `pslverr=0` cả hai; TX phát 0x42 và RX nhận 0x5A cùng lúc, cả hai đúng, không cờ lỗi |
| 2 | Khi bận (TX đang phát hoặc `rx_busy=1`): `W 008 0010 0x0000FF00`, `W 008 0000 0x0`, `W 014 1100 0xFFFF0000`, `W 014 0000 0x0` | `pslverr=0` |
| 3 | `tx_done=0`: `W 00C 0001 0x00000000` | `pslverr=0` |
| 4 | Mọi trạng thái (rảnh, TX bận, RX bận, chờ cts_n): `W 018 0001 0x07` và đọc cả 7 thanh ghi (kể cả `R 004` khi `rx_done=0`, `R 00C`) | `pslverr=0` |

Pass criteria: không báo lỗi ở bất kỳ truy cập hợp lệ nào; TX và RX đồng thời đúng.

### T-3.3.1 t3_3_1_err_parity
Source: XLSX Test_plan; HD §4; A3 | Trace: REQ-RX-03, SPEC §9.4 | Spec ID: 3.3.1, 2.4.4.1 | Priority: 1 | Check: Scoreboard
Precondition: BAUD=0x900D, `IER=0x04`; `STAT[2]=0` sau reset (`R 010 → 0x00000001`).

| Step | Input | Expected output |
|---|---|---|
| 1 | Với N = 5…8 và parity chẵn/lẻ (CFG: 5→0x18/0x08, 6→0x19/0x09, 7→0x1A/0x0A, 8→0x1B/0x0B): peer gửi data 0xA5 với bit parity **đảo** | `rx_done=1`; `R 010 → 0x00000007` (tx_done, rx_done, parity_err); `irq=1`; `R 004 →` N bit thấp của 0xA5 (vẫn đọc được data) |
| 2 | Sau `R 004` | `R 010 → 0x00000001`; `parity_err=0`; `irq=0` |
| 3 | Cùng cấu hình, peer gửi parity **đúng** | `R 010 → 0x00000003`; `parity_err=0`; `irq=0` (IER=0x04 chỉ mở err_ie) |

Pass criteria: 8 tổ hợp (N × loại parity) đặt đúng `parity_err`; không đặt khi parity đúng; đọc RXDATA xóa cờ.

### T-3.3.2.1 t3_3_2_1_err_frame
Source: XLSX Test_plan; HD §4, §7; A3, A9 | Trace: REQ-RX-08, SPEC §9.4 | Spec ID: 3.3.2.1, 3.3.2.2, 2.4.4.2 | Priority: 1 | Check: Scoreboard
Precondition: `CFG=0x03` (1 stop), BAUD=0x900D. Trường hợp 2 stop (stop thứ nhất hoặc thứ hai bằng 0): H-07 bước 1–3.

| Step | Input | Expected output |
|---|---|---|
| 1 | Sau reset: `R 010` | `STAT[6]=0` (`0x00000001`) |
| 2 | Peer gửi 0x41 với stop = 0 (`0 1 0 0 0 0 0 1 0 0`) | `rx_done=1`; `R 010 → 0x00000043` (tx_done, rx_done, frame_err); `R 004 → 0x41` |
| 3 | `R 010` sau lần đọc RXDATA | `0x00000001` (`frame_err` về 0) |

Pass criteria: stop = 0 đặt `frame_err=1` và `rx_done=1`; đọc RXDATA xóa `frame_err`.

### T-3.3.3 t3_3_3_err_overrun
Source: XLSX Test_plan; HD §3, §4, §11; A7 | Trace: REQ-RX-08, SPEC §9.4 | Spec ID: 3.3.3, 2.4.4.3 | Priority: 1 | Check: Scoreboard
Precondition: `CFG=0x03`, BAUD=0x900D; `STAT[7]=0` sau reset. Peer đã gửi 0x11 và host chưa đọc (`rx_done=1`, `rts_n=1`).

| Step | Input | Expected output |
|---|---|---|
| 1 | Peer gửi thêm 0x22 | `R 010 → 0x00000083` (tx_done, rx_done, overrun); `rts_n=1` giữ nguyên |
| 2 | `R 004` | `prdata=0x00000011` (giữ ký tự cũ, khung 0x22 bị bỏ) |
| 3 | `R 010` | `0x00000001`: `rx_done` và `overrun` về 0; `rts_n=0` |
| 4 | Peer gửi 0x33 | Nhận bình thường: `R 004 → 0x33`, `overrun=0` |
| 5 | `IER=0x04`, tạo overrun lại | `irq=1`; sau `R 004` → `irq=0` |

Pass criteria: khung mới bị bỏ, RXDATA giữ byte cũ, `overrun=1`, `rx_done` giữ 1; đọc xóa cờ.

## 2.10 Corner case của XLSX

### T-4.1.1.1 t4_1_1_1_soft_rst_with_start
covered by H-19 (bước 7) | Trace: REQ-SRST-09 | Spec ID: 4.1.1.1, 4.1.1.2 | Priority: 1

### T-4.3.1 t4_3_1_rx_fast_back_to_back
covered by H-07 (bước 4) | Trace: REQ-RX-13 | Spec ID: 4.3.1 | Priority: 1

---

# Phần 3. Corner case bổ sung (`C-NN`)

Các case dưới đây không có trong XLSX và không trùng nội dung với Phần 1–2. Case dựa trên giả định chưa xác nhận được gắn `ASSUMPTION`.

### C-01 BAUD nhỏ nhất hợp lệ: div_int = 1
Source: SPEC §6, §5.2 | Trace: REQ-BAUD-01, REQ-BAUD-06 | Spec ID: 2.8.1.1, 3.1.5 | Priority: 2 | Check: Scoreboard
Precondition: TX, RX rảnh, cts_n=0, `CFG=0x03`, `TXDATA=0x55`. ASSUMPTION: `BAUD=0x0001` (D=1, div_frac=0) hợp lệ vì `div_int ≥ 1`; chỉ kiểm TX (RX ở D=1 không được yêu cầu vì 2 FF đồng bộ dài hơn 1 tick).

| Step | Input | Expected output |
|---|---|---|
| 1 | `W 014 0011 0x00000001` | `pslverr=0`; `R 014 → 0x00000001` |
| 2 | `W 00C 0001 0x1` | Mỗi bit trên `tx` dài đúng `16·1 + 0 = 16` chu kỳ; khung `0 1 0 1 0 1 0 1 0 1` dài 160 chu kỳ; `tx_done` lên ≤ 2 chu kỳ sau stop |
| 3 | `W 014 0011 0x0000900D` | Khôi phục |

Pass criteria: 10 bit × 16 chu kỳ, không bit nào lệch.

### C-02 BAUD lớn nhất: 0xFFFF (bộ đếm 12 bit đầy)
Source: SPEC §6.2 | Trace: REQ-BAUD-01 | Spec ID: 2.8.1.1 | Priority: 2 | Check: Scoreboard
Precondition: TX, RX rảnh, cts_n=0, `CFG=0x00` (5N1), `TXDATA=0x15`.

| Step | Input | Expected output |
|---|---|---|
| 1 | `W 014 0011 0x0000FFFF` (div_int = 4095, div_frac = 15) | `pslverr=0`; `R 014 → 0x0000FFFF` |
| 2 | `W 00C 0001 0x1` | Mỗi bit dài đúng `16·4095 + 15 = 65535` chu kỳ; khoảng cách giữa hai tick là 4095 hoặc 4096 chu kỳ (không tràn `cnt`); khung 5N1 dài 7 × 65535 = 458745 chu kỳ |
| 3 | Chuỗi `tx` | `0 1 0 1 0 1 1` (start, 0x15 = `10101` LSB trước: `1 0 1 0 1`, stop) |
| 4 | `W 014 0011 0x0000900D` sau `tx_done=1` | Khôi phục |

Pass criteria: độ dài bit = 65535 chu kỳ, không tràn bộ đếm.

### C-03 Giữ rx ở mức 0 (break)
Source: SPEC §9.1, §9.4 | Trace: REQ-RX-04 | Spec ID: 3.3.2.1 | Priority: 2 | Check: Scoreboard
Precondition: RX rảnh, `CFG=0x03`, BAUD=0x900D, `rx_done=0`.

| Step | Input | Expected output |
|---|---|---|
| 1 | `rx=0` liên tục 6510 chu kỳ (30 bit) | Đúng 1 khung: `rx_done=1`, `R 010 → 0x00000043` (tx_done, rx_done, frame_err); `R 004 → 0x00000000` |
| 2 | Trong khi `rx` vẫn 0 (sau khi đọc RXDATA) | Không có khung mới (không có cạnh xuống mới): `rx_busy=0`, `rx_done=0`, `overrun=0` |
| 3 | `rx=1` ít nhất 2 bit; peer gửi 0x55 hợp lệ | `rx_done=1`, `R 004 → 0x55`, mọi cờ lỗi 0 |

Pass criteria: break tạo đúng 1 khung lỗi, không sinh chuỗi khung vô hạn; phục hồi nhận bình thường.

### C-04 Reset cứng giữa khung RX
Source: SPEC §12.1 | Trace: REQ-IO-02, REQ-IO-03 | Spec ID: 1.2.2, 2.6.1 | Priority: 2 | Check: Scoreboard
Precondition: `CFG=0x1B`, BAUD=0x900D. Peer đang gửi 0x5A (8E1), đã qua bit thứ 4 (`rx_busy=1`); TX đang phát giữa khung.

| Step | Input | Expected output |
|---|---|---|
| 1 | Hạ `presetn=0` giữa hai sườn pclk; peer giữ `rx=1` từ lúc đó | `tx=1`, `rts_n=1`, `irq=0` trước sườn pclk kế |
| 2 | Giữ 3 chu kỳ rồi nhả `presetn=1`; sau 2 chu kỳ `R 010` | `STAT=0x00000001` (`rx_busy=0`, `rx_done=0`); `rts_n=0`; `tx=1` |
| 3 | Đợi 2600 chu kỳ | Không có `rx_done` từ khung bị hủy; không có khung trên `tx` |
| 4 | Peer gửi 0x5A hợp lệ với CFG mặc định sau reset (`CFG=0x00`; ghi `CFG=0x1B`, peer gửi 8E1) | Nhận đúng `0x5A`, mọi cờ lỗi 0 |

Pass criteria: reset cứng hủy cả khung TX và RX; thiết bị nhận lại bình thường.

### C-05 Reset mềm khi đang chờ cts_n
Source: SPEC §12.2 | Trace: REQ-SRST-03, REQ-SRST-08, REQ-ERR-12 | Spec ID: 2.7.1.2, 2.7.3 | Priority: 1 | Check: Scoreboard
Precondition: `CFG=0x03`, `TXDATA=0x41`, `cts_n=1`, đã `W 00C 0001 0x1` (`tx_done=0`, `tx=1`). ASSUMPTION: soft reset xóa cả TXDATA (REQ-SRST-02, quyết định nhóm 11/11, HD §12 chỉ nêu CFG, BAUD, IER).

| Step | Input | Expected output |
|---|---|---|
| 1 | `W 00C 0010 0x00000100` (soft_rst) | `pslverr=0` |
| 2 | Sau 2 chu kỳ: `R 010`, `R 000` | `STAT=0x00000001` (`tx_done=1`), `TXDATA=0x00000000` |
| 3 | Hạ `cts_n=0`, quan sát 2300 chu kỳ | `tx=1` suốt: không có khung nào (lệnh phát bị hủy) |

Pass criteria: lệnh phát đang chờ cts_n bị hủy hoàn toàn bởi soft reset.

### C-06 start_tx và cts_n=0 xảy ra cùng sườn (race)
Source: SPEC §8.1 | Trace: REQ-TX-08, REQ-IO-04 | Spec ID: 2.9.3.1, 1.2.3 | Priority: 2 | Check: Scoreboard
Precondition: `CFG=0x03`, BAUD=0x900D, `TXDATA=0x55`, `cts_n=1`.

| Step | Input | Expected output |
|---|---|---|
| 1 | Hạ `cts_n=0` đúng tại sườn pclk kết thúc pha access của `W 00C 0001 0x1` | `pslverr=0`; chu kỳ kế `tx_done=0` |
| 2 | Quan sát `tx` | Đúng 1 khung `0 1 0 1 0 1 0 1 0 1`; start bit không sớm hơn 2 chu kỳ sau khi `cts_n` hạ; không mất lệnh, không khung đôi |
| 3 | Lặp với `cts_n` hạ lệch −2…+2 chu kỳ so với sườn trên | Luôn đúng 1 khung |

Pass criteria: không mất `start_tx`, không phát hai khung.

### C-07 parity_err và frame_err trong cùng một khung
Source: SPEC §9.4 | Trace: REQ-RX-08 | Spec ID: 3.3.1, 3.3.2.1, 2.10.3.2 | Priority: 2 | Check: Scoreboard
Precondition: `CFG=0x0B` (8O1), BAUD=0x900D, `IER=0x04`.

| Step | Input | Expected output |
|---|---|---|
| 1 | Peer gửi 0xA5 với parity **sai** và stop = 0 | `rx_done=1`; `R 010 → 0x00000047` (tx_done, rx_done, parity_err, frame_err); `irq=1` |
| 2 | `R 004` | `prdata=0x000000A5` |
| 3 | `R 010` | `0x00000001`; `irq=0` (một lần đọc xóa cả hai cờ) |

Pass criteria: hai cờ lỗi đặt đồng thời, cùng xóa bởi một lần đọc RXDATA.

### C-08 Lệnh ghi lỗi khi cả TX và RX đều bận
Source: SPEC §5.2 | Trace: REQ-ERR (E1, E2), REQ-ERR-06 | Spec ID: 3.1.1.1, 3.1.2 | Priority: 2 | Check: Scoreboard
Precondition: `tx_done=0` (đang phát 0x41) và `rx_busy=1` (peer đang gửi 0x5A); `CFG=0x03`, `BAUD=0x900D`, `IER=0x00`.

| Step | Input | Expected output |
|---|---|---|
| 1 | `W 010 1111 0xFFFFFFFF`; `W 004 1111 0x0` | `pslverr=1` (E2) cả hai |
| 2 | `W 01C 1111 0x00000001`; `W 0FC 0001 0x1`; `W 009 1111 0x3` | `pslverr=1` (E1) cả ba |
| 3 | Sau khi cả hai khung xong: đọc 7 thanh ghi | `TXDATA=0x41`, `RXDATA=0x5A`, `CFG=0x03`, `BAUD=0x900D`, `IER=0`, `STAT=0x00000003`; hai khung hoàn tất đúng, không khung phụ |

Pass criteria: lệnh lỗi khi bận không làm hỏng khung đang chạy và không đổi thanh ghi.

### C-09 Khung dài nhất (8E2) nối liền, bên phát lệch ±2 %
Source: SPEC §9.2, §9.1 | Trace: REQ-RX-13 | Spec ID: 4.3.1 | Priority: 2 | Check: Scoreboard
Precondition: `CFG=0x1F` (8E2, n=12), BAUD=0x900D (T = 217 chu kỳ).

| Step | Input | Expected output |
|---|---|---|
| 1 | Peer nhanh `+2 %` (bit time 212,75 chu kỳ), gửi liên tiếp 20 khung 8E2 với data `0x00…0x13`, mỗi khung start kế sau `12 × 212,75 = 2553` chu kỳ từ start trước; host đọc RXDATA trong vòng 2500 chu kỳ sau mỗi `rx_done` | Mẫu stop cuối ở `11,5 × 217 = 2495,5` chu kỳ nằm trong stop bit cuối của bên phát (`[2340,3 ; 2553,0)`); 20 byte đúng thứ tự, `frame_err=0`, `parity_err=0`, `overrun=0` |
| 2 | Lặp với peer chậm `−2 %` (bit time 221,43 chu kỳ; start kế sau 2657 chu kỳ) | Như bước 1 |

Pass criteria: 20/20 byte đúng ở cả hai hướng lệch.

### C-10 Ghi IER theo lane và bit rfu
Source: SPEC §4.7 | Trace: REQ-REG-04, REQ-IRQ-01 | Spec ID: 2.1.1.4, 2.5.1 | Priority: 2 | Check: Scoreboard
Precondition: TX, RX rảnh, `IER=0x02`, `tx_done=1`, `rx_done=0` (`irq=0`).

| Step | Input | Expected output |
|---|---|---|
| 1 | `W 018 0010 0x00000700` (chỉ lane 1) | `pslverr=0`; `R 018 → 0x00000002`; `irq=0` |
| 2 | `W 018 1110 0xFFFFFFFF` (không chạm lane 0) | `pslverr=0`; `R 018 → 0x00000002` |
| 3 | `W 018 0001 0xFFFFFFF8` (bit 2:0 = 0, các bit rfu = 1) | `R 018 → 0x00000000`; `irq=0` |
| 4 | `W 018 0001 0x000000FF` | `R 018 → 0x00000007`; `irq=1` (tx_done=1 và tx_done_ie=1) |

Pass criteria: chỉ `IER[2:0]` ghi được, chỉ qua lane 0; bit rfu không ảnh hưởng `irq`.

### C-11 Bật IER khi cờ đã được đặt
Source: SPEC §11 | Trace: REQ-IRQ-01, REQ-IRQ-06 | Spec ID: 2.12.1.1 | Priority: 2 | Check: Scoreboard, SVA
Precondition: `CFG=0x0B` (8O1), `IER=0x00`; peer đã gửi 0x41 với parity sai (`rx_done=1`, `parity_err=1`, `tx_done=1`); `irq=0`.

| Step | Input | Expected output |
|---|---|---|
| 1 | `W 018 0001 0x02` | `irq=1` trong ≤ 2 chu kỳ pclk |
| 2 | `W 018 0001 0x04` | `irq=1` (nguồn lỗi) |
| 3 | `W 018 0001 0x01` | `irq=1` (tx_done=1) |
| 4 | `W 018 0001 0x00` | `irq=0` trong ≤ 2 chu kỳ pclk dù các cờ vẫn set |
| 5 | `W 018 0001 0x06`, rồi `R 004` | `irq=1`, sau `R 004` → `irq=0` (cả rx_done và lỗi cùng xóa) |

Pass criteria: `irq` theo đúng công thức ngay khi IER đổi, cả khi bật và tắt.

### C-12 start_tx đúng quanh thời điểm tx_done lên 1
Source: SPEC §8.1, §5.2 | Trace: REQ-TX-05, REQ-TX-11 | Spec ID: 2.9.2.1, 3.1.3.1 | Priority: 2 | Check: Scoreboard, SVA
Precondition: `CFG=0x03`, BAUD=0x900D, cts_n=0, `TXDATA=0x41`; một khung đang phát, thời điểm `tx_done` lên 1 là `t_d` (biết trước từ mô hình).

| Step | Input | Expected output |
|---|---|---|
| 1 | Với `k = −3…+3`: đặt chu kỳ access của `W 00C 0001 0x1` tại `t_d + k` chu kỳ | Bất biến cho mọi k: `pslverr = (tx_done == 0 tại chu kỳ access)` |
| 2 | Đếm khung trên `tx` sau mỗi lần | `pslverr=0` → đúng 1 khung mới được phát; `pslverr=1` → không có khung phụ |

Pass criteria: không có trường hợp `pslverr=0` mà không có khung, hoặc `pslverr=1` mà vẫn có khung phụ.

### C-13 Ghi BAUD = 0 khi đang bận (E4 và E5 cùng lúc)
Source: SPEC §5.2 | Trace: REQ-ERR (E4, E5) | Spec ID: 3.1.4.2, 3.1.5 | Priority: 2 | Check: Scoreboard
Precondition: `BAUD=0x900D`, `CFG=0x03`.

| Step | Input | Expected output |
|---|---|---|
| 1 | `tx_done=0` (đang phát): `W 014 0011 0x00000000` | `pslverr=1`; `R 014 → 0x0000900D` |
| 2 | `rx_busy=1` (peer đang gửi): `W 014 0011 0x00000000` | `pslverr=1`; BAUD không đổi |
| 3 | Rảnh: `W 014 0011 0x00000000` | `pslverr=1`; BAUD không đổi (chỉ E5) |

Pass criteria: một mã lỗi chồng hai điều kiện vẫn cho đúng một `pslverr=1`, không đổi BAUD.

### C-14 CTRL: start_tx và soft_rst ghi theo từng lane
Source: SPEC §4.4, §12.2 | Trace: REQ-APB-06, REQ-SRST-09 | Spec ID: 1.1.2.1, 2.3.2.1, 3.1.3.2 | Priority: 2 | Check: Scoreboard
Precondition: TX rảnh, cts_n=0, `CFG=0x1B`, `BAUD=0xB028`, `IER=0x01`, `TXDATA=0x41`.

| Step | Input | Expected output |
|---|---|---|
| 1 | `W 00C 0001 0x00000101` (chỉ lane 0: start_tx=1, bit 8 không được ghi) | `pslverr=0`; chạy 1 khung 0x41 8E1; `CFG`, `BAUD`, `IER` không đổi (không soft reset) |
| 2 | Khi `tx_done=0`: `W 00C 0001 0x00000101` | `pslverr=1` (E3: pstrb[0]=1, pwdata[0]=1, soft_rst không được ghi); không khung phụ |
| 3 | Chờ `tx_done=1`: `W 00C 0010 0x00000101` (chỉ lane 1: soft_rst=1, bit 0 không được ghi) | `pslverr=0`; reset mềm: `CFG=0`, `BAUD=0x900D`, `IER=0`; **không** có khung (start_tx bị bỏ qua) |

Pass criteria: lane 0 chỉ chạm `start_tx`, lane 1 chỉ chạm `soft_rst`.

### C-15 rts_n theo tổ hợp rx_dis và rx_done
Source: SPEC §10 | Trace: REQ-FC-01..03 | Spec ID: 2.11.1.1, 2.11.1.2, 2.11.1.3 | Priority: 2 | Check: SVA, Scoreboard
Precondition: `CFG=0x03`, BAUD=0x900D. Công thức: `rts_n = rx_dis \| rx_done`.

| Step | Input | Expected output |
|---|---|---|
| 1 | `rx_dis=0`, `rx_done=0` | `rts_n=0` |
| 2 | Peer gửi 0x5A: `rx_dis=0`, `rx_done=1` | `rts_n=1` |
| 3 | `W 008 0001 0x43` (`rx_dis=1`) khi `rx_done=1` (`tx_done=1`, `rx_busy=0` nên không E4) | `pslverr=0`; `rts_n=1` |
| 4 | `W 008 0001 0x03` (`rx_dis=0`) khi `rx_done` vẫn 1 | `rts_n=1` (vẫn đầy) |
| 5 | `R 004` | `rx_done=0`, `rts_n=0` |
| 6 | `W 008 0001 0x43` khi `rx_done=0` | `rts_n=1` (`rx_dis=1`, `rx_done=0`) |

Pass criteria: `rts_n` khớp 4 tổ hợp: (0,0) → 0; (0,1) → 1; (1,0) → 1; (1,1) → 1.


---

# Phần 4. Ma trận trace

Tổng: 20 test H, 51 test T, 15 test C = 86 test. Mọi Spec ID của sheet Veri_spec (115 mục) đều có ít nhất một test.

## 4.1 Spec ID → REQ → Test

| Spec ID | REQ | Test |
|---|---|---|
| 1.1.1.1 | REQ-APB-01, REQ-GEN-06 | H-08, T-1.1.1.1 |
| 1.1.1.2 | REQ-APB-02, REQ-GEN-06 | H-08, T-1.1.1.1 |
| 1.1.1.3 | REQ-APB-03, REQ-GEN-06 | H-08, T-1.1.1.3 |
| 1.1.1.4 | REQ-APB-04, REQ-GEN-06 | H-02, H-08, T-1.1.1.3 |
| 1.1.1.5 | REQ-APB-05, REQ-GEN-06 | T-1.1.1.5 |
| 1.1.2.1 | REQ-APB-06, REQ-GEN-06 | T-1.1.2.1, C-14 |
| 1.1.2.2 | REQ-APB-07, REQ-GEN-06 | T-1.1.2.1 |
| 1.1.3.1 | REQ-APB-04, REQ-GEN-06 | H-08, T-1.1.1.1 |
| 1.2.1 | REQ-IO-01 | H-01, T-1.2.1 |
| 1.2.2 | REQ-FC-05, REQ-GEN-02, REQ-IO-02 | H-01, T-1.2.2, C-04 |
| 1.2.3 | REQ-IO-04 | T-2.9.3.1, C-06 |
| 1.3.1 | REQ-TT-01, REQ-TT-02 | H-20, T-1.3.1 |
| 1.3.2 | REQ-TT-01 | H-20, T-1.3.1 |
| 1.3.2.2 | REQ-TT-01, REQ-TT-03 | H-20, T-1.3.1 |
| 2.1.1.1 | REQ-REG-01 | H-02, T-2.1.1.1 |
| 2.1.1.2 | REQ-REG-02 | H-02, T-2.1.1.2 |
| 2.1.1.3 | REQ-REG-03 | T-2.1.1.1 |
| 2.1.1.4 | REQ-REG-04 | T-2.1.1.4, C-10 |
| 2.2.1.1 | REQ-GEN-03, REQ-FRM-05 | H-05, T-2.2.1.1 |
| 2.2.1.2 | REQ-GEN-03, REQ-FRM-05 | H-05, T-2.2.1.1 |
| 2.2.1.3 | REQ-GEN-03, REQ-FRM-05 | H-05, T-2.2.1.1 |
| 2.2.1.4 | REQ-GEN-03, REQ-FRM-05 | H-05, T-2.2.1.1 |
| 2.2.2.1 | REQ-TX-10 | T-2.2.2.1 |
| 2.2.2.2 | REQ-RX-14 | T-2.2.2.2 |
| 2.3.1.1 | REQ-TX-01 | T-2.3.1.1 |
| 2.3.1.2 | REQ-TX-02 | T-2.3.1.1 |
| 2.3.1.3 | REQ-TX-03 | T-2.3.1.1 |
| 2.3.2.1 | REQ-SRST-01 | H-19, T-2.3.2.1, C-14 |
| 2.4.1.1 | REQ-TX-04 | H-16, T-2.4.1.1 |
| 2.4.2.1 | REQ-RX-07 | H-17, T-2.4.2.1 |
| 2.4.2.2 | REQ-RX-07 | H-17, T-2.4.2.1 |
| 2.4.3.1 | REQ-REG-05 | T-2.4.3.1 |
| 2.4.4.1 | REQ-REG-06 | T-3.3.1 |
| 2.4.4.2 | REQ-REG-06 | T-3.3.2.1 |
| 2.4.4.3 | REQ-REG-06 | T-3.3.3 |
| 2.5.1 | REQ-IRQ-01 | H-18, T-2.5.1, C-10 |
| 2.6.1 | REQ-GEN-02, REQ-IO-03 | T-1.2.2, C-04 |
| 2.7.1.1 | REQ-SRST-02 | H-19, T-2.3.2.1 |
| 2.7.1.2 | REQ-SRST-03 | H-19, T-2.7.1.2, C-05 |
| 2.7.1.3 | REQ-SRST-04 | H-19, T-2.7.1.2 |
| 2.7.1.4 | REQ-FC-05, REQ-SRST-05 | H-19, T-2.7.1.2 |
| 2.7.2.1 | REQ-SRST-06 | H-19, T-2.3.2.1 |
| 2.7.2.2 | REQ-SRST-07 | H-19, T-2.3.2.1 |
| 2.7.3 | REQ-ERR-11, REQ-SRST-08 | H-19, T-2.7.1.2, C-05 |
| 2.8.1.1 | REQ-BAUD-01, REQ-GEN-01 | H-04, T-2.8.1.1, C-01, C-02 |
| 2.8.1.2 | REQ-BAUD-02, REQ-GEN-01 | H-03, T-2.8.1.1 |
| 2.8.2.1 | REQ-BAUD-03, REQ-GEN-01, REQ-GEN-04 | H-03, T-2.8.2.1 |
| 2.8.2.2 | REQ-BAUD-04, REQ-GEN-01, REQ-GEN-04 | H-03, T-2.8.2.2 |
| 2.9.1.1 | REQ-FRM-01 | H-05, H-16, T-2.2.1.1 |
| 2.9.1.2 | REQ-FRM-02 | T-2.9.1.2 |
| 2.9.1.3 | REQ-FRM-03 | H-05, T-2.9.1.3 |
| 2.9.1.4 | REQ-FRM-04 | H-05, T-2.2.1.1 |
| 2.9.1.5 | REQ-FRM-05, REQ-GEN-03 | H-05, T-2.2.1.1 |
| 2.9.1.6 | REQ-FRM-02 | T-2.9.1.2 |
| 2.9.2.1 | REQ-TX-05 | H-16, T-2.4.1.1, C-12 |
| 2.9.2.2 | REQ-TX-06 | H-16, T-2.4.1.1 |
| 2.9.2.3 | REQ-TX-07 | T-2.3.1.1 |
| 2.9.3.1 | REQ-FC-04, REQ-TX-08 | H-16, T-2.9.3.1, C-06 |
| 2.10.1.1 | REQ-FRM-05, REQ-GEN-03, REQ-RX-01 | H-05, T-2.10.1.1 |
| 2.10.1.2 | REQ-RX-02 | H-05, T-2.10.1.1 |
| 2.10.1.3 | REQ-RX-03 | H-05, T-2.10.1.1 |
| 2.10.2.1 | REQ-RX-04 | H-17, T-2.4.2.1 |
| 2.10.2.2 | REQ-RX-05 | T-2.10.2.2 |
| 2.10.3.1 | REQ-RX-06 | H-07, H-17, T-2.4.2.1 |
| 2.10.3.2 | REQ-RX-08 | T-2.10.3.2, C-07 |
| 2.10.3.3 | REQ-RX-09 | T-2.10.3.2 |
| 2.10.3.4 | REQ-RX-10 | T-2.10.3.2 |
| 2.10.4.1 | REQ-RX-11 | H-06, T-2.10.4.1 |
| 2.10.4.2 | REQ-RX-12 | T-2.10.4.2 |
| 2.11.1.1 | REQ-FC-01 | H-17, T-2.11.1.1, C-15 |
| 2.11.1.2 | REQ-FC-02 | H-17, T-2.11.1.1, C-15 |
| 2.11.1.3 | REQ-FC-03 | T-2.2.2.2, C-15 |
| 2.12.1.1 | REQ-IRQ-01 | H-18, T-2.5.1, C-11 |
| 2.12.1.2 | REQ-IRQ-02 | H-18, T-2.5.1 |
| 2.12.1.3 | REQ-IRQ-03 | H-18, T-2.5.1 |
| 2.12.2.1 | REQ-IRQ-04 | H-18, T-2.12.2.1 |
| 2.12.2.2 | REQ-IRQ-05 | H-18, T-2.12.2.1 |
| 2.12.3.1 | REQ-IRQ-06 | H-18, T-2.12.3.1 |
| 2.12.3.2 | REQ-IRQ-07 | H-18, T-2.12.3.1 |
| 2.13.1.1 | REQ-SPI-01 | H-10, T-2.13.1.1 |
| 2.13.1.2 | REQ-SPI-02 | H-10, T-2.13.1.1 |
| 2.13.1.3 | REQ-SPI-03 | H-10, T-2.13.1.1 |
| 2.13.1.4 | REQ-SPI-04 | H-10, T-2.13.1.1 |
| 2.13.1.5 | REQ-SPI-04 | H-10, T-2.13.1.1 |
| 2.13.2.1 | REQ-SPI-05 | H-10, T-2.13.1.1 |
| 2.13.2.2 | REQ-SPI-06 | H-11, T-2.13.2.2 |
| 2.13.3.1 | REQ-SPI-07 | H-12, T-2.13.3.1 |
| 2.13.3.2 | REQ-SPI-08 | H-12, T-2.13.3.1 |
| 2.13.4.1 | REQ-SPI-09 | H-13, T-2.13.4.1 |
| 2.13.4.2 | REQ-SPI-10 | H-13, T-2.13.4.1 |
| 2.14.1.1 | SPEC §14.1 | H-14, T-2.14.1.1 |
| 2.14.1.2 | SPEC §14.2 | H-15, T-2.14.1.2 |
| 3.1.1.1 | REQ-GEN-06 | H-09, T-3.1.1.1, C-08 |
| 3.1.1.2 | REQ-GEN-06 | H-09, T-3.1.1.1 |
| 3.1.2 | REQ-GEN-06 | H-09, T-3.1.2, C-08 |
| 3.1.3.1 | REQ-GEN-06, REQ-TX-11 | H-09, T-3.1.3.1, C-12 |
| 3.1.3.2 | REQ-GEN-06, REQ-TX-11 | H-09, T-3.1.3.1, C-14 |
| 3.1.4.1 | REQ-GEN-06 | H-09, T-3.1.4.1 |
| 3.1.4.2 | REQ-GEN-06 | H-09, T-3.1.4.1, C-13 |
| 3.1.4.3 | REQ-ERR-12, REQ-GEN-06 | T-3.1.4.1 |
| 3.1.5 | REQ-BAUD-06, REQ-GEN-06 | H-09, T-3.1.5, C-01, C-13 |
| 3.1.6 | REQ-GEN-06 | H-09, T-3.1.3.1 |
| 3.2.1.1 | REQ-ERR-07 | H-09, T-3.2.1.1 |
| 3.2.1.2 | REQ-ERR-08 | H-09, T-3.2.1.1 |
| 3.2.1.3 | REQ-ERR-09 | H-09, T-3.2.1.1 |
| 3.2.1.4 | REQ-ERR-10 | H-09, T-3.2.1.1 |
| 3.3.1 | SPEC §9.4 | T-3.3.1, C-07 |
| 3.3.2.1 | SPEC §9.4 | H-07, T-3.3.2.1, C-03, C-07 |
| 3.3.2.2 | SPEC §9.4 | H-07, T-3.3.2.1 |
| 3.3.3 | SPEC §9.4 | T-3.3.3 |
| 4.1.1.1 | REQ-ERR-11, REQ-SRST-09 | H-19, T-4.1.1.1 |
| 4.1.1.2 | REQ-ERR-11, REQ-SRST-09 | H-19, T-4.1.1.1 |
| 4.2.1 | REQ-FC-04, REQ-TX-09 | H-16, T-2.9.3.1 |
| 4.3.1 | REQ-RX-13 | H-07, T-4.3.1, C-09 |
| 4.4.1 | REQ-BAUD-05 | H-03, T-2.8.2.2 |

## 4.2 REQ không có Spec ID trong XLSX

| REQ | Cách kiểm | Ghi chú |
|---|---|---|
| REQ-GEN-05 | T-3.3.3, T-2.10.3.2 | Đệm 1 ký tự, không FIFO: kiểm qua overrun và đọc RXDATA |
| REQ-RTL-01 | lint / netlist | Kiểm bằng lint/Yosys/netlist ở cổng G2, G4 (không phải test mô phỏng) |
| REQ-RTL-02 | lint / netlist | Kiểm bằng lint/Yosys/netlist ở cổng G2, G4 (không phải test mô phỏng) |
| REQ-RTL-03 | lint / netlist | Kiểm bằng lint/Yosys/netlist ở cổng G2, G4 (không phải test mô phỏng) |
| REQ-RTL-04 | T-2.9.3.1 | Bước 5 của T-2.9.3.1; kiểm trên netlist ở cổng G2, G4 |
| REQ-RTL-05 | lint / netlist | Kiểm bằng lint/Yosys/netlist ở cổng G2, G4 (không phải test mô phỏng) |
| REQ-RTL-06 | lint / netlist | Kiểm bằng lint/Yosys/netlist ở cổng G2, G4 (không phải test mô phỏng) |
| REQ-SPI-11 | H-10 | Kiểm thêm trên RTL/netlist: spi_cs_n, spi_sclk, spi_mosi qua 2 FF; SCLK không dùng làm clock |

---

# Phần 5. Yêu cầu môi trường kiểm chứng

## 5.1 Phạm vi và nguyên tắc

Phần này là yêu cầu **bắt buộc** khi viết testbench cho các test ở Phần 1–3. Testplan không chứa code; phần này chỉ nêu testbench phải có gì và phải kiểm gì. Một môi trường chỉ có stimulus và xem waveform không được coi là đạt.

- **Tự kiểm tra.** Kết luận PASS/FAIL do checker tự động đưa ra (scoreboard, SVA). Không soi waveform bằng mắt để kết luận PASS.
- **Mỗi test có checker.** Mỗi test ở Phần 1–3 phải được ít nhất một điểm so sánh `SB-NN` hoặc một thuộc tính `A-NN` phán quyết, và đóng góp vào ít nhất một covergroup `CG-NN`. Ngoại lệ: H-01 và H-20 chủ yếu kiểm tĩnh (elaboration, kết nối chân) nên chỉ cần SVA.
- **Chỉ chạm cổng.** Testbench chỉ truy cập `apb_uart` qua cổng (REQ-RTL-06). Ở mức này `tx_done`, `rx_done`, `rx_busy` chỉ lấy được từ mô hình tham chiếu hoặc từ `R 010`. Ở mức `apb_uart_core` có thêm cổng `stat_tx_done`, `stat_rx_done`, `stat_parity_err`. Ở mức chip có `uo_out[3]` (tx_done), `uo_out[4]` (rx_done), `uo_out[5]` (parity_err). `rx_busy`, `frame_err`, `overrun` không có ở chân nào.
- **Một bộ test cho mọi mức.** Các test mức khối chạy được trên RTL và netlist Yosys; các test mức chip chạy được trên GLS có SDF (mục 5.7).
- **Đủ bốn loại kiểm.** SVA (5.5), scoreboard (5.4), code coverage và functional coverage (5.6) đều phải có; thiếu một loại là chưa hoàn chỉnh.

## 5.2 Các mức DUT

Cổng và phân cấp module: `TB_GUIDE.md` (TBG) §2–§4.

| Mức | DUT | Mục đích |
|---|---|---|
| Unit | `sync_2ff`, `baud_gen`, `uart_tx`, `uart_rx` | Đã có unit test đạt (TBG). Giữ trong regression. `baud_gen` có cổng `tick`: kiểm khoảng cách tick của H-04 bước 3 và C-02 ở đây |
| Unit | `uart_regs` | **Chưa mô phỏng lần nào** (TBG). Kiểm thanh ghi, `pslverr` E1–E5, cờ, `irq`, `rts_n`; các cờ, `rx_dis`, `rx_done` đều là cổng nên A-06, A-07 gắn ở đây |
| Unit | `spi2apb` | **Chưa mô phỏng lần nào** (TBG). Tín hiệu APB là cổng: kiểm thời điểm giao dịch APB (sau sườn lên SCLK thứ 8 hoặc 48) ở đây |
| Lõi | `apb_uart_core` | Cổng như `apb_uart` cộng `stat_tx_done`, `stat_rx_done`, `stat_parity_err`. Dùng cho các kiểm cần đúng từng chu kỳ: A-08, SB-06, SB-11, C-12, T-2.10.3.2 bước 5 |
| Khối | `apb_uart` (top 1, 16 cổng) | Chạy toàn bộ `H-`, `T-`, `C-` trừ các test wrapper. Đây là mức ban chấm nối testbench |
| Chip | `tt_um_hust_apb_uart` (top 2) | Chạy H-10…H-15, H-20, T-1.3.1 qua SPI và chân `ui_in`/`uo_out` |

`apb_uart_core`, `apb_uart` và `tt_um_hust_apb_uart` cũng mới chỉ qua lint, chưa mô phỏng (TBG, ngày 2026-11-13).

## 5.3 Thành phần testbench bắt buộc

| Thành phần | Trách nhiệm | Phải hỗ trợ |
|---|---|---|
| APB master BFM | Phát giao dịch setup + access | `pstrb` tùy ý; địa chỉ bất kỳ 12 bit; đặt pha access vào đúng chu kỳ chỉ định (C-06, C-12, T-2.10.3.2 bước 5); lái `psel=0` trong khi các tín hiệu khác đổi (T-1.1.1.5) |
| APB monitor | Ghi lại mọi giao dịch | `paddr`, `pwrite`, `pstrb`, `pwdata`, `prdata`, `pslverr`; cấp cho scoreboard và coverage |
| UART peer phát (lái `rx`) | Gửi khung vào DUT | 24 dạng khung; bit time thực (lệch ±2 %, ±3 %); chèn lỗi parity; stop = 0 cho từng stop; break; glitch theo số chu kỳ; khung nối liền |
| UART peer thu (đọc `tx`) | Giải mã khung DUT phát | Đo độ dài từng bit theo chu kỳ `pclk`; giải mã data, parity, stop; đếm số khung |
| Bộ lái `cts_n`, monitor `rts_n` và `irq` | Flow control và ngắt | Đổi `cts_n` không đồng bộ với `pclk`; ghi thời điểm đổi của `rts_n`, `irq` |
| SPI master BFM (mức chip và unit `spi2apb`) | Phát khung SPI | Mode 0, 56 bit, `f_SCLK = f_pclk/10`; hủy khung ở bit chỉ định; ghi lại MISO và sườn SCLK tại lúc MISO đổi |
| APB slave giả (unit `spi2apb`) | Trả `prdata`, `pready`, `pslverr` | Giá trị đặt trước cho từng địa chỉ; ghi lại thời điểm giao dịch |
| Bộ lái cờ (unit `uart_regs`) | Lái `tx_done`, `rx_busy`, `rx_valid`, `rx_data`, `rx_perr`, `rx_ferr` | Đặt cờ đúng chu kỳ chỉ định, kể cả trùng chu kỳ access |
| Bộ tạo clock và reset | `pclk`, `presetn` | `pclk` 25 MHz; hạ `presetn` không đồng bộ, giữa hai sườn `pclk` |
| Mô hình tham chiếu + scoreboard | Dự đoán và so sánh | Mục 5.4 |
| SVA | Kiểm giao thức và bất biến | Mục 5.5 |
| Bộ thu coverage | Functional và code coverage | Mục 5.6 |
| Điều khiển test | Chạy và báo kết quả | Tên test trùng cột "Test name" của XLSX; timeout cho mỗi test; một dòng PASS/FAIL mỗi test; seed ghi vào log |

## 5.4 Scoreboard và mô hình tham chiếu

Mô hình tham chiếu tự dự đoán kết quả từ stimulus; ở mức khối nó **không** đọc tín hiệu nội bộ của DUT.

- **Sự kiện thừa.** Scoreboard báo lỗi cả khi có sự kiện không dự đoán (khung lạ trên `tx`, `irq` lên), không chỉ khi thiếu.
- **Cuối test.** Mọi hàng đợi của scoreboard phải rỗng; còn phần tử chờ là FAIL.
- **Cửa sổ mơ hồ.** SPEC chỉ cho cận trên của vài thời điểm (`tx_done` lên ≤ 2 chu kỳ, `rx_done` ≤ 1 bit, `rx_busy` sau 2 FF đồng bộ). Khi một lệnh APB rơi vào cửa sổ đó (C-12, T-2.10.3.2 bước 5), scoreboard chấp nhận cả hai giá trị `pslverr` nhưng bắt buộc nhất quán: `pslverr=0` thì lệnh có tác dụng, `pslverr=1` thì không. Muốn kiểm đúng từng chu kỳ thì chạy ở mức `apb_uart_core`.
- **Kiểm cần tín hiệu nội bộ.** H-08 bước 4 (thanh ghi đổi ở sườn nào), H-04 bước 3 và C-02 (khoảng cách tick), thời điểm APB của SPI: thực hiện ở mức unit (`uart_regs`, `baud_gen`, `spi2apb`), chỉ trên RTL.

| ID | Điểm so sánh | Dự đoán từ / quan sát qua | Spec ID | Test |
|---|---|---|---|---|
| SB-01 | `prdata` của mọi lần đọc: 7 thanh ghi, bit rfu = 0, CTRL đọc 0 | Mô hình thanh ghi | 2.1.1.2, 2.1.1.3, 2.1.1.4 | H-02, T-1.1.1.5, T-1.1.2.1, T-2.1.1.1, T-2.1.1.4, T-2.4.3.1, C-10 |
| SB-02 | `pslverr` của mọi giao dịch, xét theo thứ tự E1 → E5 (TBG §5) | Mô hình thanh ghi + trạng thái TX/RX (có cửa sổ mơ hồ, xem dưới bảng) | 3.1.1.1, 3.1.2, 3.1.3.1, 3.1.4.1, 3.1.5, 3.2.1.4 | H-09, T-3.1.1.1, T-3.1.2, T-3.1.4.1, T-3.1.5, T-3.2.1.1, C-01, C-08, C-12, C-13 |
| SB-03 | Sau lệnh có `pslverr=1`: không thanh ghi nào đổi, không có hành động | Mô hình thanh ghi | 3.1.6 | H-09, T-3.1.1.1, T-3.1.2, T-3.1.4.1, T-3.1.5, C-08, C-13 |
| SB-04 | Khung trên `tx`: chuỗi bit, parity, số stop, độ dài mỗi bit `16·div_int + div_frac` chu kỳ, số khung (kể cả "không có khung") | TXDATA, CFG, BAUD đã ghi | 2.9.1.1, 2.9.1.3, 2.8.1.1, 2.3.1.1 | H-03, H-04, H-05, H-16, T-2.2.2.1, T-2.3.1.1, T-2.9.1.2, T-2.9.1.3, C-01, C-02 |
| SB-05 | Byte nhận và các cờ `rx_done`, `parity_err`, `frame_err`, `overrun` (qua `R 010`, `R 004`) | Khung UART peer đã gửi | 2.10.1.1, 3.3.1, 3.3.2.1, 3.3.3 | H-03, H-05, H-06, H-07, T-2.10.2.2, T-2.10.3.2, T-2.10.4.2, T-3.3.1, T-3.3.2.1, T-3.3.3, C-03, C-07, C-09 |
| SB-06 | `tx_done` theo thời gian: xuống ở chu kỳ kế sau start_tx, lên ≤ 2 chu kỳ sau stop bit cuối | Mô hình TX; quan sát `stat_tx_done` ở mức `apb_uart_core`, `uo_out[3]` ở mức chip | 2.9.2.1, 2.9.2.2 | H-16, C-12 |
| SB-07 | `irq` theo công thức ngắt | IER và các cờ của mô hình | 2.12.1.1 | H-18, C-11 |
| SB-08 | `rts_n = rx_dis \| rx_done`, cho phép trễ ≤ 2 chu kỳ; bằng 1 trong reset cứng và trong 2 chu kỳ reset mềm | CFG và cờ `rx_done` của mô hình | 2.11.1.1, 2.11.1.2, 2.11.1.3 | H-17, T-2.2.2.2, C-15 |
| SB-09 | Reset mềm và reset cứng: giá trị thanh ghi sau reset, khung đang phát/nhận bị hủy, lệnh APB đúng từ chu kỳ thứ 3 | Mô hình thanh ghi + mô hình TX/RX | 2.7.1.1, 2.7.1.2, 2.7.1.3, 2.7.2.1, 2.6.1 | H-19, T-1.2.2, C-04, C-05, C-14 |
| SB-10 | SPI mức chip: 7 byte MISO của mỗi khung và tác dụng phụ lên thanh ghi. Thời điểm giao dịch APB (sau sườn lên SCLK thứ 8 hoặc 48) kiểm ở unit `spi2apb` | Khung MOSI + mô hình thanh ghi | 2.13.1.1, 2.13.2.1, 2.13.2.2, 2.13.3.1 | H-10, H-11, H-12, H-13, H-14, H-15 |
| SB-11 | Thời điểm RX: `rx_busy=1` sau khi kiểm lại start ở tick 8; `rx_done=1` trong ≤ 1 bit sau mẫu stop cuối, cùng lúc `rx_busy=0` | Mô hình RX; quan sát `stat_rx_done` ở mức `apb_uart_core`, `uo_out[4]` ở mức chip; `rx_busy` qua `R 010` hoặc cổng của unit `uart_rx` | 2.10.2.1, 2.10.3.1 | H-07, H-17 |
| SB-12 | SPI: MISO chỉ đổi ở sườn xuống SCLK; MOSI được lấy mẫu ở sườn lên | Khung SPI | 2.13.1.2 | H-10 |

## 5.5 SVA

Cột "Quan sát qua" cho biết thuộc tính gắn ở mức nào. Thuộc tính nào cũng phải có ít nhất một test làm tiền đề (antecedent) xảy ra. Bằng chứng là báo cáo cover của từng `A-NN`: assertion có số lần kích hoạt bằng 0 bị coi là chưa kiểm.

| ID | Thuộc tính | Quan sát qua | Spec ID | Test |
|---|---|---|---|---|
| A-01 | `psel && penable \|-> pready` | cổng `apb_uart` | 1.1.1.1 | H-08, T-1.1.1.1 |
| A-02 | `presetn \|-> pready` | cổng `apb_uart` | 1.1.1.2 | H-08, T-1.1.1.1 |
| A-03 | `pslverr \|-> psel && penable` | cổng `apb_uart` | 1.1.3.1 | H-08, T-1.1.1.1 |
| A-04 | Sau khi `presetn` hạ, trong một cửa sổ ổn định trước sườn `pclk` kế: `tx && rts_n && !irq && !pslverr && pready`. Độ rộng cửa sổ là tham số (GLS cần lớn hơn trễ lan truyền) | cổng `apb_uart` | 1.2.2, 2.6.1 | H-01, T-1.2.2, C-04 |
| A-05 | Sau reset không có X/Z trên `pready`, `pslverr`, `tx`, `rts_n`, `irq`, và trên `prdata` trong pha access | cổng `apb_uart` | 1.2.2 | H-01, T-1.2.2, C-04 |
| A-06 | `irq` bằng công thức ngắt trong ≤ 2 chu kỳ kể từ khi nguồn đổi, và giữ mức khi điều kiện còn | unit `uart_regs` (các cờ và `irq` là cổng). Mức khối chỉ kiểm trường hợp ghi IER | 2.12.1.2, 2.12.1.3 | H-18, C-11 |
| A-07 | `rts_n == (rx_dis \| rx_done)`, cho phép trễ ≤ 2 chu kỳ; không xét khi reset cứng và trong 2 chu kỳ reset mềm | unit `uart_regs` (cổng `rx_dis`, `rx_done`, `rts_n`). Mức khối do SB-08 kiểm | 2.11.1.1, 2.11.1.2, 2.11.1.3 | H-17, T-2.2.2.2, C-15 |
| A-08 | Sau khi lệnh start_tx được nhận, `tx_done=0` ở chu kỳ kế | `apb_uart_core` (`stat_tx_done`), hoặc unit `uart_regs` + `uart_tx` | 2.9.2.1 | H-16, C-12 |
| A-09 | `tx=1` trong suốt thời gian chờ `cts_n` | cổng `apb_uart` + mô hình tham chiếu | 2.9.3.1 | H-16, T-2.9.3.1, C-06 |
| A-10 | Khi đang chờ, `cts_n` hạ thì start bit trên `tx` không xuất hiện sớm hơn 2 chu kỳ `pclk`. Phía `rx`: kiểm bằng unit test `sync_2ff` và kiểm netlist (T-2.9.3.1 bước 5) | cổng `apb_uart` | 1.2.3 | T-2.9.3.1, C-06 |
| A-11 | `rts_n=1` trong 2 chu kỳ reset mềm | cổng `apb_uart` | 2.7.1.4 | H-19 |
| A-12 | Đọc `0x00C` luôn trả `prdata=0` | cổng `apb_uart` | 2.3.1.3, 2.7.2.2 | H-02, H-19, T-2.1.1.4, T-2.3.1.1 |
| A-13 | Bit rfu của `prdata` luôn 0 khi đọc 7 thanh ghi | cổng `apb_uart` | 2.1.1.4 | T-2.1.1.4, C-10 |
| A-14 | `spi_cs_n=1` liên tục ≥ 3 chu kỳ `pclk` thì `spi_miso=0` (`spi_cs_n` đi qua 2 FF đồng bộ) | chân wrapper | 2.13.1.4 | H-10 |
| A-15 | `uio_oe == 0`, `uio_out == 0`, `uo_out[7] == 0` | chân wrapper | 1.3.2.2 | H-20, T-1.3.1 |

## 5.6 Coverage

**5.6.1 Code coverage.** Công cụ: Questa `vcover`, gộp kết quả của mọi test trong regression. Phạm vi: mọi module trong `rtl/` (cả `spi2apb` và wrapper).

| Loại | Ngưỡng | Nguồn |
|---|---|---|
| Statement | ≥ 90 % | SPEC §15 (bắt buộc) |
| Branch | ≥ 90 % | SPEC §15 (bắt buộc) |
| FSM state | 100 % | Mục tiêu nhóm |
| FSM transition | 100 % các cung đạt được | Mục tiêu nhóm |
| Condition / expression | ≥ 90 % | Mục tiêu nhóm |
| Toggle trên cổng top | 100 % các bit có thể đổi | Mục tiêu nhóm |

Loại trừ cấu trúc của toggle (hằng theo đặc tả): `pready`, `prdata[31:16]`, `uio_out`, `uio_oe`, `uo_out[7]`. Mọi dòng loại trừ khác phải nằm trong một file waiver, kèm lý do và người duyệt. Không loại trừ để đạt ngưỡng.

**5.6.2 Functional coverage.** Ngưỡng: 100 % bin của bảng dưới (mục tiêu nhóm). Bin cộng điểm (3 baud cao, lệch ±3 %) báo riêng. Bin trong bảng đã được giới hạn ở các ô mà test có tên đánh trúng; tổ hợp rộng hơn do regression ngẫu nhiên phủ và không tính vào ngưỡng.

| ID | Covergroup | Bin bắt buộc | Spec ID | Test |
|---|---|---|---|---|
| CG-01 | Dạng khung | `data_bits` × parity {none, odd, even} × `stop_bits` = 24 bin; lấy riêng cho TX và cho RX | 2.9.1.5, 2.10.1.1 | H-05 |
| CG-02 | Baud | 10 giá trị BAUD của bảng H-03 × {TX, RX}; thêm bin TX cho `0x0001`, `0xFFFF`, `0x200E` | 2.8.2.1, 2.8.2.2, 2.8.1.1 | H-03, H-04, C-01, C-02 |
| CG-03 | Truy cập APB | 7 địa chỉ × {đọc, ghi}; lệnh ghi BAUD × `pstrb` ∈ {0000, 0001, 0010, 0011, 1100, 1111}; lệnh ghi thanh ghi khác × `pstrb` ∈ {0000, lane có field, lane không có field}; địa chỉ lỗi ∈ {ngoài bảng, không căn 4 byte} × {đọc, ghi}; `psel=0` | 2.1.1.1, 1.1.2.1, 1.1.2.2, 3.1.1.1, 3.1.1.2, 1.1.1.5 | H-02, H-08, H-09, T-1.1.1.1, T-1.1.1.5, T-1.1.2.1, T-2.1.1.1, T-2.1.1.4, T-2.3.1.1, T-3.1.1.1, C-08, C-14 |
| CG-04 | `pslverr` | E1 và E2 × {rảnh, TX và RX cùng bận}; E3 TXDATA và E3 start_tx × {TX bận, chờ `cts_n`}; E4 CFG và E4 BAUD × {TX bận, RX bận, chờ `cts_n`}; E5 × {rảnh, bận}; 4 bin "hợp lệ khi bận" của REQ-ERR-07…10 | 3.1.1.1, 3.1.2, 3.1.3.1, 3.1.3.2, 3.1.4.1, 3.1.4.2, 3.1.4.3, 3.1.5, 3.2.1.1, 3.2.1.2, 3.2.1.3 | H-09, T-2.9.3.1, T-3.1.1.1, T-3.1.2, T-3.1.4.1, T-3.1.5, T-3.2.1.1, C-01, C-08, C-12, C-13, C-14 |
| CG-05 | Dữ liệu và parity | Data ∈ {`0x00`, `0xFF`, `0x55`, `0xA5`, `0x5A`, giá trị khác}; TX với N < 8 và bit cao của TXDATA bằng 1; RX với N < 8, N bit data toàn 1, `RXDATA[7:N]=0`; số bit 1 của data chẵn và lẻ × parity {odd, even} | 2.9.1.2, 2.10.1.2, 2.9.1.3, 2.10.1.3 | H-05, T-2.9.1.2, T-2.9.1.3 |
| CG-06 | Lỗi đường truyền | `parity_err`; `frame_err` do stop 1; `frame_err` do stop 2; `overrun`; `parity_err` và `frame_err` cùng khung; break; glitch < 0,4 bit; xóa cờ bằng đọc RXDATA | 3.3.1, 3.3.2.1, 3.3.2.2, 3.3.3, 2.10.3.2, 2.10.2.2 | H-07, T-2.10.2.2, T-2.10.3.2, T-3.3.1, T-3.3.2.1, T-3.3.3, C-03, C-07 |
| CG-07 | Ngắt | 10 dòng của bảng chân lý H-18; với từng nguồn {tx_done, rx_done, parity_err, frame_err, overrun}: cạnh lên và cạnh xuống của `irq` khi bit IE của nguồn đó bằng 1; bật và tắt IER khi cờ đã đặt | 2.5.1, 2.12.2.1, 2.12.2.2, 2.12.3.1, 2.12.3.2 | H-18, C-10, C-11 |
| CG-08 | Điều khiển luồng | `cts_n` ∈ {0 lúc start_tx, 1 rồi hạ, lên 1 giữa khung, hạ cùng sườn start_tx}; 4 tổ hợp (`rx_dis`, `rx_done`) của `rts_n` | 2.9.3.1, 4.2.1, 2.11.1.1, 2.11.1.2, 2.11.1.3 | H-16, H-17, T-2.2.2.2, T-2.9.3.1, C-06, C-15 |
| CG-09 | Reset | Reset mềm ở trạng thái {rảnh, TX bận, RX bận, chờ `cts_n`}; soft_rst + start_tx khi {`tx_done=1`, `tx_done=0`}; ghi CTRL theo từng lane; reset cứng giữa khung TX và RX | 2.7.1.2, 2.7.1.3, 4.1.1.1, 4.1.1.2, 2.6.1 | H-19, T-1.2.2, C-04, C-05, C-14 |
| CG-10 | Lệch tốc độ bên phát | {−3 %, −2 %, 0, +2 %, +3 %} × n ∈ {7…12}; khung nối liền ở ±2 % | 2.10.4.1, 2.10.4.2, 4.3.1 | H-06, H-07, T-2.10.4.2, C-09 |
| CG-11 | `tx_dis` / `rx_dis` | `tx_dis` ∈ {0, 1} × có start_tx; `rx_dis` ∈ {0, 1} × có khung đến; 4 tổ hợp CFG[6:5] đọc lại qua STAT[5:4] | 2.2.2.1, 2.2.2.2, 2.4.3.1 | T-2.2.2.1, T-2.2.2.2, T-2.4.3.1 |
| CG-12 | Đồng thời | TX và RX cùng chạy; đọc RXDATA trùng chu kỳ byte mới; start_tx quanh thời điểm `tx_done` lên | 3.2.1.1, 2.10.3.3 | H-09, T-2.10.3.2, T-3.2.1.1, C-12 |
| CG-13 | SPI và chân wrapper | Ghi × chỉ số {0, 2, 3, 5, 6, 7}; đọc × chỉ số {1, 4, 7}; `cmd[6:4] ≠ 000`; hủy khung ghi trước bit 48; hủy khung đọc sau bit 8; chuỗi host phát và nhận | 2.13.2.1, 2.13.2.2, 2.13.3.1, 2.13.3.2, 2.13.4.1, 2.13.4.2, 2.14.1.1, 2.14.1.2, 1.3.1 | H-20, H-10, H-11, H-12, H-13, H-14, H-15, T-1.3.1 |

## 5.7 Regression, netlist, GLS và tiêu chí kết thúc

**Regression.** Chạy toàn bộ test có tên, sau đó chạy ngẫu nhiên có ràng buộc (dạng khung, data, baud, `pstrb`, địa chỉ, giá trị IER, thời điểm lệnh, thời điểm reset mềm, lệnh SPI) với nhiều seed. Test FAIL phải chạy lại được bằng seed ghi trong log.

**Netlist Yosys (G4).** Top `apb_uart`, chạy lại các test mức khối.
- Tắt: SVA và kiểm gắn ở mức unit hoặc `apb_uart_core`; code coverage.
- Giữ: scoreboard; SVA ở cổng `apb_uart` (A-01…A-05, A-09…A-13); kiểm X.

**GLS có SDF ở tt, ss, ff (G8).** ASSUMPTION: netlist sau layout có top là `tt_um_hust_apb_uart` (tile 1×1), nên cổng `apb_uart` nằm bên trong; nhóm cần xác nhận với giảng viên.
- Chạy: các test mức chip (H-10…H-15, H-20, T-1.3.1) với scoreboard SB-10, SB-12 và SVA ở chân (A-14, A-15).
- Đầu vào không đồng bộ (`rx`, `cts_n`, SPI) gây vi phạm setup/hold ở FF đồng bộ đầu tiên và sinh X. Phải tắt timing check trên FF đồng bộ tầng một, hoặc giữ sườn của peer ngoài cửa sổ setup/hold.

**Tiêu chí kết thúc.**

| Tiêu chí | Ngưỡng | Nguồn |
|---|---|---|
| Test Priority 1 | 100 % PASS | SPEC §15 |
| SVA | 0 fail; mọi `A-NN` có kích hoạt | SPEC §15; mục tiêu nhóm |
| Statement, branch coverage | ≥ 90 % | SPEC §15 |
| 20 test công khai | PASS trên RTL và netlist Yosys | SPEC §15 (G3, G4) |
| GLS có SDF | Test mức chip PASS ở tt, ss, ff | SPEC §15 (G8); số test là mục tiêu nhóm |
| Kiểm cấu trúc RTL | 0 cảnh báo `verilator -Wall`; 0 latch; `rx`, `cts_n` qua 2 FF | SPEC §3.2 (G2) |
| Functional coverage | 100 % bin của mục 5.6.2 | Mục tiêu nhóm |
| Waiver | Không còn waiver chưa duyệt | Mục tiêu nhóm |
