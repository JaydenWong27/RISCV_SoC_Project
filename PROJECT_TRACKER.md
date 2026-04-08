# RISC-V SoC Project Tracker
**Board:** Sipeed Tang Nano 20K (Gowin GW2AR-18)
**Goal:** Full-stack SoC — custom RV32I CPU + Wishbone bus + peripherals + bare-metal C firmware
**Timeline:** 8–12 weeks (weekends + evenings)
**Started:** March 2026

---

## Project Status: 🟡 Not Started

---

## Phases & Progress

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| Phase 1 | Environment Setup & Blink Test | ⬜ Not started | Week 1 |
| Phase 2 | RISC-V CPU Core (RV32I) | ⬜ Not started | Weeks 2–4 |
| Phase 3 | Wishbone Bus Interconnect | ⬜ Not started | Week 5 |
| Phase 4 | Custom Peripherals (UART, SPI, GPIO, PWM, Timer) | ⬜ Not started | Weeks 6–8 |
| Phase 5 | Bare-Metal Firmware (C) | ⬜ Not started | Weeks 8–10 |
| Phase 6 | Integration, Testing & Synthesis Results | ⬜ Not started | Weeks 10–12 |

---

## Current Phase: Phase 1 — Environment Setup

### To Do
- [ ] Download & install Gowin EDA (Education Edition) — https://www.gowinsemi.com
- [ ] Request free education licence (emailed after registration)
- [ ] Install RISC-V GNU toolchain (`sudo apt install gcc-riscv64-unknown-elf`)
- [ ] Install cocotb (`pip install cocotb`)
- [ ] Install Icarus Verilog (`sudo apt install iverilog`)
- [ ] Install GTKWave (`sudo apt install gtkwave`)
- [ ] Plug in Tang Nano 20K, verify USB recognition (may need BL616 driver on Windows)
- [ ] Create Gowin project: device GW2AR-18, package QFP88, speed grade C8/I7
- [ ] Write LED blink Verilog (27 MHz clock, toggle LED ~0.5s)
- [ ] Create .cst constraint file (map LED + clock pins)
- [ ] Synthesise, P&R, generate bitstream
- [ ] Flash bitstream via Gowin Programmer
- [ ] Confirm LED blinks ✅
- [ ] Initialise Git repository, push to GitHub
- [ ] Record synthesis stats: LUT count, FF count, max clock frequency

---

## Hardware Needed (Shopping List)

| Item | Details | Est. Cost |
|------|---------|-----------|
| Sipeed Tang Nano 20K | Gowin GW2AR-18, 20K LUTs | ~$25–30 USD (AliExpress) |
| USB-C cable | Programming + UART | Usually included |
| Breadboard + jumper wires | GPIO testing | ~$5–10 |
| LEDs + 330Ω resistors | 3–5 LEDs | ~$2–3 |
| USB-to-UART adapter (optional) | CP2102 or FTDI | ~$5–8 |

**Total: ~$35–50 CAD**

---

## Key Files

| File | Description |
|------|-------------|
| `RISCV_SoC_Project_Guide_Tang_Nano_20K.docx` | Full project guide (all phases, reference, pitfalls) |
| `src/core.v` | CPU core (5-stage pipeline — existing draft) |
| `src/alu.v` | ALU module (existing draft) |
| `src/regfile.v` | Register file (existing draft) |
| `src/README.MD` | Instruction set spec (32-bit custom ISA) |

---

## Memory Map (Reference)

| Address Range | Peripheral | Size |
|---------------|-----------|------|
| 0x00000000–0x00007FFF | Block RAM (instruction + data) | 32 KB |
| 0x10000000–0x1000000F | UART | 16 bytes |
| 0x10001000–0x1000100F | GPIO | 16 bytes |
| 0x10002000–0x1000200F | PWM | 16 bytes |
| 0x10003000–0x1000300F | Timer | 16 bytes |

---

## Synthesis Results Log

| Phase | LUTs | FFs | Max Freq | Notes |
|-------|------|-----|----------|-------|
| Phase 1 (blink) | — | — | — | Fill in after synthesis |
| Phase 2 (CPU only) | — | — | — | |
| Final SoC | — | — | — | |

---

## Notes & Decisions

- Using 3-stage pipeline initially (fetch, decode/execute, mem/writeback) — simpler to debug
- No M extension (no multiply/divide) in v1 — add as extension later
- No pipeline forwarding in v1 — use stalls, add forwarding as extension
- Wishbone B4 pipelined bus protocol
- Block RAM only (no SDRAM controller in v1)

---

## Session Log
_Update this when working on the project_

| Date | What was done |
|------|---------------|
| Mar 26, 2026 | Project folder created, tracker set up |

