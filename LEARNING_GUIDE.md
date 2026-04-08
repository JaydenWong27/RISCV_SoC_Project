# Everything You Need to Know: RISC-V SoC on FPGA

A comprehensive, ground-up guide for Jayden. This covers every concept you'll encounter across all 6 phases of the project — from "what is an FPGA" all the way to "how does my C code run on silicon I designed."

---

## Table of Contents

1. The Big Picture — What You're Actually Building
2. FPGAs — What They Are and How They Work
3. Digital Logic Fundamentals (The Building Blocks)
4. Verilog — The Language You'll Write Everything In
5. The RISC-V Architecture
6. Building a CPU — Pipeline Concepts
7. The Wishbone Bus — How Everything Talks
8. Memory-Mapped I/O and Peripherals
9. Bare-Metal Firmware — Software on Your Own Hardware
10. The Toolchain — From Code to Blinking LEDs
11. Testing and Simulation with cocotb
12. Synthesis, Timing, and Getting It on Real Hardware
13. Common Mistakes and How to Avoid Them
14. Glossary

---

## 1. The Big Picture — What You're Actually Building

Imagine a computer. Not a laptop — the simplest possible computer. It has a processor that runs instructions, some memory to store those instructions and data, and a few peripherals it can talk to (a serial port, some LEDs, a timer). That's what you're building. From scratch. On a chip.

Here's the stack, bottom to top:

```
┌──────────────────────────────────────────────────┐
│  YOUR C FIRMWARE (main.c)                        │  ← You write this
│  "RISC-V SoC booted!\r\n"                        │
├──────────────────────────────────────────────────┤
│  HARDWARE ABSTRACTION LAYER (hal.h)              │  ← You write this
│  Memory-mapped register definitions              │
├──────────────────────────────────────────────────┤
│  RISC-V CPU CORE                                 │  ← You design this in Verilog
│  Fetches, decodes, and executes instructions     │
├──────────────────────────────────────────────────┤
│  WISHBONE BUS                                    │  ← You design this in Verilog
│  Routes CPU memory requests to the right place   │
├──────────────────────────────────────────────────┤
│  PERIPHERALS (UART, GPIO, PWM, Timer)            │  ← You design these in Verilog
│  + Block RAM (instruction & data memory)         │
├──────────────────────────────────────────────────┤
│  FPGA FABRIC (Tang Nano 20K)                     │  ← This is the physical chip
│  Configurable logic that becomes your hardware   │
└──────────────────────────────────────────────────┘
```

When this project is done, you will have:

- Designed a processor that understands RISC-V machine code
- Built a bus that lets the processor talk to peripherals
- Created peripherals (UART for serial, GPIO for LEDs, PWM, timer)
- Written C code that runs on YOUR processor and drives YOUR peripherals
- Synthesised all of this onto a real FPGA chip

Very few people at any level do this. Most students either design hardware OR write firmware. You're doing both, and connecting them together. That's what makes this project exceptional.

---

## 2. FPGAs — What They Are and How They Work

### What is an FPGA?

An FPGA (Field-Programmable Gate Array) is a chip filled with configurable logic blocks and programmable connections between them. Unlike a normal CPU (which has a fixed architecture), an FPGA can become *any* digital circuit you want.

Think of it like LEGOs for hardware. A normal CPU is a pre-built LEGO set — it comes assembled and does one specific thing. An FPGA is a giant bucket of LEGO bricks — you decide what to build.

### How FPGAs Work Internally

Inside your Tang Nano 20K (Gowin GW2AR-18), there are three main resources:

**LUTs (Look-Up Tables):** These are the basic logic elements. A 4-input LUT can implement any Boolean function of 4 variables. Your chip has 20,736 of them. When you write `assign y = a & b | c;` in Verilog, it becomes a LUT configuration.

```
         ┌─────────┐
  a ─────┤         │
  b ─────┤   LUT   ├───── y
  c ─────┤  (SRAM) │
  d ─────┤         │
         └─────────┘
```

A LUT is actually just a tiny memory (16 entries for a 4-input LUT). The inputs form the address, and the output is whatever value is stored at that address. By loading different values into the SRAM cells, the same LUT hardware can implement AND, OR, XOR, or any other combinational function.

**Flip-Flops (FFs):** These are 1-bit memory elements. Each LUT typically has one FF attached to it. FFs store state — they remember a value until the next clock edge. Your chip has 15,552 of them. Every `reg` in your Verilog that gets assigned in an `always @(posedge clk)` block becomes one or more FFs.

```
         ┌─────┐
  D ─────┤     │
         │ FF  ├───── Q (stored value)
  clk ───┤     │
         └─────┘
```

On every rising edge of `clk`, the FF captures whatever value is on its D input and holds it at Q until the next rising edge. This is the fundamental mechanism of all sequential (stateful) digital circuits.

**Block RAM (BRAM):** Dedicated memory blocks, much denser than using LUTs as memory. Your chip's BRAM will store your program instructions and data. The GW2AR-18 has enough BRAM for 32KB, which is plenty for bare-metal firmware.

### What "Synthesis" Means

When you write Verilog, you're describing a digital circuit. The FPGA tools need to convert that description into a configuration for the actual chip. This happens in stages:

1. **Synthesis:** Your Verilog is converted into a netlist — a description of logic gates and flip-flops and the wires between them. This is where `a & b` becomes "configure this LUT to implement AND."

2. **Place and Route (P&R):** The netlist is mapped onto the physical FPGA. Each gate gets assigned to a specific LUT location on the chip, and the wires between them get routed through the chip's programmable interconnect. This is like figuring out which LEGO bricks go where and how to connect them.

3. **Bitstream Generation:** The final placement and routing is encoded into a binary file (the bitstream) that configures the FPGA. When you flash this file to the chip, every LUT, FF, and interconnect switch gets set to the right position.

4. **Programming:** The bitstream is loaded onto the FPGA via USB. The chip is now your custom hardware.

### Your Board: Tang Nano 20K

The Sipeed Tang Nano 20K is a small, cheap FPGA development board. Key specs:

- **FPGA:** Gowin GW2AR-18 — 20,736 LUTs, 15,552 FFs
- **Clock:** 27 MHz on-board crystal oscillator
- **Memory:** 64Mbit (8MB) SDRAM on-board (you won't use this in v1 — you'll use BRAM)
- **I/O:** USB-C for programming and UART, HDMI connector, GPIO pins
- **Cost:** ~$25-30 USD

You'll use the Gowin EDA toolchain (free Education Edition) to synthesise, place-and-route, and program the chip.

---

## 3. Digital Logic Fundamentals (The Building Blocks)

Before you can design a CPU, you need to be comfortable with the building blocks of digital circuits. If you've taken a digital logic course or worked with UWASIC, some of this will be review.

### Combinational vs Sequential Logic

**Combinational logic** has outputs that depend only on the current inputs. No memory, no state. Think of it like a math function — same inputs always give same outputs. Examples: AND gate, multiplexer, adder, ALU.

**Sequential logic** has outputs that depend on current inputs AND previous state. It has memory (flip-flops). Think of it like a state machine — the output depends on where you are, not just what the input is. Examples: counters, registers, shift registers, FSMs, your entire CPU.

### Essential Building Blocks

