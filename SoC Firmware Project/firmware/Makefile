CC = riscv64-unknown-elf-gcc
OBJCOPY = riscv64-unknown-elf-objcopy

CFLAGS = -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -T link.ld

all: firmware.hex

firmware.elf: crt0.S main.c link.ld hal.h
	$(CC) $(CFLAGS) crt0.S main.c -o firmware.elf

firmware.bin: firmware.elf
	$(OBJCOPY) -O binary firmware.elf firmware.bin

firmware.hex: firmware.bin bin2hex.py
	python3 bin2hex.py firmware.bin firmware.hex

clean:
	rm -f firmware.elf firmware.bin firmware.hex
