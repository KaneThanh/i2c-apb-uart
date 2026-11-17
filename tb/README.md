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
