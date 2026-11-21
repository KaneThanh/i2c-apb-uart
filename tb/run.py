import argparse
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent
# Workspace layout: ../docs/TESTPLAN.md. Design repo layout: ../docs/Testplan/TESTPLAN.md.
PLAN = next(
    (p for p in (ROOT.parent / "docs" / "TESTPLAN.md", ROOT.parent / "docs" / "Testplan" / "TESTPLAN.md") if p.is_file()),
    ROOT.parent / "docs" / "TESTPLAN.md",
)


def tb_files(pattern="*.sv"):
    """Testbench sources in ROOT and its subfolders (flat workspace or tb/{common,unit,cases}); skips run-* output."""
    return sorted(p for p in ROOT.rglob(pattern) if not any(part.startswith("run-") for part in p.relative_to(ROOT).parts))
CASE_PATTERN = r"^### ([HTC]-[\d.]+) ([^\r\n]+)"
PASS_PATTERN = r"(?m)^\s*#?\s*PASS ([HTC]-[\d.]+)\s*$"


def case_module(case):
    return "tb_" + case.lower().replace("-", "_").replace(".", "_")


def inventory():
    plan = PLAN.read_text(encoding="utf-8")
    sections = list(re.finditer(CASE_PATTERN, plan, re.M))
    cases = {section[1]: section[2] for section in sections}
    expected = {case_module(case) for case in cases}
    case_files = {source.stem: source for source in tb_files("tb_*.sv")}
    actual = set(case_files)
    if expected != actual:
        raise ValueError(
            f"Thiếu file: {sorted(expected - actual)}. File dư: {sorted(actual - expected)}."
        )
    for index, section in enumerate(sections):
        end = sections[index + 1].start() if index + 1 < len(sections) else len(plan)
        declared = re.search(r"^covered by ([^|\n]+)", plan[section.end():end], re.M)
        if not declared:
            continue
        sources = re.findall(r"[HTC]-[\d.]+", declared[1])
        source_file = case_files[case_module(section[1])]
        modules = re.findall(
            r"(?m)^\s*(tb_\w+)\s+#\(\.AUTO_RUN\(0\)\)", source_file.read_text(encoding="utf-8")
        )
        if modules != [case_module(source) for source in sources]:
            raise ValueError(f"{section[1]} gọi sai testcase nguồn: {modules}.")
    return cases


def run_command(command, cwd, log_path):
    with log_path.open("wb") as log:
        result = subprocess.run(command, cwd=cwd, stdout=log, stderr=subprocess.STDOUT)
    output = log_path.read_text(encoding="utf-8", errors="replace")
    if result.returncode:
        missing_modules = re.findall(r"Module '([^']+)' is not defined", output)
        detail = f" Thiếu module: {', '.join(dict.fromkeys(missing_modules))}." if missing_modules else ""
        raise RuntimeError(
            f"{command[0]} thoát với mã {result.returncode}.{detail} Log: {log_path}"
        )
    return output


def main():
    parser = argparse.ArgumentParser(description="Chạy testbench SystemVerilog với QuestaSim.")
    parser.add_argument("--list", action="store_true", help="Kiểm tra danh sách ca và in ID.")
    parser.add_argument("--compile-only", action="store_true", help="Chỉ chạy vlib và vlog.")
    parser.add_argument("--out-dir", type=Path, default=ROOT, help="Nơi tạo thư mục run-*.")
    parser.add_argument("--rtl", nargs="+", type=Path, default=[], help="Các file RTL/netlist.")
    parser.add_argument("--case", nargs="+", metavar="ID", help="Mặc định chạy đủ 86 ID.")
    parser.add_argument("--questa-bin", type=Path, help="Thư mục chứa vlib/vlog/vsim/vcover.")
    parser.add_argument("--seed", type=int, default=1)
    args = parser.parse_args()

    cases = inventory()
    if args.list:
        for case, name in cases.items():
            print(case, name)
        print(f"Tổng: {len(cases)}")
        return 0
    if not args.rtl and not args.compile_only:
        parser.error("Cần truyền các file RTL bằng --rtl.")
    missing = [str(path) for path in args.rtl if not path.is_file()]
    if missing:
        parser.error(f"Không tìm thấy file RTL: {', '.join(missing)}")
    selected = list(dict.fromkeys(args.case or cases))
    unknown = [case for case in selected if case not in cases]
    if unknown:
        parser.error(f"ID không có trong testplan: {', '.join(unknown)}")
    rtl = [str(path.resolve()) for path in args.rtl]
    sources = [str(path) for path in tb_files()]
    incdirs = [f"+incdir+{folder}" for folder in sorted({path.parent for path in tb_files("*.svh")})]
    bin_dir = args.questa_bin.resolve() if args.questa_bin else None
    out_dir = args.out_dir.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    build = Path(tempfile.mkdtemp(prefix="run-", dir=out_dir))
    print(f"Thư mục kết quả {build}", flush=True)

    def execute(tool, log, *arguments):
        command = str(bin_dir / tool) if bin_dir else tool
        return run_command([command, *arguments], build, build / log)

    execute("vlib", "vlib.log", "work")
    if rtl:
        execute("vlog", "vlog.log", "+cover=bcesft", *rtl)
    execute("vlog", "vlog_tb.log", "-sv", *incdirs, *sources)

    if args.compile_only:
        print(f"Đã biên dịch {len(sources)} file testbench.")
        return 0

    failed = []
    databases = []
    for case in selected:
        top = case_module(case)
        database = f"{top}.ucdb"
        script = "onerror {quit -code 1}; "
        script += f"coverage save -onexit {database}; run -all; quit -code 0"
        name = cases[case].split()[0] if case.startswith("T-") else case
        try:
            output = execute(
                "vsim", f"{top}.log", "-c", "-coverage", "-sv_seed", str(args.seed),
                "-onfinish", "stop", top, "-do", script,
            )
            if re.findall(PASS_PATTERN, output) != [case] or not (build / database).is_file():
                raise RuntimeError(f"Kết quả mô phỏng thiếu PASS hoặc UCDB. Log: {top}.log")
            databases.append(database)
        except RuntimeError as error:
            failed.append(case)
            print(f"FAIL {case} {name} seed={args.seed} | {error}", flush=True)
        else:
            print(f"PASS {case} {name} seed={args.seed}", flush=True)

    if databases:
        execute("vcover", "merge.log", "merge", "regression.ucdb", *databases)
        execute("vcover", "coverage.txt", "report", "-details", "regression.ucdb")
    print(f"{len(selected) - len(failed)}/{len(selected)} PASS")
    return int(bool(failed))


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ValueError) as error:
        print(f"Lỗi: {error}", file=sys.stderr)
        sys.exit(1)
