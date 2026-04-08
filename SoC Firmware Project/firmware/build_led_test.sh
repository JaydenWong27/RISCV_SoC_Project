#!/bin/sh
set -e

cd "$(dirname "$0")"

CC=riscv64-unknown-elf-gcc
OBJCOPY=riscv64-unknown-elf-objcopy
CFLAGS='-march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -T link.ld'

# Build the LED test firmware
$CC $CFLAGS crt0.S led_test.c -o firmware.elf
$OBJCOPY -O binary firmware.elf firmware.bin
python3 bin2hex.py firmware.bin firmware.hex
python3 hex_to_bram.py

echo "Built firmware and updated ../rtl/peripherals/wb_bram.v"