# RISC-V SoC on FPGA

A 32-bit RISC-V (RV32I) system-on-chip built from scratch in synthesizable Verilog,
running bare-metal C on an AMD/Xilinx Artix-7 XC7A100T. No soft-core IP, no generated
blocks — the CPU, bus, and peripherals are all hand-written RTL.

**Verified on hardware:** the CPU boots from on-chip block RAM, executes compiled C,
and drives the board's LED through the Wishbone bus.

### Highlights

- **5-stage pipelined RV32I CPU** — data forwarding, load-use hazard detection with
  single-cycle stall, branch flushing, and a prefetch buffer absorbing BRAM read latency
- **Wishbone B4 interconnect** with four memory-mapped peripherals: UART, GPIO, PWM, timer
- **32 KB unified instruction/data memory** inferred as true dual-port block RAM
- **Closes timing at 50 MHz with +5.2 ns slack** (~67 MHz capable) — 2.7% LUTs,
  1.4% registers, 8 block RAMs, zero DSPs
- **83 cocotb tests across 12 suites, all passing**, plus a bare-metal C toolchain
  with custom startup code and linker script
