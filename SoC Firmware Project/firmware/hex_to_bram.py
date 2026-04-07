#!/usr/bin/env python3
"""Convert firmware.hex to hardcoded wb_bram.v memory initialization."""

import sys

def hex_to_bram(hex_file, output_file):
    """Read hex file and generate wb_bram.v content."""
    
    # Read hex file
    memory = {}
    current_addr = 0
    with open(hex_file, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith('@'):
                # Palette format: @ADDR followed by 32-bit words
                tokens = line[1:].split()
                current_addr = int(tokens[0], 16)
                words = tokens[1:]
            else:
                words = line.split()
            for word in words:
                if len(word) == 8:  # 32-bit hex word
                    memory[current_addr] = int(word, 16)
                    current_addr += 1
    
    # Generate Verilog
    lines = [
        "module wb_bram (",
        "    input wire clk,",
        "    input wire rst,",
        "",
        "    // Port A: instruction fetch (read-only)",
        "    input wire [31:0] instr_addr,",
        "    input wire instr_we,",
        "    output reg [31:0] instr_data,",
        "",
        "    // Port B: data access (read/write, directly from CPU data bus)",
        "    input wire [31:0] wb_addr,",
        "    input wire [31:0] wb_dat_m2s,",
        "    input wire wb_cyc,",
        "    input wire wb_stb,",
        "    input wire wb_we,",
        "    input wire [3:0] wb_sel,",
        "",
        "    output reg [31:0] wb_dat_s2m,",
        "    output reg wb_ack",
        "",
        ");",
        "",
        "// Two separate single-port BRAMs avoid Gowin's unsupported DPB WRITE_MODE0=10.",
        "// Both memories boot from the same firmware image so instruction fetches and",
        "// data reads see the same initial contents.",
        "reg [31:0] mem_i [0:8191];",
        "reg [31:0] mem_d [0:8191];",
        "integer i;",
        "",
        "initial begin",
        "    // Initialize with NOPs (addi x0, x0, 0)",
        "    for (i = 0; i < 1024; i = i + 1) begin",
        "        mem_i[i] = 32'h00000013;",
        "        mem_d[i] = 32'h00000013;",
        "    end",
        "    for (i = 1024; i < 2048; i = i + 1) begin",
        "        mem_i[i] = 32'h00000013;",
        "        mem_d[i] = 32'h00000013;",
        "    end",
        "    for (i = 2048; i < 3072; i = i + 1) begin",
        "        mem_i[i] = 32'h00000013;",
        "        mem_d[i] = 32'h00000013;",
        "    end",
        "    for (i = 3072; i < 4096; i = i + 1) begin",
        "        mem_i[i] = 32'h00000013;",
        "        mem_d[i] = 32'h00000013;",
        "    end",
        "    for (i = 4096; i < 5120; i = i + 1) begin",
        "        mem_i[i] = 32'h00000013;",
        "        mem_d[i] = 32'h00000013;",
        "    end",
        "    for (i = 5120; i < 6144; i = i + 1) begin",
        "        mem_i[i] = 32'h00000013;",
        "        mem_d[i] = 32'h00000013;",
        "    end",
        "    for (i = 6144; i < 7168; i = i + 1) begin",
        "        mem_i[i] = 32'h00000013;",
        "        mem_d[i] = 32'h00000013;",
        "    end",
        "    for (i = 7168; i < 8192; i = i + 1) begin",
        "        mem_i[i] = 32'h00000013;",
        "        mem_d[i] = 32'h00000013;",
        "    end",
        "",
        "    // Load firmware from hex file",
        "",
    ]
    
    # Generate firmware initialization (up to 32-bit words)
    sorted_addrs = sorted(memory.keys())
    for addr in sorted_addrs:
        word = memory[addr]
        lines.append(f"    mem_i[{addr}] = 32'h{word:08x}; mem_d[{addr}] = 32'h{word:08x};")
    
    lines.extend([
        "end",
        "",
        "// Port A: instruction fetch",
        "always @(posedge clk) begin",
        "    instr_data <= mem_i[instr_addr[14:2]];",
        "end",
        "",
        "// Port B: data memory (read-write)",
        "always @(posedge clk) begin",
        "    if (rst) begin",
        "        wb_dat_s2m <= 0;",
        "        wb_ack <= 0;",
        "    end else begin",
        "        if (wb_cyc && wb_stb) begin",
        "            if (wb_we) begin",
        "                // Write",
        "                if (wb_sel[0]) mem_d[wb_addr[14:2]][7:0] <= wb_dat_m2s[7:0];",
        "                if (wb_sel[1]) mem_d[wb_addr[14:2]][15:8] <= wb_dat_m2s[15:8];",
        "                if (wb_sel[2]) mem_d[wb_addr[14:2]][23:16] <= wb_dat_m2s[23:16];",
        "                if (wb_sel[3]) mem_d[wb_addr[14:2]][31:24] <= wb_dat_m2s[31:24];",
        "            end else begin",
        "                // Read",
        "                wb_dat_s2m <= mem_d[wb_addr[14:2]];",
        "            end",
        "            wb_ack <= 1;",
        "        end else begin",
        "            wb_ack <= 0;",
        "        end",
        "    end",
        "end",
        "",
        "endmodule",
    ])
    
    with open(output_file, 'w') as f:
        f.write('\n'.join(lines))
    
    print(f"Generated {output_file} with {len(memory)} words of firmware")

if __name__ == '__main__':
    hex_file = 'firmware.hex'
    out_file = '../rtl/peripherals/wb_bram.v'
    hex_to_bram(hex_file, out_file)
    print(f"Updated {out_file}")
