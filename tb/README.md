# Testbench APB UART

Mỗi ID trong [TESTPLAN.md](../docs/Testplan/TESTPLAN.md) có một file `tb_<id>.sv` và một top mô phỏng tương ứng. Ví dụ, `T-2.10.3.2` dùng `tb_t_2_10_3_2.sv`. Với 26 dòng `covered by`, file của ca gọi trực tiếp kịch bản nguồn và báo kết quả dưới ID riêng.

## Cấu trúc thư mục

| Thư mục | Nội dung |
|---|---|
| `common/` | `apb_env.sv` (APB BFM, SVA, covergroup), `spi_env.sv` (SPI BFM mức chip), `uart_peer.svh`, `uart_coverage.svh` |
| `unit/` | Fixture mức unit: `baud_env.sv` (`baud_gen`), `regs_env.sv` (`uart_regs`), `spi_unit_env.sv` (`spi2apb`) |
| `cases/` | 86 file `tb_<id>.sv`, mỗi ID trong testplan một file |
| `run.py` | Runner QuestaSim |

`apb_env.sv` cung cấp APB BFM, kiểm handshake và so sánh readback. `spi_env.sv` cung cấp BFM SPI mode 0 cho mức chip. `uart_peer.svh` dựng khung kỳ vọng, phát kích thích RX và kiểm chuỗi TX theo chu kỳ 25 MHz. Các fixture `baud_env.sv`, `regs_env.sv` và `spi_unit_env.sv` kiểm riêng hành vi cần quan sát ở cổng unit.

## Chạy từ thư mục gốc của repo (`i2c-apb-uart/`)

```powershell
python -I -X utf8 tb/run.py --list
python -I -X utf8 tb/run.py --compile-only
$rtl = @(Get-ChildItem rtl -File -Filter '*.v' | ForEach-Object FullName)
python -I -X utf8 tb/run.py --rtl @rtl --case H-01 H-02 H-10
python -I -X utf8 tb/run.py --rtl @rtl
```

Truyền đúng các file RTL theo `TB_GUIDE.md`. Nếu thư mục chứa nhiều biến thể, truyền danh sách file cụ thể. Các top bắt buộc cho toàn bộ bộ ca là `apb_uart`, `apb_uart_core`, `tt_um_hust_apb_uart`, `baud_gen`, `uart_regs` và `spi2apb`, cùng các module phụ thuộc.

Trên máy hiện tại, dùng `--questa-bin C:/questasim64_10.7c/win64` để mô phỏng. Bản QuestaSim 2024.3 trong PATH đã biên dịch được nhưng báo lỗi license khi chạy `vsim`.

Runner tạo thư mục `run-*` chứa log và UCDB. Dùng `--out-dir` để chọn nơi lưu, `--questa-bin` nếu QuestaSim ngoài PATH, và `--seed` để lặp lại seed. Runner yêu cầu cả dòng PASS đúng ID lẫn UCDB của ca, rồi gộp các UCDB thành `regression.ucdb` và xuất `coverage.txt`. Lỗi compile, lỗi gắn DUT, timeout và lỗi checker đều cho mã thoát khác 0.

## Phạm vi đã xác minh

- Có 86 file ca và 5 module fixture. Bước `--list` so ID file và liên kết `covered by` với testplan. Compile xác nhận mã SystemVerilog; bước gắn DUT và mô phỏng quyết định kết quả của ca.
- Các covergroup hiện có ghi nhận dạng khung, baud, APB, payload/parity, sai lệch tốc độ và lệnh SPI. Các bin và điểm đo Phần 5 còn thiếu được theo dõi trong [tiến độ triển khai](../docs/Testplan/FEATURE_testbenches.md).

## Kết quả regression và lỗi RTL đã phát hiện

Regression ngày 2026-11-17 chạy 86 ca trên 9 file RTL trong `rtl/`, dùng QuestaSim 10.7c, seed 1. Kết quả: **85/86 PASS**. Ca FAIL duy nhất là **T-1.2.2**, do lỗi RTL. Testbench không sai và không cần sửa.

### T-1.2.2: `pslverr` không về 0 khi reset giữa pha access

**Yêu cầu.** REQ-IO-02 (Spec ID 1.2.2, 2.6.1): trong lúc `presetn = 0` và ngay sau reset, output phải là `tx = 1`, `rts_n = 1`, `irq = 0`, `pslverr = 0`, `pready = 1`. `presetn` là reset bất đồng bộ, nên output phải về giá trị reset ngay khi `presetn` xuống, không chờ sườn `pclk`.

**Kịch bản của ca** (`cases/tb_t_1_2_2.sv`):

