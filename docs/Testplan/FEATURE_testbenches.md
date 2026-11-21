# Triển khai test và testbench APB UART

Nguồn triển khai là [TESTPLAN.md](TESTPLAN.md), đặc biệt Phần 1–3 cho kịch bản và Phần 5 cho yêu cầu môi trường. Hai kế hoạch cũ trong `docs/superpowers/plans/` mô tả giai đoạn soạn testplan. Hướng dẫn chạy nằm tại [testbenches/README.md](../testbenches/README.md).

| Giai đoạn | Tiến độ |
|---|---|
| Tạo file theo ID | Có 20 ca H, 51 ca T và 15 ca C. 26 file T dùng lại kịch bản nguồn theo các dòng `covered by`. |
| Dựng fixture | Có BFM APB/SPI, UART peer, checker, fixture unit cho baud, thanh ghi và SPI, cùng runner QuestaSim xuất UCDB. |
| Biên dịch | QuestaSim 2024.3 biên dịch 91 file SystemVerilog với 0 lỗi và 0 cảnh báo. |
| Smoke test runner | QuestaSim 10.7c chạy DUT giả tối giản: H-01, H-02 và T-2.1.1.2 PASS. Khi đổi BAUD từ `0x900D` thành `0x900C`, H-02 FAIL ở SB-01 và runner thoát mã 1. |
| Rà soát 2026-11-17 | Đối chiếu ca với TESTPLAN.md, sửa 4 chỗ yếu hơn testplan: ngưỡng CTS 59 → 80 ns (H-16, T-2.9.3.1); H-19 kiểm `tx=1` liên tục sau soft reset giữa khung; T-1.2.2 đặt đủ điều kiện đầu (CFG 0x1B, IER 0x07, `rx_done=1`, `irq=1`, TX giữa khung); C-04 thêm TX đang phát; T-1.1.1.5 đưa CFG về 0x03 và TXDATA 0x41. Biên dịch lại 91 file: 0 lỗi, 0 cảnh báo. Chưa chạy trên RTL đích. |
| Đưa vào repo thiết kế 2026-11-17 | Copy vào `APB_UART_Git/i2c-apb-uart/tb/` (`common/`, `unit/`, `cases/`, `run.py`, `README.md`) và `docs/Testplan/FEATURE_testbenches.md`; thêm `tb/run-*/` vào `.gitignore`. `run.py` sửa để chạy được cả bố cục phẳng (`testbenches/`) lẫn bố cục repo. Repo có đủ 9 file RTL: biên dịch 91 file testbench cùng RTL không lỗi; H-01, H-02, H-20 PASS trên RTL thật. Chưa chạy đủ 86 ca. Dòng "Mô phỏng RTL mục tiêu" bên dưới là trạng thái cũ. |
| Regression 86 ca trên RTL thật 2026-11-17 | `tb/run.py` với 9 file RTL của `i2c-apb-uart/rtl`, QuestaSim 10.7c, seed 1: **85/86 PASS**. FAIL: T-1.2.2 (xem dưới). `regression.ucdb` gộp có độ phủ code theo file 89,29 % (số lọc của vcover); chưa tách statement/branch của RTL để so ngưỡng 90 %. |
| Sửa lỗi T-1.2.2 và chạy lại 2026-11-21 | `rtl/uart_regs.v:58` thêm `& presetn` vào `pslverr`. Regression 86 ca, QuestaSim 10.7c, seed 1: **86/86 PASS**. 20 test P của khung chấm `apb-uart-sinh-vien` PASS với seed 1, 7, 2026. |
| Mô phỏng RTL mục tiêu | Chưa chạy được. RTL tại `D:/APB_UART/APB_UART/sources/rtl` thiếu `apb_uart`, `apb_uart_core` và `tt_um_hust_apb_uart`. Elaborate H-01, H-20 và C-12 báo thiếu đúng các module này. |
| Hoàn thiện Phần 5 | Còn các mục dưới đây. Chưa có kết luận đạt tiêu chí nghiệm thu hoặc đạt độ phủ trên DUT. |

## Quyết định triển khai

- Giữ giao diện theo `TB_GUIDE.md` và chọn DUT theo cấp kiểm. Không thay `apb_uart` bằng top DE2-115 `uart_apb_top`, vì địa chỉ, chân và phân cấp của hai bản RTL không tương ứng. Nếu bản RTL đích khác `TB_GUIDE.md`, cần đối chiếu lại ánh xạ và kết quả mong đợi.
- Ca có dòng `covered by` vẫn có file và top riêng, nhưng gọi trực tiếp kịch bản nguồn. Khi chạy đủ 86 ID, các kịch bản dùng chung được chạy lại để tạo báo cáo theo từng ID.
- T-2.10.3.2 kiểm trùng sườn tại cổng unit `uart_regs`: lái `rx_valid` cùng access đọc RXDATA. Các bước còn lại chạy ở mức khối với khung UART thật. Phần quét lệch −3…+3 tại lõi còn thiếu.
- Workspace hiện tại không có metadata Git. Toàn bộ file mới nằm trong `testbenches/` và hồ sơ tiến độ này nằm trong `docs/`.

## Lỗi RTL phát hiện (không sửa trong `rtl/`)

- **T-1.2.2** (REQ-IO-02, Spec ID 1.2.2 / 2.6.1): hạ `presetn=0` giữa pha access của lệnh ghi lỗi (`W 020`, `psel=penable=1`) thì `pslverr` vẫn bằng 1, mong đợi 0. `rtl/uart_regs.v:58`: `assign pslverr = access & (e1 | e2 | e3 | e4 | e5);` với `access = psel & penable` (dòng 26), không có điều kiện `presetn`. Thêm `& presetn` vào `pslverr` là đủ. Các output khác (`tx`, `rts_n`, `irq`, `pready`) về giá trị reset đúng.
- **Đã sửa 2026-11-21:** dòng 58 thành `assign pslverr = access & presetn & (e1 | e2 | e3 | e4 | e5);`; T-1.2.2 PASS, regression 86/86 PASS.

## Còn mở

- Hoàn thiện mô hình tham chiếu có theo dõi trạng thái và sự kiện dư cho toàn bộ kịch bản. Các checker hiện dự đoán khung UART từ cấu hình/stimulus, đối chiếu giao dịch APB/SPI, cờ và thời gian tại các điểm đặt trong từng ca.
- Hoàn thiện A-06, A-07, A-08 và chứng minh độ kích hoạt của từng assertion. Một số thuộc tính thời gian hiện được kiểm trong từng testcase. H-01 đã nối theo tên và kiểm đầu ra reset, còn kiểm tự động hướng và độ rộng của toàn bộ cổng.
- Bổ sung CG-04, CG-06…CG-09, CG-11 và CG-12. Hoàn thiện các bin còn thiếu của các nhóm hiện có, rồi kiểm độ phủ chức năng, statement/branch và ngưỡng được quy định trong Phần 5.
- Đưa unit regression có sẵn vào runner khi có đúng nguồn. Thực hiện kiểm CDC trên netlist, regression netlist Yosys, GLS có SDF theo tt/ss/ff và regression seed theo Phần 5.
