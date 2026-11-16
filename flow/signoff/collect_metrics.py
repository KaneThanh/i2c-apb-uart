#!/usr/bin/env python3
"""Đọc runs/<tag>/final/metrics.json của LibreLane và in bảng PASS/FAIL theo tiêu chí gate G6–G9.

Cách dùng:  python3 flow/signoff/collect_metrics.py runs/wokwi [--md out.md]
Mã thoát 1 nếu có tiêu chí bắt buộc FAIL.

Tên metric lấy đúng từ metrics.json của LibreLane 3.0.14 (lần chạy 16/11/2026).
Lý do cần script: LibreLane chỉ dừng flow khi vi phạm timing ở corner *tt*
(TIMING_VIOLATION_CORNERS), nên phải tự kiểm ss và ff.
"""
import json
import sys
from pathlib import Path


def load(run_dir: Path) -> dict:
    p = run_dir / "final" / "metrics.json"
    if not p.is_file():
        sys.exit(f"Không thấy {p}. Flow đã chạy xong chưa?")
    return json.loads(p.read_text())


def corners(m: dict, base: str) -> dict:
    pre = base + "__corner:"
    return {k[len(pre):]: v for k, v in m.items() if k.startswith(pre)}


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    run_dir = Path(sys.argv[1])
    md_out = None
    if "--md" in sys.argv:
        md_out = Path(sys.argv[sys.argv.index("--md") + 1])
    m = load(run_dir)

    rows = []  # (gate, tiêu chí, giá trị, kết quả, bắt buộc)

    def add(gate, name, value, ok, required=True):
        if value is None:
            rows.append((gate, name, "không có", "?", required))
        else:
            rows.append((gate, name, value, "PASS" if ok else ("FAIL" if required else "CẢNH BÁO"), required))

    # --- G6/G7 timing ---
    setup = corners(m, "timing__setup__ws")
    hold = corners(m, "timing__hold__ws")
    ss = {c: v for c, v in setup.items() if "_ss_" in c}
    if ss:
        worst_c = min(ss, key=ss.get)
        add("G6/G7", f"setup WS ≥ 0 @ss (xấu nhất {worst_c})", round(ss[worst_c], 3), ss[worst_c] >= 0)
    else:
        add("G6/G7", "setup WS ≥ 0 @ss", None, False)
    for c in sorted(setup):
        if "_ss_" not in c:
            add("G7", f"setup WS @{c}", round(setup[c], 3), setup[c] >= 0)
    for c in sorted(hold):
        add("G6/G7", f"hold WS ≥ 0 @{c}", round(hold[c], 3), hold[c] >= 0)
    add("G7", "setup TNS = 0", m.get("timing__setup__tns"), m.get("timing__setup__tns", 1) == 0)
    add("G7", "hold TNS = 0", m.get("timing__hold__tns"), m.get("timing__hold__tns", 1) == 0)

    # --- G2 nhắc lại ---
    for k, name in [("design__lint_error__count", "lint lỗi = 0"),
                    ("design__lint_warning__count", "lint cảnh báo = 0"),
                    ("synthesis__check_error__count", "synth check lỗi = 0")]:
        add("G2", name, m.get(k), m.get(k, 1) == 0)

    # --- G9 sign-off vật lý ---
    for k, name in [("route__drc_errors", "route DRC = 0"),
                    ("magic__drc_error__count", "Magic DRC = 0"),
                    ("design__lvs_error__count", "LVS lỗi = 0"),
                    ("design__lvs_device_difference__count", "LVS khác thiết bị = 0"),
                    ("design__lvs_net_difference__count", "LVS khác net = 0"),
                    ("design__lvs_unmatched_pin__count", "LVS chân không khớp = 0"),
                    ("antenna__violating__nets", "antenna net vi phạm = 0"),
                    ("antenna__violating__pins", "antenna chân vi phạm = 0")]:
        add("G9", name, m.get(k), m.get(k, 1) == 0)
    kl = m.get("klayout__drc_error__count")
    if kl is not None:
        add("G9", "KLayout DRC = 0", kl, kl == 0)
    else:
        rows.append(("G9", "KLayout DRC = 0", "không chạy trong flow (precheck TT chạy)", "?", False))

    # --- thông tin / cảnh báo ---
    add("info", "utilization (gồm fill)", m.get("design__instance__utilization"), True, False)
    add("info", "số buffer hold", m.get("design__instance__count__hold_buffer"), True, False)
    add("info", "công suất tổng (W, tt, hoạt động mặc định)", m.get("power__total"), True, False)
    for k, name in [("design__max_slew_violation__count", "vi phạm max slew"),
                    ("design__max_fanout_violation__count", "vi phạm max fanout"),
                    ("design__max_cap_violation__count", "vi phạm max cap")]:
        v = m.get(k)
        add("info", name, v, v == 0, False)

    # --- in ---
    w = max(len(r[1]) for r in rows)
    lines = [f"Kết quả từ {run_dir}/final/metrics.json", ""]
    lines.append(f"| Gate | {'Tiêu chí'.ljust(w)} | Giá trị | Kết quả |")
    lines.append(f"|---|{'-' * (w + 2)}|---|---|")
    for g, n, v, r, _ in rows:
        lines.append(f"| {g} | {n.ljust(w)} | {v} | {r} |")
    text = "\n".join(lines)
    print(text)
    if md_out:
        md_out.write_text(text + "\n")

    failed = [r for r in rows if r[4] and r[3] in ("FAIL", "?")]
    if failed:
        print(f"\n{len(failed)} tiêu chí bắt buộc chưa đạt hoặc thiếu số liệu.")
        return 1
    print("\nMọi tiêu chí bắt buộc: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
