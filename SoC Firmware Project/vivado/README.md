# Vivado flow — MicroPhase A7-Lite (XC7A100T-2FTG256)

## Pin status

| Signal | Pin | Status |
|---|---|---|
| `clk` (50 MHz) | **N11** | verified |
| `rst` (KEY1) | **T13** | verified |
| `gpio_pins[0]` (LED1) | **P11** | verified |
| `uart_tx` | - | TODO |
| `uart_rx` | - | TODO |
| `gpio_pins[1]` (LED2) | - | TODO |
| `pwm_out` | - | TODO |

### About A7-LITE_R11.pdf

The board schematic PDF and MicroPhase's online manual both describe the
**FGG484** variant - every sheet's device symbol reads `XC7A35T-2FGG484I`, and
its ball names reach column 22 (`C22`, `V2`, `AA1`, `J19`). FTG256 is a 16x16
grid: rows A-T (no I, O, Q), columns 1-16. That documentation does not apply to
this chip and none of its pins are used.

Pin *function* is per-package, so the FGG484 roles of N11/T13/P11 say nothing
about their roles on FTG256. Vivado validates the three against
`xc7a100tftg256-2` and errors if any is not a user I/O there - so a bad pin
surfaces as a clear message, not a silent misbuild.

One fact does carry over: the board has a **CH340E USB-UART bridge**, so once
the UART balls are traced you get a console over USB with no extra hardware.

## Two tops

**`soc_top_bringup`** - the full SoC exposing *only* clk, rst and LED1. Use it
now, while the other pins are unknown:

```bash
vivado -mode batch -source vivado/build.tcl -tclargs bringup
```

This produces a real, flashable bitstream. Nothing is left for Vivado to place
on an arbitrary ball, because `uart_tx`, `pwm_out` and `gpio_pins[7:1]` are not
ports of this wrapper at all - their drivers are trimmed and no I/O buffer is
created. The LED port is named `gpio_pins[0:0]`, so the same XDC constrains it.

**`soc_top`** - the full design, the default. It will run synthesis, placement,
routing and timing with the four TODO ports unconstrained, but **refuses to
write a bitstream** until they have pins, listing which are missing. That guard
exists because with the unconstrained-I/O check downgraded, Vivado auto-places
leftover ports on arbitrary balls, and `uart_tx`/`pwm_out` are driven outputs -
one landing on something the board already drives means contention.

Override only if you have decided the placement is safe:

```tcl
set allow_unconstrained_bitstream 1   ;# top of build.tcl
```

## Build

From the `SoC Firmware Project` directory:

```bash
vivado -mode batch -source vivado/build.tcl
```

Outputs go to `vivado/build/`: `soc_top.bit`, checkpoints, and utilization,
timing and DRC reports. The script prints the worst negative slack at the end
and flags it if timing is not met at 50 MHz.

Synthesis and timing analysis work **before** the pins are filled in — only
placement needs them. So you can check elaboration, BRAM inference and 50 MHz
timing closure immediately.

## Program

```bash
vivado -mode batch -source vivado/program.tcl
```

This is a volatile JTAG download; it is lost on power cycle. To boot from the
on-board QSPI flash instead, uncomment the `CONFIG_MODE` / `BITSTREAM.*`
properties at the bottom of `a7lite.xdc` and use `write_cfgmem`.

## Board-specific settings

| Setting | Where | Value |
|---|---|---|
| Part | `build.tcl` | `xc7a100tftg256-2` |
| Clock frequency | `soc_top` parameter `CLK_FREQ_HZ` | `50_000_000` |
| Clock period | `a7lite.xdc` `create_clock` | `20.000` ns |
| UART baud | `soc_top` parameter `BAUD_RATE` | `115200` |
| LED polarity | `soc_top` → `wb_gpio` `ACTIVE_LOW_MASK` | `8'h00` (active-high) |
| Firmware image | `soc_top` parameter `INIT_FILE` | `firmware.hex` |

**If the LEDs come up inverted** — on solid when they should be off — change
`ACTIVE_LOW_MASK` in `rtl/top/soc_top.v` from `8'h00` to `8'h03` and rebuild.
The A7-Lite manual does not state LED polarity, so active-high is an assumption.

The SoC runs directly from the 50 MHz oscillator; there is no MMCM. If timing
does not close, the fallback is a Clocking Wizard MMCM stepping down to a lower
frequency, with `CLK_FREQ_HZ` updated to match so the UART divisor follows.

## Bring-up order

1. `rtl/top/board_test.v` is a CPU-less top that blinks the LEDs and sends
   `"Hi!\n"` over the UART. It reuses the module name `soc_top`, so it drops
   straight into this XDC — swap it for `rtl/top/soc_top.v` in `build.tcl`
   (never read both; they collide). Use it to confirm the pins are right.
2. Build the real `soc_top` and confirm LED0 lights.
3. Check the UART at 115200 8N1. `firmware/hello_uart.hex` prints a test string
   if you want traffic to look at.
