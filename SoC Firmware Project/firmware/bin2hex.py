#!/usr/bin/env python3
"""Convert a flat firmware binary into the hex format $readmemh expects.

Output is one 32-bit little-endian word per line, no address markers, which
rtl/peripherals/wb_bram.v loads directly via $readmemh.
"""

import sys
import struct

if len(sys.argv) != 3:
    print("Usage: python bin2hex.py input.bin output.hex")
    sys.exit(1)

input_file = sys.argv[1]
output_file = sys.argv[2]

with open(input_file, 'rb') as f:
    data = f.read()

with open(output_file, 'w') as f:
    for i in range(0, len(data), 4):
        word = data[i:i+4]
        if len(word) < 4:
            word += b'\x00' * (4 - len(word))
        # Little endian
        word_int = struct.unpack('<I', word)[0]
        f.write(f"{word_int:08X}\n")