**Multiplexer (Mux):** Selects one of several inputs based on a select signal. You'll use these constantly — the bus interconnect is basically a big mux, and the ALU needs one to select which operation result to output.

```
      sel
       │
  ┌────┴────┐
  │   MUX   │
  │ 0  1  2 │
  └────┬────┘
       │
      out

  If sel=0, out=input0
  If sel=1, out=input1
  ...etc
```

In Verilog, a mux is often a `case` statement or a ternary operator:
```verilog
assign out = (sel == 2'b00) ? a :
             (sel == 2'b01) ? b :
             (sel == 2'b10) ? c : d;
```

**Decoder:** Converts a binary-encoded input into a one-hot output (only one output is active at a time). Your bus interconnect uses address decoding to select which peripheral to talk to.

```
  addr[1:0]        enables
   00        →    peripheral_0_sel = 1
   01        →    peripheral_1_sel = 1
   10        →    peripheral_2_sel = 1
   11        →    peripheral_3_sel = 1
```

**Register:** A group of flip-flops that stores a multi-bit value. Your CPU has 32 registers, each 32 bits wide. Registers are written on a clock edge and hold their value until the next write.

```verilog
always @(posedge clk) begin
    if (write_enable)
        register <= data_in;  // Captures data_in on rising clock edge
end
// register holds its value at all other times
```

**Adder:** Adds two binary numbers. The CPU's ALU needs one for ADD instructions, and the program counter needs one to increment by 4 each cycle. Hardware adders are built from chains of full-adder cells, but in Verilog you just write `a + b` and the synthesis tool builds the adder for you.

**Shift Register:** A chain of flip-flops where data shifts one position per clock cycle. The UART transmitter is essentially a shift register — it loads a byte and shifts it out one bit at a time.

**Finite State Machine (FSM):** A circuit that transitions between states based on inputs. Many of your peripherals and parts of the CPU will be implemented as FSMs. For example, the UART transmitter has states like IDLE, START_BIT, DATA_BITS, STOP_BIT.

```
  IDLE ──(start)──→ START_BIT ──(1 bit time)──→ DATA[0] ──→ ... ──→ STOP_BIT ──→ IDLE
```

In Verilog, FSMs look like:
```verilog
localparam IDLE = 2'b00, SENDING = 2'b01, DONE = 2'b10;
reg [1:0] state;

always @(posedge clk) begin
    case (state)
        IDLE:    if (start) state <= SENDING;
        SENDING: if (bit_count == 8) state <= DONE;
        DONE:    state <= IDLE;
    endcase
end
```

### Binary Number Representation

RISC-V is a 32-bit architecture, so you'll work with 32-bit numbers constantly.

**Unsigned:** Straightforward binary. 32 bits can represent 0 to 4,294,967,295 (2^32 - 1).

