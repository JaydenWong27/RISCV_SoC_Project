# RISC-V SoC on MicroPhase A7-Lite

A fully functional 32 bit RISCV (RV32I) System-on-Chip implemented in Verilog, targeting the MicroPhase A7-Lite FPGA development board (AMD/Xilinx Artix-7 XC7A100T-2FTG256). The CPU executes real bare-metal C firmware and blinks the onboard LEDs.

## What this is

This project is a from-scratch RISC-V processor and SoC built entirely in synthesizable Verilog. It includes:

- A 5-stage pipelined RV32I CPU core
- A unified 32 KB block RAM for instructions and data, loaded from `firmware.hex` at elaboration
- GPIO, UART, PWM, and Timer peripherals
- A Wishbone bus interconnect connecting the CPU to all peripherals
- Bare-metal C firmware (LED blink demo)
- cocotb simulation test suites for each module

The design synthesizes and runs on real hardware using AMD Vivado. It runs directly from the board's 50 MHz oscillator with no MMCM.

## Specifications

| | |
|---|---|
| **Target** | MicroPhase A7-Lite — AMD/Xilinx Artix-7 XC7A100T-2FTG256 |
| **Toolchain** | Vivado 2026.1 (non-project TCL flow); Icarus Verilog + cocotb for simulation |
| **ISA** | RV32I — 37 base instructions across 9 opcode groups (no FENCE/ECALL/EBREAK) |
| **Pipeline** | 5-stage in-order: Fetch → Decode → Execute → Memory → Writeback |
| **Clock** | 50 MHz, taken straight from the board oscillator (no MMCM/PLL) |
| **Memory** | 32 KB unified instruction/data, true dual-port block RAM |
| **Bus** | Wishbone B4 classic, 32-bit, single master, 5 slaves |

### Post-route results (Vivado 2025.2, `soc_top`, after the stall-logic fixes)

| Resource | Used | Available | Utilization |
|---|---|---|---|
| Slice LUTs | 1,720 | 63,400 | 2.71% |
| Slice Registers | 1,820 | 126,800 | 1.44% |
| Block RAM (RAMB36E1) | 8 | 135 | 5.93% |
| DSP48 | 0 | 240 | 0% |
| Bonded IOB | 13 | 170 | 7.65% |
| Global clock buffers | 1 | 32 | 3.13% |

**Timing:** WNS **+5.847 ns** setup, WHS +0.105 ns hold, **0 failing endpoints** of 5,653.
20 ns minus 5.847 ns of slack leaves 14.15 ns, so this implementation supports roughly **70 MHz**,
about 40% above the 50 MHz target. The worst path runs from `ex_mem_mem_read` (the memory
stall) to the synchronous reset of the ID/EX registers (the bubble). Before the fixes it was
+5.214 ns / +0.092 ns. No DSPs and no LUTRAM: all storage lands in dedicated block RAM.

### Verification

**83 cocotb tests across 12 suites, all passing** (`python sim/run_tests.py`), plus
hardware bring-up on the board: the CPU boots from BRAM, executes bare-metal C, and
drives the LED through the Wishbone bus and GPIO peripheral.

**Random-program check against a Python reference model** (`python sim/cpu_check/cpu_check.py`):
7 directed load and branch cases plus 1,000 random programs, compared register by register.
The original core matched on only 155 of 1,000. That traced to five bugs in the stall logic,
all of which the 83 unit tests missed:

| # | Bug | Fix |
|---|---|---|
| 1 | Every stall dropped the block RAM output, so each load deleted the 4th instruction after it | Re-present `pc_prev` to the RAM while stalled |
| 2 | The load-use hazard check compared ID against EX/MEM instead of ID/EX | Feed the hazard unit from ID/EX |
| 3 | The bubble overwrote ID/EX while EX/MEM was frozen | Hold ID/EX during a memory stall |
| 4 | A branch fired during a memory stall and was lost | Gate branch and jump with `!mem_stall` |
| 5 | The first instruction after reset ran twice | Turn the duplicate fetch into a NOP |

With the fixes: 7 of 7 directed cases, 1,000 of 1,000 random programs, and the 83 cocotb tests still pass.

### Microarchitecture

- Prefetch buffer absorbing the BRAM's registered-read latency
- EX/MEM→EX and MEM/WB→EX forwarding paths
- Load-use hazard detection: every load costs 1 extra cycle, and a dependent instruction right after it 1 more
- Branches resolve in Execute: a taken branch costs 4 cycles, a not-taken branch 0
- Register-file read-during-write bypass
- Byte/halfword load-store with sign and zero extension

