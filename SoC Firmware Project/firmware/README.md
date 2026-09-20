# LED Test Firmware

This directory contains the SoC firmware, a simple FPGA LED test, and the
helper that turns a build into the memory image the RTL loads.

## Files

- `main.c` - the default firmware: blinks LED0 via GPIO.
- `led_test.c` - simpler still: sets the first 6 GPIO pins as outputs and holds LED0 on.
- `bin2hex.py` - converts `firmware.bin` into `firmware.hex`, one 32-bit word per
  line, which `../rtl/peripherals/wb_bram.v` loads directly with `$readmemh`.
- `build_led_test.sh` - compiles `led_test.c` and regenerates `firmware.hex`.
- `hello_uart.hex` - a prebuilt image that prints "Hello from RISC-V!" over the
  UART. Handy for confirming the serial port during board bring-up: copy it over
  `firmware.hex` and rebuild the bitstream.

## Usage

Build the default firmware:

```sh
make
```

Or the LED test, from the `firmware/` directory:

```sh
sh build_led_test.sh
```

Either way the result is `firmware.hex`. There is no longer a separate step to
regenerate Verilog - `wb_bram.v` reads the hex file at elaboration time, so just
rebuild the bitstream:

```sh
cd ..
vivado -mode batch -source vivado/build.tcl
```

## Notes

- Both builds use the shared `crt0.S`, `link.ld`, and `hal.h`.
- `link.ld` describes a single 32 KB RAM region at 0x00000000, matching the
  8192-word memory in `wb_bram.v`. `crt0.S` sets the stack pointer to 0x8000,
  the top of that region.
- The LED test keeps LED0 asserted continuously, so the board should show a
  solid LED if GPIO is working.
- LED polarity is a hardware concern, not a firmware one: `soc_top` passes
  `ACTIVE_LOW_MASK` to `wb_gpio`. It is `8'h00` (active-high) for the A7-Lite.
