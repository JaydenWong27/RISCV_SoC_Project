# LED Test Firmware

This directory now contains a simple FPGA LED test and a helper script to build it.

## Files

- `led_test.c` - simple firmware that sets the first 6 GPIO pins as outputs and drives LED0 on.
- `hex_to_bram.py` - converts `firmware.hex` into `../rtl/peripherals/wb_bram.v` memory initialization.
- `build_led_test.sh` - compiles `led_test.c`, generates `firmware.hex`, and updates `wb_bram.v`.

## Usage

Run the following from the `firmware/` directory:

```sh
sh build_led_test.sh
```

Then re-run synthesis in GoWin so the updated `wb_bram.v` is included in the bitstream.

## Notes

- `build_led_test.sh` uses the existing `crt0.S`, `link.ld`, and `hal.h` files.
- The test keeps LED0 asserted continuously, so the board should show a solid LED if GPIO is working.