Interrupts are **not** implemented: `wb_timer` raises `timer_irq` and it reaches the
core's port list, but there is no trap handling, `mtvec` or CSR file, so the timer is
used by polling.

### Memory map

```
0x00000000  32 KB unified instruction/data RAM
0x10000000  UART   — TX data, TX busy, RX data, RX ready
0x10001000  GPIO   — output, direction, input (8-bit, tristate)
0x10002000  PWM    — period, compare, enable
0x10003000  Timer  — control, limit, value, status
```

## CPU architecture

The CPU is a 5-stage in-order pipeline:

![RV32I five-stage pipeline](SoC%20Firmware%20Project/docs/cpu_pipeline_5stage.svg)

### Key features

- Prefetch buffer: absorbs the BRAM's 1-cycle registered read latency so the pipeline always sees a valid instruction
- Data forwarding: EX/MEM→EX and MEM/WB→EX paths feed the ALU directly from in-flight results, eliminating most stall cycles
- Load-use stall: 1-cycle pipeline freeze when a load result is needed by the immediately following instruction
- Memory stall: every load freezes the pipeline for 1 cycle while the registered BRAM read completes
- Hazard detection: dedicated unit (`rv32i_hazard.v`) compares the instruction in Decode against the load in ID/EX and inserts NOP bubbles
- Branch flushing: taken branches and jumps resolve in Execute and cost 4 cycles, because the registered BRAM read and the prefetch buffer put extra wrong-path instructions in flight; `flush_delay` drains the buffer
- JALR: correctly computes `(rs1 + imm) & ~1` (distinct from JAL which uses `PC + imm`)
- Correct branch conditions: BLT/BGE/BLTU/BGEU use the SLT output bit, not the sign bit
- Byte/halfword load-store: LB, LH, LBU, LHU, SB, SH with proper sign/zero extension and byte-enable strobes
- Register file bypass: read-during-write in the same cycle returns the new value immediately

## Building and flashing

### 1. Build the firmware

You need a RISC-V GCC cross-compiler. On macOS:

bash
brew tap riscv-software-src/riscv
brew install riscv-gnu-toolchain


Then build:

bash
cd "SoC Firmware Project/firmware"
make


This produces `firmware.hex`, one 32-bit word per line. `rtl/peripherals/wb_bram.v`
loads it directly with `$readmemh`, so there is no separate step to regenerate Verilog.

### 2. Synthesize and flash

First fill in the pin assignments in `vivado/a7lite.xdc` — they are left blank
deliberately, see [vivado/README.md](SoC%20Firmware%20Project/vivado/README.md). Then:

bash
cd "SoC Firmware Project"
vivado -mode batch -source vivado/build.tcl     # -> vivado/build/soc_top.bit
vivado -mode batch -source vivado/program.tcl   # JTAG download


The shipped `firmware/firmware.hex` is the `led_test` image: it sets GPIO pins 0-5 as
outputs, drives LED0 on, and halts. A steady LED means the CPU booted and executed C.
To get the blinking demo from `main.c` instead, rebuild with `cd firmware && make`.

## Running simulations

Tests use [cocotb](https://www.cocotb.org/) with [Icarus Verilog](https://steveicarus.github.io/iverilog/).

bash
pip install cocotb
brew install icarus-verilog   # macOS

cd "SoC Firmware Project"
python sim/run_tests.py            # all 12 suites, 83 tests
python sim/run_tests.py uart bram  # just those suites

## What the demo firmware does

The prebuilt `firmware/firmware.hex` is `led_test.c` - it sets `GPIO_DIR = 0x3F`, drives
LED0 on, and spins forever, so the LED is steady rather than blinking.

`firmware/main.c`, which `make` builds, runs an LED blink loop instead:

1. Sets GPIO pins 0–5 as outputs (`GPIO_DIR = 0x3F`)
2. Waits ~100k cycles
3. Turns LED 0 on (`GPIO_OUT = 0x01`)
4. Waits ~100k cycles
5. Turns it off (`GPIO_OUT = 0x00`)
6. Repeats forever

At 50 MHz each delay loop is roughly 20 ms, so the blink lands near 25 Hz - fast enough
to read as a flicker rather than a blink. Raise the loop bound in `main.c` if you want
something clearly visible.
