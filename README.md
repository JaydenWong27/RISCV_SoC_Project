# RISC-V SoC Tang Nano 20K

A fully functional 32 bit RISCV (RV32I) System-on-Chip implemented in Verilog, targeting the Sipeed Tang Nano 20K FPGA development board (Gowin GW2AR 18 chip). The CPU executes real bare-metal C firmware and blinks the onboard LEDs.

## What this is

This project is a from-scratch RISC-V processor and SoC built entirely in synthesizable Verilog. It includes:

- A 5-stage pipelined RV32I CPU core
- Block RAM for instruction and data storage (with hardcoded firmware)
- GPIO, UART, PWM, and Timer peripherals
- A Wishbone bus interconnect connecting the CPU to all peripherals
- Bare-metal C firmware (LED blink demo)
- cocotb simulation test suites for each module

The design synthesizes and runs on real hardware using the Gowin EDA toolchain.

## CPU architecture

The CPU is a 5-stage in-order pipeline:

[ Fetch ] -> [ Decode ] -> [ Execute ] -> [ Memory ] -> [ Writeback ]

### Key features

- Prefetch buffer: absorbs the BRAM's 1-cycle registered read latency so the pipeline always sees a valid instruction
- Data forwarding: EX/MEM→EX and MEM/WB→EX paths feed the ALU directly from in-flight results, eliminating most stall cycles
- Load-use stall: 1-cycle pipeline freeze when a load result is needed by the immediately following instruction
- Memory stall: pipeline freezes while waiting for BRAM data to arrive from a load
- Hazard detection: dedicated unit (`rv32i_hazard.v`) detects load-use hazards and inserts NOP bubbles
- Branch flushing: 2-cycle flush on taken branches and jumps, extended by `flush_delay` to drain the prefetch buffer
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


This produces `firmware.hex`. Then run the converter to embed it in the RTL:

bash
python3 hex_to_bram.py firmware.hex


Copy the output into the `initial` block in `rtl/peripherals/wb_bram.v` (replacing the existing hardcoded values).

### 2. Synthesize and flash

1. Open Gowin EDA
2. Open SoC Firmware Project/SoC Firmware Project.gprj
3. Run Synthesize → Place & Route → Program Device
4. Flash the .fs bitstream to the board via USB

The default firmware blinks LED 0 on and off in a loop.

## Running simulations

Tests use [cocotb](https://www.cocotb.org/) with [Icarus Verilog](https://steveicarus.github.io/iverilog/).

bash
pip install cocotb
brew install icarus-verilog   # macOS

cd "SoC Firmware Project/sim"
make MODULE=test_core         # run CPU core tests
make MODULE=test_alu          # run ALU tests
make MODULE=test_soc          # run full SoC smoke test
# etc.

## What the demo firmware does

`firmware/main.c` runs an LED blink loop:

1. Sets GPIO pins 0–5 as outputs (`GPIO_DIR = 0x3F`)
2. Waits ~100k cycles
3. Turns LED 0 on (`GPIO_OUT = 0x01`)
4. Waits ~100k cycles
5. Turns it off (`GPIO_OUT = 0x00`)
6. Repeats forever

At 27 MHz, each delay loop is roughly 3–4 ms, giving a ~7–8 ms blink period.