| Bước | Kích thích | Kỳ vọng |
|---|---|---|
| 1 | Precondition: CFG = 0x1B, IER = 0x07, `rx_done = 1`, `irq = 1`, TX đang phát giữa khung | — |
| 2 | Ghi lỗi `W 020` (địa chỉ 0x020 ngoài bảng, lỗi E1), giữ `psel = penable = 1` ở pha access | `pslverr = 1` (đúng, dòng 19 của ca) |
| 3 | Vẫn giữ `psel = penable = 1`, hạ `presetn = 0`, chờ 2 ns | `{tx, rts_n, irq, pslverr, pready} = 5'b11001` (dòng 21 của ca) |
| 4 | Thả `psel/penable`, giữ reset 3 chu kỳ, nhả `presetn = 1` | `tx = 1` liên tục 2300 chu kỳ, khung TX cũ không phát tiếp |

**Kết quả đo.** Sau khi `presetn` xuống: `tx = 1`, `rts_n = 1`, `irq = 0`, `pready = 1` đều đúng. Riêng **`pslverr = 1`**, sai so với kỳ vọng 0.

**Nguyên nhân.** Trong `rtl/uart_regs.v`, `pslverr` là tổ hợp thuần của các tín hiệu APB đầu vào và không phụ thuộc `presetn`:

```verilog
// rtl/uart_regs.v
26:  wire       access     = psel & penable;
28:  wire       addr_ok    = (paddr[11:5] == 7'd0) & (paddr[1:0] == 2'd0) & (idx != 3'd7);
43:  wire e1 = ~addr_ok;
58:  assign pslverr     = access & (e1 | e2 | e3 | e4 | e5);
```

- `access` chỉ phụ thuộc `psel` và `penable`, là input do master lái. Master không bắt buộc phải thả `psel/penable` khi reset.
- `e1` chỉ phụ thuộc `paddr`. Địa chỉ 0x020 có `idx = 3'd0` nhưng `paddr[11:5] = 7'd1`, nên `addr_ok = 0` và `e1 = 1`.
- Các flip-flop trong khối về reset đúng. `pslverr` không qua flip-flop nào, nên `presetn = 0` không tác động lên nó. Kết quả: `pslverr = access & e1 = 1` trong suốt thời gian reset.
- `apb_uart.v` và `apb_uart_core.v` nối thẳng `pslverr` của `uart_regs` ra cổng top, không chặn thêm.

**Cách sửa** (trong thiết kế, dòng 58 của `rtl/uart_regs.v`). Thêm điều kiện `presetn` để `pslverr` bằng 0 khi reset:

```verilog
assign pslverr     = access & presetn & (e1 | e2 | e3 | e4 | e5);
```

- Chỉ đổi đúng dòng này. Logic `e1`–`e5` giữ nguyên.
- `wr = access & pwrite & ~pslverr` (dòng 49) không đổi hành vi. Trong reset, `pslverr = 0` làm `wr` có thể bằng 1, nhưng mọi thanh ghi đang bị reset bất đồng bộ nên lệnh ghi không có tác dụng. Khi `presetn = 1`, biểu thức mới bằng biểu thức cũ.
- Phần cứng chỉ thêm một cổng AND, đường `presetn` vốn đã có trong khối.

**Mức ảnh hưởng.** Assertion `ap_pslverr_zero_in_reset` (`!presetn |-> !pslverr`, không dùng `disable iff`) trong khung chấm của thầy (`public-tests/tb/checker.sv` trong gói `apb-uart-sinh-vien`, không nằm trong repo này) kiểm đúng điều này. Nếu một test ẩn H reset giữa pha access của lệnh lỗi, test đó FAIL với RTL hiện tại. Bộ 20 test P công khai không gặp lỗi này, vì cả 20 ca PASS với seed 1, 7 và 2026 ngày 2026-11-21.

**Kiểm lại sau khi sửa.** Chạy lại riêng ca này, rồi chạy cả 86 ca để chắc không hỏng ca khác:

```powershell
python -I -X utf8 tb/run.py --questa-bin C:/questasim64_10.7c/win64 --rtl @rtl --case T-1.2.2
python -I -X utf8 tb/run.py --questa-bin C:/questasim64_10.7c/win64 --rtl @rtl
```

Kỳ vọng: 86/86 PASS. Sau đó cập nhật kết quả vào `docs/Testplan/FEATURE_testbenches.md` và bản gốc trong workspace testplan.

Trạng thái ngày 2026-11-21: dòng 58 chưa sửa. Theo quy tắc dự án, testbench không tự sửa `rtl/`; người phụ trách RTL sửa.
