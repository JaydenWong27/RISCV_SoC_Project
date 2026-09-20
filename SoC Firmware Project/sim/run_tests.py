#!/usr/bin/env python3
"""Run the cocotb test suites against Icarus Verilog.

Invokes iverilog/vvp directly instead of going through cocotb's Makefile.
Two reasons, both specific to this project on Windows:

  * cocotb passes vvp an absolute path ending in .dll for -m. Icarus 11 then
    looks for "<that path>.vpi" and fails. Using -M <dir> -m <name> works.
  * GNU make cannot handle spaces in prerequisite paths, and this project
    lives under "SoC Firmware Project".

Usage:
    python run_tests.py              # every suite
    python run_tests.py uart bram    # only the named suites
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path

SIM_DIR = Path(__file__).resolve().parent
RTL = SIM_DIR.parent / "rtl"
BUILD = SIM_DIR / "sim_build"

CORE = [
    RTL / "core" / "rv32i_alu.v",
    RTL / "core" / "rv32i_decode.v",
    RTL / "core" / "rv32i_regfile.v",
    RTL / "core" / "rv32i_hazard.v",
    RTL / "core" / "rv32i_core.v",
]
PERIPH = [
    RTL / "bus" / "wb_interconnect.v",
    RTL / "peripherals" / "wb_bram.v",
    RTL / "peripherals" / "wb_gpio.v",
    RTL / "peripherals" / "wb_pwm.v",
    RTL / "peripherals" / "wb_timer.v",
    RTL / "peripherals" / "wb_uart.v",
]

# suite -> (toplevel module, source files)
SUITES = {
    "alu":          ("rv32i_alu",      [RTL / "core" / "rv32i_alu.v"]),
    "decode":       ("rv32i_decode",   [RTL / "core" / "rv32i_decode.v"]),
    "regfile":      ("rv32i_regfile",  [RTL / "core" / "rv32i_regfile.v"]),
    "hazard":       ("rv32i_hazard",   [RTL / "core" / "rv32i_hazard.v"]),
    "core":         ("rv32i_core",     CORE),
    "interconnect": ("wb_interconnect", [RTL / "bus" / "wb_interconnect.v"]),
    "bram":         ("wb_bram",        [RTL / "peripherals" / "wb_bram.v"]),
    "gpio":         ("wb_gpio",        [RTL / "peripherals" / "wb_gpio.v"]),
    "pwm":          ("wb_pwm",         [RTL / "peripherals" / "wb_pwm.v"]),
    "timer":        ("wb_timer",       [RTL / "peripherals" / "wb_timer.v"]),
    "uart":         ("wb_uart",        [RTL / "peripherals" / "wb_uart.v"]),
    "soc":          ("soc_top",        CORE + PERIPH + [RTL / "top" / "soc_top.v"]),
}


def cocotb_config(*args):
    out = subprocess.run(
        [sys.executable, "-m", "cocotb_tools.config", *args],
        capture_output=True, text=True, check=True,
    )
    return out.stdout.strip()


def vpi_module():
    """Return (search_dir, module_name), creating the .vpi alias if needed."""
    entry = Path(cocotb_config("--lib-entry", "vpi", "icarus"))
    lib_dir, stem = entry.parent, entry.stem
    alias = lib_dir / (stem + ".vpi")
    if not alias.exists():
        shutil.copyfile(entry, alias)
    return str(lib_dir), stem


def run_suite(name, lib_dir, module, env_base):
    toplevel, sources = SUITES[name]
    BUILD.mkdir(exist_ok=True)
    vvp_file = BUILD / f"{name}.vvp"

    # The RTL carries no `timescale directive, so Icarus would default to a
    # 1-second precision and every cocotb Timer would fail to be represented.
    cmds = BUILD / "cmds.f"
    cmds.write_text("+timescale+1ns/1ps\n")

    compile_cmd = ["iverilog", "-g2012", "-o", str(vvp_file), "-s", toplevel,
                   "-f", str(cmds), *[str(s) for s in sources]]
    r = subprocess.run(compile_cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"  COMPILE FAILED\n{r.stdout}{r.stderr}")
        return False, 0, 0

    env = dict(env_base)
    env["COCOTB_TEST_MODULES"] = f"test_{name}"
    env["COCOTB_TOPLEVEL"] = toplevel
    env["COCOTB_RESULTS_FILE"] = str(BUILD / f"results_{name}.xml")

    r = subprocess.run(["vvp", "-M", lib_dir, "-m", module, str(vvp_file)],
                       capture_output=True, text=True, env=env, cwd=str(SIM_DIR))
    out = r.stdout + r.stderr

    passed = failed = 0
    for line in out.splitlines():
        if "TESTS=" in line and "PASS=" in line:
            for tok in line.replace("*", " ").split():
                if tok.startswith("PASS="):
                    passed = int(tok.split("=")[1])
                elif tok.startswith("FAIL="):
                    failed = int(tok.split("=")[1])
    if passed == 0 and failed == 0:
        print("  NO TESTS RAN")
        for line in out.splitlines():
            if "ERROR" in line or "Error" in line:
                print("   ", line.strip()[:160])
        return False, 0, 0

    status = "ok" if failed == 0 else "FAIL"
    print(f"  {status}: {passed} passed, {failed} failed")
    if failed:
        for line in out.splitlines():
            if " FAIL " in line:
                print("   ", line.strip()[:160])
    return failed == 0, passed, failed


def main():
    wanted = sys.argv[1:] or list(SUITES)
    unknown = [w for w in wanted if w not in SUITES]
    if unknown:
        sys.exit(f"unknown suite(s): {', '.join(unknown)}")

    lib_dir, module = vpi_module()

    # wb_bram and soc_top load firmware.hex via $readmemh, relative to cwd.
    shutil.copyfile(SIM_DIR.parent / "firmware" / "firmware.hex",
                    SIM_DIR / "firmware.hex")

    env = dict(os.environ)
    env["GPI_USERS"] = (cocotb_config("--libpython") + ";"
                        + cocotb_config("--pygpi-entry-point"))
    env["PYGPI_PYTHON_BIN"] = sys.executable
    env["TOPLEVEL_LANG"] = "verilog"
    env["PYTHONPATH"] = str(SIM_DIR) + os.pathsep + env.get("PYTHONPATH", "")

    total_pass = total_fail = 0
    bad = []
    for name in wanted:
        print(f"[{name}]")
        ok, p, f = run_suite(name, lib_dir, module, env)
        total_pass += p
        total_fail += f
        if not ok:
            bad.append(name)

    print("\n" + "=" * 56)
    print(f"  {total_pass} passed, {total_fail} failed across {len(wanted)} suite(s)")
    if bad:
        print(f"  problem suites: {', '.join(bad)}")
    print("=" * 56)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
