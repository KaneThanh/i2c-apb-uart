# Checklist sign-off G2–G9 (điền đường dẫn bằng chứng vào cột cuối)

Mục lấy từ danh mục kiểm tra G1–G9 trong `HD-APB-UART-tuong-tac.html` (§13) và tiêu chí gate trong spec §15.
Commit được chấm: `__________` (tag `v1.0`), ngày `__/11/2026`.

## G2 — RTL + lint (14/11, nộp bù)

| # | Mục | Lệnh / nơi xem | ✔ | Bằng chứng |
|---|---|---|---|---|
| 1 | Module `apb_uart` đúng tên và 16 cổng | đối chiếu spec §2.1 | ☐ | |
| 2 | `verilator --lint-only -Wall`: 0 dòng `%Warning` (2 top) | `make -C flow lint` | ☐ | `build/lint/*.log` |
| 3 | Yosys `proc`: 0 latch | `build/syn/*/latch_check.rpt` | ☐ | |
| 4 | Một net clock `pclk`, không clock sinh bằng logic | `check_setup` trong `build/sta/*/check_setup.rpt`; CTS chỉ có 1 cây | ☐ | |
| 5 | `rx`, `cts_n` (và SPI) qua 2 FF đồng bộ | RTL `sync_2ff`; netlist có `u_sync_*` | ☐ | |
| 6 | Không `initial`, `#delay`, `$display`, không gọi cell `sky130_` trong `rtl/` | `grep -nE "initial\|#[0-9]\|\\$display\|sky130_" rtl/*.v` | ☐ | |

## G4 — netlist (18/11)

| # | Mục | ✔ | Bằng chứng |
|---|---|---|---|
| 7 | Netlist Yosys 2 top, `check -assert` sạch, không cell `$` chưa ánh xạ | ☐ | `build/syn/*/stat.rpt` |
| 8 | Người kiểm chứng: 20 test công khai PASS trên netlist `apb_uart` | ☐ | log từ người kiểm chứng |

## G6 — STA, LEC (21/11)

| # | Mục | ✔ | Bằng chứng |
|---|---|---|---|
| 9 | SDC: `create_clock` 40 ns trên `pclk`/`clk`, input/output delay mọi cổng, `check_setup` không có endpoint thiếu ràng buộc | ☐ | `build/sta/*/check_setup.rpt` |
| 10 | Setup WS ≥ 0 ở ss (trước layout, 2 top) | ☐ | `build/sta/*/ss/summary.rpt` |
| 11 | Hold WS ≥ 0 ở tt/ss/ff (sau route, 9 corner) | ☐ | `make -C flow metrics` |
| 12 | eqy: RTL ≡ netlist Yosys (`apb_uart`, `tt_um`) | ☐ | `build/lec/*_syn/eqy.log` dòng `Successfully proved` |
| 13 | eqy: RTL ≡ netlist sau layout (`tt_um`) | ☐ | `build/lec/tt_um_pnr/eqy.log` |

## G7 — Layout (24/11)

| # | Mục | ✔ | Bằng chứng |
|---|---|---|---|
| 14 | LibreLane hết flow trên template TT, tile 1×1 (`info.yaml: tiles "1x1"`) | ☐ | Actions `gds` xanh |
| 15 | Setup, hold WS sau route ≥ 0 (ss setup, mọi corner hold) | ☐ | `build/metrics.md` |
| 16 | Commit tại chỗ và commit trên GitHub cho cùng metrics | ☐ | 2 file `metrics.json` |

## G8 — GLS (26/11)

| # | Mục | ✔ | Bằng chứng |
|---|---|---|---|
| 17 | GLS có SDF tt: 20 test công khai PASS, SDF gắn 100 % instance | ☐ | `build/gls/tt/sim.log` |
| 18 | GLS có SDF ss | ☐ | `build/gls/ss/sim.log` |
| 19 | GLS có SDF ff | ☐ | `build/gls/ff/sim.log` |
| 20 | Vi phạm timing check chỉ ở tầng đồng bộ đầu (đã giải thích) hoặc không có | ☐ | |

## G9 — Sign-off (26/11 23:59)

| # | Mục | ✔ | Bằng chứng |
|---|---|---|---|
| 21 | Magic DRC = 0 | ☐ | `metrics.json: magic__drc_error__count` |
| 22 | KLayout DRC = 0 (precheck TT: FEOL, BEOL, offgrid, pin label) | ☐ | artifact `precheck_reports` |
| 23 | LVS khớp (0 lỗi, 0 khác biệt) | ☐ | `design__lvs_*` |
| 24 | Antenna = 0 | ☐ | `antenna__violating__nets/pins` |
| 25 | GitHub Actions xanh: `gds`, `precheck`, `gl_test`, `viewer`, `docs`, `test` (`fpga` không chạy khi push) | ☐ | link run |
| 26 | Báo cáo đủ 10 mục phần E của tiêu chí chấm | ☐ | `docs/reports/final.pdf` |
| 27 | Tag `v1.0` trỏ đúng commit đã chấm | ☐ | `git show v1.0` |

## Chỉ số ghi vào báo cáo (lấy từ `build/metrics.md`)

| Chỉ số | Baseline 16/11 | Bản nộp |
|---|---|---|
| Cell (sau tổng hợp, tt_um, có bản vá fsm_encoding) | 917 | |
| Flip-flop | 185 | |
| Diện tích tổng hợp (µm²) | 11 161 | |
| Utilization sau layout (gồm fill), lần C | 0,905 | |
| Setup WS @ss (ns), lần C | +21,84 | |
| Hold WS @ff (ns), lần C | +0,112 | |
| Buffer hold, lần C | 151 | |
| Vi phạm max slew @ss, lần C | 283 | |
| Công suất tt (mW, hoạt động mặc định) | 0,645 | |