**Signed (Two's Complement):** The most significant bit (bit 31) is the sign bit. If it's 1, the number is negative. To negate a number, invert all bits and add 1. 32 bits represent -2,147,483,648 to +2,147,483,647.

```
 0000...0001 = +1
 0000...0000 =  0
 1111...1111 = -1
 1111...1110 = -2
 1000...0000 = -2,147,483,648 (most negative)
```

**Sign extension** is critical in RISC-V. When a 12-bit immediate needs to be used as a 32-bit value, you replicate the sign bit (bit 11) into bits 12-31. Getting this wrong is one of the most common CPU bugs:

```
12-bit: 1111_1111_1010  (= -6 in 12-bit two's complement)
32-bit: 1111_1111_1111_1111_1111_1111_1111_1010  (= -6, correct)
              ^^^^^^^^^^^^^^^^^^^^ sign extended
```

In Verilog, sign extension happens automatically with `$signed()`, or you can do it manually:
```verilog
wire [31:0] imm_extended = {{20{imm[11]}}, imm[11:0]};
//                          ^^^^^^^^^^^^^ replicate bit 11 twenty times
```

### Hexadecimal

You'll see hex everywhere in this project. It's just base-16:

```
Binary:  1010_1111_0000_0011
Hex:     A     F    0    3    →  0xAF03
```

Memory addresses are in hex (0x10000000), instruction encodings are in hex (0x00000013 is a NOP), and your constraint file will use hex for pin assignments. Get comfortable reading and converting between binary and hex mentally.

---

## 4. Verilog — The Language You'll Write Everything In

Verilog is a hardware description language (HDL). It doesn't run sequentially like C — it describes hardware that operates in parallel. This is the most important mindset shift for software people.

### The Key Mental Model

In C, statements execute one after another:
```c
a = 1;
b = 2;
c = a + b;  // c is 3
```

In Verilog, everything described in the same module exists simultaneously as physical hardware:
```verilog
assign a = 1;
assign b = 2;
assign c = a + b;  // These are three parallel pieces of hardware, not sequential statements
```

Those three `assign` statements create three independent pieces of hardware (two constant drivers and an adder) that all operate at the same time, continuously. There is no "first a is set, then b, then c is computed." They all exist and operate simultaneously.

### Module Structure

Everything in Verilog is a **module** — a self-contained block of hardware with inputs and outputs. Think of it like a chip with pins.

```verilog
module my_adder (
    input  wire [31:0] a,      // 32-bit input
    input  wire [31:0] b,      // 32-bit input
    output wire [31:0] sum     // 32-bit output
);

    assign sum = a + b;        // Continuous assignment — always computing

endmodule
```

You instantiate modules inside other modules (like plugging chips onto a circuit board):
```verilog
module top (
    input wire clk,
    input wire [31:0] x, y,
    output wire [31:0] result
);

    my_adder adder_instance (
        .a(x),
        .b(y),
        .sum(result)
    );

endmodule
```

### Wire vs Reg

This is the most confusing thing for beginners. Despite the names, `wire` and `reg` do NOT mean "wire" and "register" in the hardware sense.

- **`wire`**: A signal driven by a continuous assignment (`assign`) or a module output. Think "connection."
- **`reg`**: A signal driven inside an `always` block. It MIGHT become a flip-flop (register), or it might just be combinational logic. The name is misleading.

A `reg` becomes a real hardware register (flip-flop) only when it's assigned inside an `always @(posedge clk)` block. If it's assigned inside an `always @(*)` block, it's just combinational logic that the tool needs to use `reg` syntax for.

```verilog
// This creates a FLIP-FLOP (real register):
reg [7:0] counter;
always @(posedge clk) begin
    counter <= counter + 1;  // Updates on clock edge → hardware register
end

// This creates COMBINATIONAL LOGIC (no register, despite "reg"):
reg [7:0] alu_result;
always @(*) begin
    case (op)
        2'b00: alu_result = a + b;   // Just a mux + adder, no storage
        2'b01: alu_result = a - b;
        2'b10: alu_result = a & b;
        2'b11: alu_result = a | b;
    endcase
end
```

### Blocking vs Non-Blocking Assignment

This is critical and gets people constantly:

- **`=` (blocking):** Use in combinational logic (`always @(*)`). The assignment happens "immediately" (for simulation ordering purposes).
- **`<=` (non-blocking):** Use in sequential logic (`always @(posedge clk)`). All assignments happen "simultaneously" at the clock edge.

```verilog
// COMBINATIONAL — use =
always @(*) begin
    temp = a + b;       // blocking: temp gets value immediately
    result = temp * 2;  // uses the updated temp
end

// SEQUENTIAL — use <=
always @(posedge clk) begin
    q1 <= d;     // All three happen at the same time
    q2 <= q1;    // q2 gets the OLD value of q1, not the one just assigned
    q3 <= q2;    // This creates a 3-stage shift register
end
```

If you use `=` in sequential blocks, you'll get simulation mismatches with real hardware. If you use `<=` in combinational blocks, you'll get latches (which are almost always bugs). The rule is simple: `=` with `always @(*)`, `<=` with `always @(posedge clk)`.

### Parameterised Modules

You can make modules configurable using parameters:
```verilog
module register #(
    parameter WIDTH = 32
)(
    input  wire             clk,
    input  wire             write_en,
    input  wire [WIDTH-1:0] data_in,
    output reg  [WIDTH-1:0] data_out
);
    always @(posedge clk) begin
        if (write_en)
            data_out <= data_in;
    end
endmodule
```

### Common Patterns You'll Use

**Counter:**
```verilog
reg [31:0] count;
always @(posedge clk) begin
    if (reset)
        count <= 0;
    else if (enable)
        count <= count + 1;
end
```

**Edge detection (useful for UART, etc.):**
```verilog
reg signal_prev;
wire signal_rising_edge;

always @(posedge clk)
    signal_prev <= signal;

assign signal_rising_edge = signal & ~signal_prev;
```

**Memory (Block RAM):**
```verilog
reg [31:0] mem [0:8191];  // 8192 words × 32 bits = 32KB

// Read
assign read_data = mem[addr[14:2]];  // Word-aligned: drop lower 2 bits

// Write
always @(posedge clk) begin
    if (write_en)
        mem[addr[14:2]] <= write_data;
end

// Load initial contents from hex file
initial $readmemh("firmware.hex", mem);
```

---

## 5. The RISC-V Architecture

### What is RISC-V?

RISC-V (pronounced "risk five") is an open-source instruction set architecture (ISA). An ISA defines the contract between software and hardware — it specifies exactly what instructions the CPU understands, what registers are available, and how memory is accessed.

RISC-V is modular. The base ISA is called **RV32I** — 32-bit integer instructions. That's what you're implementing. It has exactly 40 instructions. That's it. The full x86 ISA has thousands. This is why RISC-V is ideal for learning and for building from scratch.

### The Register File

RV32I has 32 general-purpose registers, each 32 bits wide. They're named x0 through x31:

```
x0  (zero) — Hardwired to 0. Writes are ignored. ALWAYS reads as 0.
x1  (ra)   — Return address (convention, not enforced by hardware)
x2  (sp)   — Stack pointer (convention)
x3  (gp)   — Global pointer (convention)
x4  (tp)   — Thread pointer (convention)
x5-x7      — Temporaries
x8-x9      — Saved registers
x10-x17    — Function arguments / return values
x18-x27    — More saved registers
x28-x31    — More temporaries
```

The names in parentheses (ra, sp, etc.) are just conventions used by the compiler and ABI. Your hardware doesn't care about these names — it just sees register numbers 0-31. The only special one is **x0, which MUST always be zero**. This is the most commonly screwed up thing in RISC-V implementations.

Your register file module needs:
- 2 read ports (to read rs1 and rs2 simultaneously in one cycle)
- 1 write port (to write the result to rd)
- x0 hardwired to zero

### The Program Counter (PC)

The PC is a special register (not part of the x0-x31 register file) that holds the address of the current instruction. Normally it increments by 4 each cycle (because each instruction is exactly 4 bytes = 32 bits). Branches and jumps change the PC to a different address.

### Instruction Formats

Every RISC-V instruction is exactly 32 bits. The bits are arranged in specific formats. Understanding these formats is essential because your decoder module must extract the right fields from each format.

There are 6 formats:

```
R-type (register-register):
 31      25 24   20 19   15 14  12 11    7 6      0
┌─────────┬───────┬───────┬──────┬───────┬────────┐
│  funct7  │  rs2  │  rs1  │funct3│  rd   │ opcode │
└─────────┴───────┴───────┴──────┴───────┴────────┘
  7 bits    5 bits  5 bits  3 bits 5 bits  7 bits

I-type (immediate):
 31               20 19   15 14  12 11    7 6      0
┌──────────────────┬───────┬──────┬───────┬────────┐
│    imm[11:0]      │  rs1  │funct3│  rd   │ opcode │
└──────────────────┴───────┴──────┴───────┴────────┘
  12 bits            5 bits  3 bits 5 bits  7 bits

S-type (store):
 31      25 24   20 19   15 14  12 11    7 6      0
┌─────────┬───────┬───────┬──────┬───────┬────────┐
│imm[11:5]│  rs2  │  rs1  │funct3│imm[4:0]│ opcode │
└─────────┴───────┴───────┴──────┴───────┴────────┘
  7 bits    5 bits  5 bits  3 bits 5 bits  7 bits

B-type (branch):
 31    30    25 24   20 19   15 14  12 11   8  7   6      0
┌────┬────────┬───────┬───────┬──────┬──────┬───┬────────┐
│[12]│[10:5]  │  rs2  │  rs1  │funct3│[4:1] │[11]│ opcode │
└────┴────────┴───────┴───────┴──────┴──────┴───┴────────┘

U-type (upper immediate):
 31                              12 11    7 6      0
┌──────────────────────────────────┬───────┬────────┐
│          imm[31:12]               │  rd   │ opcode │
└──────────────────────────────────┴───────┴────────┘
  20 bits                           5 bits  7 bits

J-type (jump):
 31    30         21 20   19          12 11    7 6      0
┌────┬────────────┬────┬──────────────┬───────┬────────┐
│[20]│  [10:1]    │[11]│  [19:12]     │  rd   │ opcode │
└────┴────────────┴────┴──────────────┴───────┴────────┘
```

Notice how the immediate bits are scattered around in B-type and J-type. This looks insane, but it's actually deliberate — the RISC-V designers arranged the bits so that the sign bit is always in bit 31, and as many other bits as possible stay in the same position across formats. This makes the decoder simpler.

Your decoder module's job is to look at the opcode (bits 6:0) to determine the format, then extract the right fields.

### The Instructions — What Each One Does

Let's go through every instruction you'll implement, grouped by type:

**Arithmetic (R-type and I-type):**
```
ADD  rd, rs1, rs2     — rd = rs1 + rs2
SUB  rd, rs1, rs2     — rd = rs1 - rs2
ADDI rd, rs1, imm     — rd = rs1 + sign_extend(imm)
```
Note: there's no SUBI instruction. Use ADDI with a negative immediate.

**Logical (R-type and I-type):**
```
AND  rd, rs1, rs2     — rd = rs1 & rs2
OR   rd, rs1, rs2     — rd = rs1 | rs2
XOR  rd, rs1, rs2     — rd = rs1 ^ rs2
ANDI rd, rs1, imm     — rd = rs1 & sign_extend(imm)
ORI  rd, rs1, imm     — rd = rs1 | sign_extend(imm)
XORI rd, rs1, imm     — rd = rs1 ^ sign_extend(imm)
```

**Shifts (R-type and I-type):**
```
SLL  rd, rs1, rs2     — rd = rs1 << rs2[4:0]    (logical left shift)
SRL  rd, rs1, rs2     — rd = rs1 >> rs2[4:0]    (logical right shift, zero-fill)
SRA  rd, rs1, rs2     — rd = rs1 >>> rs2[4:0]   (arithmetic right shift, sign-fill)
SLLI rd, rs1, shamt   — rd = rs1 << shamt
SRLI rd, rs1, shamt   — rd = rs1 >> shamt
SRAI rd, rs1, shamt   — rd = rs1 >>> shamt
```

The difference between SRL and SRA is critical: SRL fills vacated bits with 0, SRA fills with the sign bit. For positive numbers they're identical; for negative numbers they differ.

**Comparison (R-type and I-type):**
```
SLT   rd, rs1, rs2    — rd = (rs1 < rs2) ? 1 : 0   (signed comparison)
SLTU  rd, rs1, rs2    — rd = (rs1 < rs2) ? 1 : 0   (unsigned comparison)
SLTI  rd, rs1, imm    — rd = (rs1 < sign_extend(imm)) ? 1 : 0  (signed)
SLTIU rd, rs1, imm    — rd = (rs1 < sign_extend(imm)) ? 1 : 0  (unsigned)
```

**Loads (I-type) — Read from memory:**
```
LW   rd, offset(rs1)  — rd = Memory[rs1 + offset]           (load 32-bit word)
LH   rd, offset(rs1)  — rd = sign_extend(Memory16[rs1+off]) (load 16-bit, sign extend)
LHU  rd, offset(rs1)  — rd = zero_extend(Memory16[rs1+off]) (load 16-bit, zero extend)
LB   rd, offset(rs1)  — rd = sign_extend(Memory8[rs1+off])  (load 8-bit, sign extend)
LBU  rd, offset(rs1)  — rd = zero_extend(Memory8[rs1+off])  (load 8-bit, zero extend)
```

**Stores (S-type) — Write to memory:**
```
SW   rs2, offset(rs1) — Memory[rs1 + offset] = rs2          (store 32-bit word)
SH   rs2, offset(rs1) — Memory16[rs1 + offset] = rs2[15:0]  (store lower 16 bits)
SB   rs2, offset(rs1) — Memory8[rs1 + offset] = rs2[7:0]    (store lower 8 bits)
```

Note: loads write to rd, but stores don't write to any register — they write to memory.

**Branches (B-type) — Conditional jumps:**
```
BEQ  rs1, rs2, offset — if (rs1 == rs2) PC += offset
BNE  rs1, rs2, offset — if (rs1 != rs2) PC += offset
BLT  rs1, rs2, offset — if (rs1 <  rs2) PC += offset  (signed)
BGE  rs1, rs2, offset — if (rs1 >= rs2) PC += offset  (signed)
BLTU rs1, rs2, offset — if (rs1 <  rs2) PC += offset  (unsigned)
BGEU rs1, rs2, offset — if (rs1 >= rs2) PC += offset  (unsigned)
```

The offset is relative to the branch instruction's PC, NOT PC+4. This is a common bug source.

**Upper Immediate (U-type):**
```
LUI   rd, imm         — rd = imm << 12  (load upper 20 bits, lower 12 bits = 0)
AUIPC rd, imm         — rd = PC + (imm << 12)
```

LUI is used to build large constants. Since immediates are only 12 bits in I-type, you need LUI + ADDI to create a full 32-bit value:
```
LUI  x1, 0x12345      // x1 = 0x12345000
ADDI x1, x1, 0x678    // x1 = 0x12345678
```

**Jumps (J-type and I-type):**
```
JAL  rd, offset        — rd = PC + 4; PC += offset  (jump and link)
JALR rd, rs1, offset   — rd = PC + 4; PC = (rs1 + offset) & ~1  (indirect jump)
```

JAL saves the return address in rd, then jumps. This is how function calls work: `JAL ra, function_offset` jumps to the function and stores the return address in ra (x1). The function returns with `JALR zero, ra, 0` (jump to address in ra, discard return address by writing to x0).

### How an Instruction Actually Executes

Let's trace ADD x3, x1, x2 through your CPU:

1. **Fetch:** The CPU reads the instruction from memory at the address in the PC. The 32-bit instruction word comes back. PC increments by 4.

2. **Decode:** The decoder examines bits 6:0 (opcode = 0110011 → R-type arithmetic). It extracts rs1=x1, rs2=x2, rd=x3, funct3=000, funct7=0000000. The combination of funct3 and funct7 tells the ALU to do ADD.

3. **Execute:** The register file outputs the values of x1 and x2. The ALU adds them.

4. **Writeback:** The ALU result is written back to x3 in the register file.

For a load instruction like LW x5, 8(x1), it's different:

1. **Fetch:** Read instruction, increment PC.
2. **Decode:** Opcode says load. Extract rs1=x1, rd=x5, offset=8.
3. **Execute:** ALU computes address = x1 + 8.
4. **Memory:** Send address to memory via the Wishbone bus. Memory returns the 32-bit word at that address.
5. **Writeback:** The memory data (not ALU result) is written to x5.

---

## 6. Building a CPU — Pipeline Concepts

### Why Pipeline?

If every instruction had to complete all stages before the next one starts, the CPU would be slow. Pipelining lets you overlap instructions — while one instruction is in the Execute stage, the next one is being Decoded, and the one after that is being Fetched.

Think of it like a laundry analogy: instead of waiting for the washer, dryer, and folding to complete for one load before starting the next, you start a new load in the washer as soon as the first load moves to the dryer.

### Your 3-Stage Pipeline

The project guide recommends starting with 3 stages:

```
Clock cycle:  1    2    3    4    5    6    7
Instr 1:     [F]  [EX] [MW]
Instr 2:          [F]  [EX] [MW]
Instr 3:               [F]  [EX] [MW]
Instr 4:                    [F]  [EX] [MW]

F  = Fetch (read instruction from memory)
EX = Decode + Execute (decode instruction, read registers, run ALU)
MW = Memory + Writeback (memory access if needed, write result to register)
```

Each stage takes one clock cycle. After the pipeline is full (cycle 3 onward), you complete one instruction per cycle.

Between stages, you need **pipeline registers** — flip-flops that hold the intermediate results from one stage to pass to the next:

```
        ┌──────┐    ┌────────────┐    ┌──────────────┐
  ──→   │FETCH │ ──→│  IF/EX Reg │ ──→│   EXECUTE    │ ──→ ...
        │      │    │(holds instr│    │(decode + ALU)│
        └──────┘    │ and PC)    │    └──────────────┘
                    └────────────┘
```

### Pipeline Hazards

Hazards are situations where the pipeline can't proceed normally.

**Data Hazard:** One instruction needs the result of a previous instruction that hasn't written back yet.

```
ADD x1, x2, x3    // Writes to x1 in MW stage
SUB x4, x1, x5    // Needs x1 in EX stage — but x1 isn't written yet!
```

The simplest solution (which your guide recommends for v1): **stall** the pipeline. Insert a "bubble" (one wasted cycle) so the first instruction has time to write back before the second reads the register.

```
Clock:  1    2    3    4    5    6
ADD:   [F]  [EX] [MW]
SUB:        [F]  [--] [EX] [MW]     ← stalled for 1 cycle
                  ^bubble
```

The more advanced solution (an extension for later) is **data forwarding** — routing the ALU result directly back to the EX stage input without waiting for writeback:

```
ADD:   [F]  [EX] [MW]
              │
              └──→ Forward ALU result directly
              │
SUB:        [F]  [EX] [MW]          ← no stall needed
```

**Control Hazard:** A branch instruction changes the PC, but we've already fetched the next instruction assuming no branch.

```
BEQ x1, x2, target    // We don't know if branch is taken until EX stage
next_instr:            // Already fetched — but might be wrong!
```

Solution: when a branch is taken, **flush** the instruction that was fetched after the branch (replace it with a NOP/bubble). This costs one cycle per taken branch. More advanced CPUs use branch prediction, but that's overkill for this project.

**Structural Hazard:** Two stages need the same hardware resource at the same time. Example: if instruction fetch and data load both need to access the same memory port. Solution: separate instruction and data memory (Harvard architecture) or use dual-port memory. The Wishbone bus approach naturally handles this since instruction and data accesses go through the bus.

### Implementing Hazard Detection

Your CPU needs a small piece of logic that checks whether the destination register of the instruction in the EX or MW stage matches a source register of the instruction being decoded. If so, it asserts a stall signal:

```verilog
wire data_hazard = (ex_rd != 0) && (ex_reg_write) &&
                   ((ex_rd == id_rs1) || (ex_rd == id_rs2));

wire stall = data_hazard;
```

When `stall` is asserted:
- The PC doesn't increment (same instruction fetched again next cycle)
- The IF/EX pipeline register doesn't update (same instruction decoded again)
- A NOP is inserted into the EX stage

---

## 7. The Wishbone Bus — How Everything Talks

### What is a Bus?

In a computer, the CPU needs to talk to memory and peripherals. A bus is the shared communication infrastructure that connects them. Think of it like a highway system — the CPU is a driver, memory and peripherals are destinations, and the bus protocol is the traffic rules.

### Why Wishbone?

Wishbone is a simple, open-source bus protocol. It's much simpler than alternatives like AXI (used in ARM systems) while teaching you the same concepts. Wishbone is common in open-source FPGA projects and is a recognized keyword on resumes.

### Bus Topology

Your SoC uses a **single-master** topology:

```
                      ┌──────────────┐
                      │  RISC-V CPU  │
                      │   (Master)   │
                      └──────┬───────┘
                             │
                    ┌────────┴────────┐
                    │  INTERCONNECT   │
                    │ (Address Decoder│
                    │  + Mux)        │
                    └┬──┬──┬──┬──┬───┘
                     │  │  │  │  │
              ┌──────┘  │  │  │  └──────┐
              │    ┌────┘  │  └────┐    │
              ▼    ▼       ▼       ▼    ▼
           ┌─────┐┌─────┐┌─────┐┌─────┐┌─────┐
           │ RAM ││UART ││GPIO ││ PWM ││Timer│
           │Slave││Slave││Slave││Slave││Slave│
           └─────┘└─────┘└─────┘└─────┘└─────┘
```

The CPU is the only master (the only thing that initiates transactions). All peripherals are slaves (they respond to the master's requests).

### The Wishbone Signals

These are the wires that connect master to slave:

```
Master → Slave:
  wb_cyc       Bus cycle active (held high during entire transaction)
  wb_stb       Strobe — this specific transfer is valid
  wb_we        Write enable: 1 = write, 0 = read
  wb_addr[31:0]   Address being accessed
  wb_dat_m2s[31:0]   Data from master to slave (for writes)
  wb_sel[3:0]  Byte select (which bytes in the 32-bit word are active)

Slave → Master:
  wb_dat_s2m[31:0]   Data from slave to master (for reads)
  wb_ack       Acknowledge — slave has completed the transfer
  wb_err       Error — invalid access (optional)
```

### How a Transaction Works

**Read transaction (CPU reads from UART status register):**

```
Clock:        1        2        3
            ┌────┐   ┌────┐   ┌────┐
clk     ────┘    └───┘    └───┘    └──

wb_cyc  ────────────────────────┐
                                └─────  (drops after ack)
wb_stb  ────────────────────────┐
                                └─────
wb_we   ─── LOW ──────────────────────  (it's a read)
wb_addr ─── 0x10000008 ──────────────  (UART status register)

wb_dat_s2m  XXXX     ── 0x00000002 ──  (UART says: RX data available)
wb_ack  ─────────────────┐
                          └───────────  (slave responds in cycle 2)
```

The CPU asserts cyc, stb, and the address. The slave sees its address, prepares the data, and asserts ack. The CPU captures the data and releases cyc/stb.

**Write transaction (CPU writes to GPIO output register):**

Same thing, but wb_we is HIGH and the CPU puts the data on wb_dat_m2s.

### The Interconnect (Address Decoder)

The interconnect is the "traffic cop" that looks at the address and routes the transaction to the right slave. It's surprisingly simple:

```verilog
// Address decoding logic
wire sel_ram  = (wb_addr[31:28] == 4'h0);                              // 0x0000_xxxx
wire sel_uart = (wb_addr[31:28] == 4'h1) && (wb_addr[15:12] == 4'h0); // 0x1000_0xxx
wire sel_gpio = (wb_addr[31:28] == 4'h1) && (wb_addr[15:12] == 4'h1); // 0x1000_1xxx
wire sel_pwm  = (wb_addr[31:28] == 4'h1) && (wb_addr[15:12] == 4'h2); // 0x1000_2xxx
wire sel_timer= (wb_addr[31:28] == 4'h1) && (wb_addr[15:12] == 4'h3); // 0x1000_3xxx

// Route stb to the selected slave only
assign ram_stb   = wb_stb & sel_ram;
assign uart_stb  = wb_stb & sel_uart;
// ...etc

// Mux read data and ack back from the selected slave
assign wb_dat_s2m = sel_ram  ? ram_dat  :
                    sel_uart ? uart_dat :
                    sel_gpio ? gpio_dat :
                    sel_pwm  ? pwm_dat  :
                    sel_timer? timer_dat : 32'h0;

assign wb_ack = (sel_ram & ram_ack) | (sel_uart & uart_ack) | ...;
```

That's the entire interconnect. It looks at a few address bits, selects the right slave, and muxes the response back. Because there's only one master, there's no arbitration needed.

---

## 8. Memory-Mapped I/O and Peripherals

### What is Memory-Mapped I/O?

In your SoC, peripherals don't have special instructions. The CPU talks to them the same way it talks to memory — using load and store instructions. Each peripheral has a few **registers** (not CPU registers — hardware configuration/status registers) that are mapped to specific memory addresses.

When the firmware writes to address 0x10000000, the CPU thinks it's writing to memory. But the bus interconnect routes that address to the UART, which interprets the written value as "transmit this byte." This is memory-mapped I/O.

```
From the CPU's perspective, it's all just memory:

0x00000000 ┌──────────┐
           │          │  ← Real memory (Block RAM)
           │   RAM    │     Store instructions + data here
           │          │
0x00007FFF └──────────┘

0x10000000 ┌──────────┐
           │   UART   │  ← Not memory! UART hardware registers.
           │ TX,RX,   │     Writing to 0x10000000 sends a byte out the serial port.
           │ STAT,CTL │     Reading 0x10000008 tells you if data arrived.
0x1000000F └──────────┘

0x10001000 ┌──────────┐
           │   GPIO   │  ← Not memory! GPIO hardware registers.
           │ DIR,OUT, │     Writing to 0x10001004 turns LEDs on/off.
           │ IN       │
0x1000100F └──────────┘
```

### How a Peripheral Works Internally

Every Wishbone slave peripheral follows the same pattern:

1. It has a few internal registers (configuration, status, data)
2. When the bus strobe (stb) is asserted with its address range, it responds
3. For writes: it latches the incoming data into the appropriate register
4. For reads: it puts the appropriate register value on the data bus
5. It asserts ack to signal the transaction is complete

Here's a simplified GPIO peripheral to show the pattern:

```verilog
module wb_gpio (
    input  wire        clk,
    input  wire        rst,
    // Wishbone slave interface
    input  wire        wb_stb,
    input  wire        wb_we,
    input  wire [3:0]  wb_addr,  // Only need lower bits (within 16-byte range)
    input  wire [31:0] wb_dat_i,
    output reg  [31:0] wb_dat_o,
    output reg         wb_ack,
    // External GPIO pins
    output wire [7:0]  gpio_out,
    input  wire [7:0]  gpio_in
);

    reg [7:0] direction;  // 1=output, 0=input
    reg [7:0] output_reg;

    // Wishbone write
    always @(posedge clk) begin
        if (rst) begin
            direction  <= 8'h00;
            output_reg <= 8'h00;
        end else if (wb_stb && wb_we) begin
            case (wb_addr[3:2])
                2'b00: direction  <= wb_dat_i[7:0];  // Offset 0x00
                2'b01: output_reg <= wb_dat_i[7:0];  // Offset 0x04
                // 2'b10: input register — read only, ignore writes
            endcase
        end
    end

    // Wishbone read
    always @(*) begin
        case (wb_addr[3:2])
            2'b00: wb_dat_o = {24'b0, direction};
            2'b01: wb_dat_o = {24'b0, output_reg};
            2'b10: wb_dat_o = {24'b0, gpio_in};
            default: wb_dat_o = 32'h0;
        endcase
    end

    // Drive output pins (only where direction = output)
    assign gpio_out = output_reg & direction;

    // Acknowledge immediately (combinational ack)
    always @(posedge clk)
        wb_ack <= wb_stb & ~wb_ack;  // One-cycle registered ack

endmodule
```

### The UART — Your Most Complex Peripheral

The UART (Universal Asynchronous Receiver/Transmitter) converts parallel data (8-bit bytes from the bus) into serial data (one bit at a time on a wire) and vice versa. It's how your SoC talks to a PC terminal.

**Serial protocol (115200 baud, 8N1):**

```
Idle (high)
    │    ┌──┐┌──┐┌──┐┌──┐┌──┐┌──┐┌──┐┌──┐┌──┐┌──┐
    ▼    │S ││D0││D1││D2││D3││D4││D5││D6││D7││ST│  Idle (high)
─────────┘  └┘  └┘  └┘  └┘  └┘  └┘  └┘  └┘  └┘  └──────────

S  = Start bit (always LOW) — signals beginning of byte
D0-D7 = Data bits (LSB first)
ST = Stop bit (always HIGH) — signals end of byte

Each bit lasts 1/115200 seconds ≈ 8.68 microseconds
At 27 MHz clock: 27,000,000 / 115,200 = 234 clock cycles per bit
```

The transmitter is a state machine that loads a byte, sends a start bit (low), shifts out 8 data bits LSB first, then sends a stop bit (high). A counter divides the 27 MHz clock down to the baud rate.

The receiver samples the incoming signal. When it detects the start bit (falling edge while idle), it waits half a bit period to sample in the middle of each bit, then samples 8 data bits and the stop bit. 16x oversampling and majority voting improve noise immunity.

### The PWM Generator

PWM (Pulse Width Modulation) creates a square wave with a controllable duty cycle. It's used for LED dimming, motor control, audio, etc.

```
Period = 1000 clock cycles, Duty = 300

     300 cycles          700 cycles
    ┌──────────┐                              ┌──────────┐
    │          │                              │          │
────┘          └──────────────────────────────┘          └───

The output is HIGH for (duty/period) fraction of the time.
300/1000 = 30% duty cycle
```

Implementation: a counter counts from 0 to PERIOD-1. The output is HIGH when counter < DUTY, LOW otherwise. That's it — maybe 15 lines of Verilog.

### The Timer

The timer is a counter that increments at a configurable rate (set by the prescaler). It's used for time measurement, delays, and periodic interrupts.

```
27 MHz clock, prescaler = 26999 → timer increments every 27000 cycles = 1ms

When COUNT reaches COMPARE value → interrupt flag is set (if enabled)
```

---

## 9. Bare-Metal Firmware — Software on Your Own Hardware

### What is "Bare-Metal"?

"Bare metal" means there's no operating system. Your C code runs directly on the hardware. There's no malloc, no printf, no file system — just raw memory and registers. You provide everything.

### The Boot Process

When the FPGA powers up, your CPU starts executing instructions from address 0x00000000. Here's what happens:

```
1. CPU starts at PC = 0x00000000
2. First instruction is in crt0.S (startup assembly):
   - Set the stack pointer to the top of RAM
   - Zero the .bss section (uninitialized global variables)
   - Call main()
3. main() in main.c starts running:
   - Configure peripherals via memory-mapped registers
   - Enter main loop
4. If main() ever returns, infinite loop (j .) prevents undefined behavior
```

### The Linker Script (link.ld)

The linker script tells the toolchain where to place code and data in memory. This is critical because you have a specific memory map.

```
MEMORY {
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 32K
}

SECTIONS {
    .text : {           /* Code goes at address 0 */
        *(.text.start)  /* crt0.S goes first — it must be at address 0 */
        *(.text*)
    } > RAM

    .rodata : { *(.rodata*) } > RAM     /* Read-only data (strings, constants) */
    .data   : { *(.data*)   } > RAM     /* Initialized global variables */

    .bss : {
        _bss_start = .;
        *(.bss*)
        _bss_end = .;
    } > RAM                              /* Uninitialized globals (zeroed by crt0) */

    _stack_top = ORIGIN(RAM) + LENGTH(RAM);  /* Stack starts at top of RAM, grows down */
}
```

### The volatile Keyword

In the HAL, every register access uses `volatile`:

```c
#define REG(base, offset) (*(volatile uint32_t *)((base) + (offset)))
```

`volatile` tells the C compiler: "Don't optimize accesses to this address. Every read must actually read from hardware, and every write must actually write to hardware." Without volatile, the compiler might cache a register value in a CPU register and never re-read it, which would miss hardware status changes.

For example:
```c
// WITHOUT volatile — compiler might optimize this to infinite loop
while (UART_STATUS & TX_BUSY);  // Compiler thinks: "STATUS never changes, skip the read"

// WITH volatile — compiler reads STATUS every iteration
while (UART_STATUS & TX_BUSY);  // Compiler reads the actual hardware register each time
```

### Cross-Compilation

You're writing C on your PC (x86), but the code runs on your RISC-V CPU. You need a cross-compiler — a compiler that runs on x86 but produces RISC-V machine code.

```
Your PC (x86)                         Your FPGA (RISC-V)
┌───────────┐                         ┌───────────┐
│  main.c   │                         │           │
│  hal.h    │ → riscv32-unknown-elf-gcc → firmware.bin → Block RAM
│  crt0.S   │                         │           │
│  link.ld  │                         └───────────┘
└───────────┘
```

The build chain:
1. `riscv32-unknown-elf-gcc` compiles C to RISC-V ELF binary
2. `riscv32-unknown-elf-objcopy` converts ELF to raw binary
3. A Python script converts the binary to a hex file
4. The hex file initializes Block RAM in the Verilog source (`$readmemh`)
5. Synthesis bakes the firmware into the FPGA bitstream

Yes, this means every firmware change requires re-synthesis. It's slow. That's why you test firmware in simulation first, and a UART bootloader (extension project) is the first thing to add once the base is working.

---

## 10. The Toolchain — From Code to Blinking LEDs

Here's the complete picture of every tool you'll use and how they connect:

```
DESIGN ENTRY (Verilog)
  │
  ├── Text editor / VS Code
  │   Write: rv32i_core.v, rv32i_alu.v, wb_interconnect.v, etc.
  │
  ▼
SIMULATION (Verify before hardware)
  │
  ├── Icarus Verilog (iverilog) — Verilog simulator
  ├── cocotb — Python testbench framework
  ├── GTKWave — Waveform viewer
  │
  │   You write Python tests in cocotb that drive inputs into your
  │   Verilog modules and check outputs. When something's wrong,
  │   you look at waveforms in GTKWave to see what happened cycle by cycle.
  │
  ▼
SYNTHESIS (Convert to FPGA configuration)
  │
  ├── Gowin EDA (Education Edition)
  │   1. Synthesis: Verilog → netlist (logic gates + flip-flops)
  │   2. Place & Route: Map netlist onto physical FPGA resources
  │   3. Bitstream: Generate binary file to configure FPGA
  │
  ├── Constraint files (.cst, .sdc)
  │   .cst = pin assignments (which FPGA pin connects to which signal)
  │   .sdc = timing constraints (target clock frequency)
  │
  ▼
PROGRAMMING (Load onto hardware)
  │
  ├── Gowin Programmer
  │   Flash bitstream to Tang Nano 20K via USB-C
  │
  ▼
FIRMWARE (C code for the CPU)
  │
  ├── RISC-V GNU Toolchain (riscv32-unknown-elf-gcc)
  │   Compile C → RISC-V machine code → hex file → baked into Block RAM
  │
  ├── Serial terminal (minicom / PuTTY)
  │   Connect to UART to see your firmware's output
  │
  ▼
DONE! LED blinks, UART prints, you're a hardware designer.
```

### Gowin EDA — What to Expect

When you open Gowin EDA and create a project:

1. You select the device (GW2AR-18, QFP88 package)
2. You add your Verilog source files
3. You add constraint files
4. You click "Synthesize" — this takes seconds for a small design, maybe a minute for the full SoC
5. You click "Place & Route" — this takes longer, maybe a few minutes
6. You read the reports — **this is important!**:
   - Resource utilization: how many LUTs and FFs you used
   - Timing analysis: whether your design meets timing at 27 MHz
7. You generate the bitstream and program the board

The reports are what you'll put on your resume. A full SoC might use 3,000-8,000 LUTs (15-40% of the chip), 1,000-3,000 FFs, and should comfortably meet timing at 27 MHz.

### Constraint File (.cst)

The constraint file tells the tools which FPGA pin connects to which signal in your design. You have to get this right — wrong pin assignments can damage the board.

```
// Example .cst for Tang Nano 20K (check Sipeed wiki for exact pinout!)
IO_LOC "clk" 4;          // 27 MHz clock input
IO_LOC "rst_n" 88;       // Reset button
IO_LOC "led[0]" 15;      // On-board LED 0
IO_LOC "uart_tx" 17;     // UART transmit pin
IO_LOC "uart_rx" 18;     // UART receive pin
```

---

## 11. Testing and Simulation with cocotb

### Why Simulate?

Debugging hardware on the actual FPGA is painful. You can't set breakpoints, you can't print variables, and you can't step through execution. Simulation lets you test your design on your PC with full visibility into every signal at every clock cycle.

You should spend 80% of your time in simulation and 20% on hardware. If it works in simulation, it almost certainly works on the FPGA (the exceptions are timing-related issues).

### cocotb Basics

cocotb lets you write testbenches in Python instead of Verilog. Since you already know cocotb from UWASIC, here's a quick reminder of the patterns you'll use:

```python
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_alu_add(dut):
    """Test that the ALU correctly adds two numbers."""

    # Drive inputs
    dut.a.value = 5
    dut.b.value = 3
    dut.op.value = 0  # ADD operation

    # Wait for combinational logic to settle
    await Timer(1, units="ns")

    # Check output
    assert dut.result.value == 8, f"Expected 8, got {dut.result.value}"

@cocotb.test()
async def test_cpu_add_instruction(dut):
    """Test that the CPU correctly executes an ADD instruction."""

    # Start clock
    clock = Clock(dut.clk, 10, units="ns")  # 100 MHz for simulation
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value = 0

    # Run for enough cycles for the instruction to complete
    for _ in range(10):
        await RisingEdge(dut.clk)

    # Check register file contents
    # (How you access internal signals depends on your module hierarchy)
    assert dut.regfile.regs[3].value == expected_value
```

### Testing Strategy

**Phase 2 (CPU Core) — the most critical testing:**

1. Start with individual instruction tests: write a tiny assembly program (e.g., just `ADDI x1, x0, 5; ADD x2, x1, x1`), assemble it, load the hex into simulated memory, run the simulation, and check that x2 contains 10.

2. Test every instruction type. It's tedious but essential. The official riscv-tests suite (github.com/riscv-software-src/riscv-tests) has pre-built test programs for every instruction. Passing these is strong evidence your CPU works correctly.

3. Edge cases to test specifically:
   - Writing to x0 (should have no effect)
   - Signed vs unsigned comparisons (SLT vs SLTU)
   - Branch taken vs not taken
   - All sign extension paths (I-type, S-type, B-type, J-type)
   - Back-to-back dependent instructions (hazard detection)

### Using GTKWave

When a test fails, dump waveforms and look at them:

```python
# In your cocotb Makefile
PLUSARGS += --vcd=waves.vcd

# Or in Python
# After the test, open waves.vcd in GTKWave
```

In GTKWave you can see every signal at every clock cycle. Trace through instruction execution: Is the PC incrementing correctly? Is the right instruction being fetched? Did the decoder extract the correct fields? Did the ALU produce the right result? This is how you debug CPU designs.

---

## 12. Synthesis, Timing, and Getting It on Real Hardware

### Timing Closure

Your FPGA runs at 27 MHz, meaning each clock cycle is ~37 ns. All combinational logic between any two flip-flops must complete within this time. If the longest path takes 40 ns, your design "fails timing" and won't work reliably at 27 MHz.

The timing report from Gowin EDA tells you:
- **Fmax:** The maximum frequency your design can run at
- **Slack:** How much time is left over (positive = good, negative = bad)
- **Critical path:** The longest combinational path — the bottleneck

If timing fails, common fixes:
- Add pipeline registers to break long combinational paths
- Simplify the logic on the critical path (e.g., use a simpler address decoder)
- Reduce mux sizes

27 MHz is quite slow for FPGA designs. Your SoC should meet timing easily.

### Resource Utilization

The synthesis report tells you how much of the FPGA you're using:

```
Resource        Used    Available   Utilization
LUT             4,500   20,736      21.7%
FF              1,800   15,552      11.6%
BRAM            8       46          17.4%
```

These numbers go on your resume. They demonstrate that you understand the physical cost of your design.

### From Simulation to Hardware — What Can Go Wrong

Things that work in simulation but fail on hardware:

1. **Timing violations:** Simulation doesn't model propagation delay. If your critical path is too long, the FPGA will malfunction intermittently.

2. **Uninitialized registers:** In simulation, uninitialized regs are 'x' (unknown). On the FPGA, they power up to some arbitrary value. Always use a reset signal to initialize everything.

3. **Clock domain crossings:** If you have signals going between different clock domains (unlikely in your design since you only have one clock), you need synchronizers.

4. **Pin assignment errors:** Double-check the constraint file against the actual board pinout. Seriously.

---

## 13. Common Mistakes and How to Avoid Them

### CPU Bugs (Phase 2)

**x0 not hardwired to zero.** Every write to x0 must be silently discarded. Every read from x0 must return 0. Test this explicitly.

**Sign extension errors.** The most insidious bugs. I-type immediates are 12 bits sign-extended to 32. B-type and S-type split the immediate across two fields and you have to reassemble them before sign-extending. J-type is even worse (the bits are scrambled). Test with negative immediates and negative branch offsets.

**Branch offset relative to wrong PC.** The offset is relative to the branch instruction's own PC, not PC+4 and not the instruction after the branch. If your branches land one instruction off, this is probably the bug.

**Pipeline hazards not detected.** If you see wrong results but only when two dependent instructions are back-to-back, you're missing a hazard stall.

### Bus Bugs (Phase 3)

**Slave never acks.** The CPU hangs forever waiting for an acknowledgment. Add a watchdog timer or test every peripheral's ack in isolation.

**Address decoder overlap.** Two peripherals responding to the same address. Check your address decoding logic carefully.

### Peripheral Bugs (Phase 4)

**UART baud rate wrong.** 27,000,000 / 115,200 = 234.375. Use 234. If your terminal shows garbage characters, the baud rate is probably off.

**Reading input register that's actually output register.** GPIO direction and read/write logic need to be consistent.

### Firmware Bugs (Phase 5)

**Missing volatile.** Compiler optimizes away your hardware register reads. Everything that accesses a peripheral register MUST use volatile.

**Stack overflow.** With only 32KB of RAM shared between code, data, and stack, be careful with large local arrays. The stack grows downward from the top of RAM.

**Forgetting crt0.S.** If you skip the startup code, the stack pointer is random and .bss is uninitialized. main() will crash immediately.

---

## 14. Glossary

**ABI (Application Binary Interface):** Convention for register usage, function calling, etc. RV32I uses the "ilp32" ABI.

**ALU (Arithmetic Logic Unit):** The part of the CPU that does math and logic operations.

**BRAM (Block RAM):** Dedicated memory blocks built into the FPGA.

**BSS (.bss section):** The section of memory for uninitialized global variables. Zeroed by the startup code.

**Bitstream:** The binary file that configures an FPGA.

**Bus:** Shared communication infrastructure connecting CPU to memory and peripherals.

**cocotb:** Python-based verification framework for testing Verilog/VHDL designs.

**Combinational Logic:** Logic with no memory — output depends only on current inputs.

**Constraint File (.cst):** Maps signal names in Verilog to physical FPGA pin numbers.

**Cross-compiler:** A compiler that produces code for a different architecture than the one it runs on.

**EDA (Electronic Design Automation):** Software tools for designing electronic systems.

**ELF:** Executable and Linkable Format — the standard binary format produced by compilers.

**FF (Flip-Flop):** A 1-bit storage element that updates on a clock edge.

**Fmax:** Maximum clock frequency at which a design can operate.

**FPGA (Field-Programmable Gate Array):** A reconfigurable chip that can implement any digital circuit.

**FSM (Finite State Machine):** A circuit that transitions between states based on inputs and current state.

**GPIO (General-Purpose I/O):** Configurable digital pins that can be inputs or outputs.

**HAL (Hardware Abstraction Layer):** C definitions for accessing hardware registers.

**HDL (Hardware Description Language):** A language for describing digital hardware (Verilog, VHDL).

**Hazard:** A situation in a pipeline where the next instruction can't proceed normally.

**ISA (Instruction Set Architecture):** The specification of instructions a CPU understands.

**LUT (Look-Up Table):** The basic configurable logic element in an FPGA.

**Memory-Mapped I/O:** Accessing peripherals through load/store instructions to specific addresses.

**Netlist:** A description of a circuit as gates, flip-flops, and connections between them.

**P&R (Place and Route):** The process of mapping a netlist onto physical FPGA resources.

**PC (Program Counter):** Register holding the address of the current instruction.

**Pipeline:** Technique of overlapping instruction execution stages for higher throughput.

**Prescaler:** A clock divider — counts N clock cycles before producing one output tick.

**PWM (Pulse Width Modulation):** A technique for controlling average power by varying the duty cycle of a square wave.

**Register File:** The CPU's fast internal storage — 32 registers in RISC-V.

**RTL (Register Transfer Level):** The level of abstraction for describing digital hardware in terms of registers and the logic between them.

**RV32I:** The RISC-V 32-bit base integer instruction set.

**Sequential Logic:** Logic with memory — output depends on current inputs and previous state.

**Sign Extension:** Expanding a smaller signed number to a larger bit width by replicating the sign bit.

**Slack:** The difference between the required timing and the actual timing. Positive = meeting timing.

**SoC (System on Chip):** A complete computer system on a single chip — CPU, memory, peripherals.

**Stall (Pipeline Bubble):** Pausing part of the pipeline to resolve a hazard.

**Synthesis:** Converting HDL code into a netlist of logic gates and flip-flops.

**Two's Complement:** The standard representation for signed integers in binary.

**UART (Universal Asynchronous Receiver/Transmitter):** A serial communication protocol.

**Verilog:** A hardware description language used to design digital circuits.

**Wishbone:** An open-source bus protocol for connecting CPU to peripherals.

---

## What to Read Next

1. **RISC-V Spec (Chapter 2)** — riscv.org/technical/specifications — The actual ISA specification. Chapter 2 covers everything about RV32I.
2. **RISC-V Green Card** — Search for "RISC-V reference card" — A one-page cheat sheet of all instructions and encodings.
3. **ZipCPU Wishbone Tutorials** — zipcpu.com — Excellent practical walkthroughs of building Wishbone peripherals.
4. **PicoRV32 Source Code** — github.com/YosysHQ/picorv32 — A real, working RV32I core to study (but write your own!).
5. **Tang Nano 20K Wiki** — wiki.sipeed.com — Pinout, schematic, getting started with Gowin EDA.

Good luck, Jayden. This is going to be a great project.
