#!/usr/bin/env python3
"""CPU correctness check: directed load/branch cases + random programs vs a Python reference model.

Put this file in "SoC Firmware Project/sim/cpu_check/" and run:
    python cpu_check.py            # 7 directed cases + 1000 random programs
    python cpu_check.py 200        # fewer random programs
Needs Icarus Verilog (iverilog, vvp) on PATH. Reads the RTL from ../../rtl.
"""
import random, subprocess, sys
from pathlib import Path

HERE  = Path(__file__).resolve().parent
RTL   = HERE.parent.parent / "rtl"
BUILD = HERE / "build"
M = 0xFFFFFFFF
DATA = 0x400          # data region for loads/stores, well past the code

# ---------------- encoders ----------------
def r(f7,rs2,rs1,f3,rd,op): return (f7<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def ienc(imm,rs1,f3,rd,op): return ((imm&0xfff)<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def senc(imm,rs2,rs1): return (((imm>>5)&0x7f)<<25)|(rs2<<20)|(rs1<<15)|(2<<12)|((imm&0x1f)<<7)|0x23
def benc(imm,rs2,rs1,f3): return (((imm>>12)&1)<<31)|(((imm>>5)&0x3f)<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(((imm>>1)&0xf)<<8)|(((imm>>11)&1)<<7)|0x63
def jenc(imm,rd): return (((imm>>20)&1)<<31)|(((imm>>1)&0x3ff)<<21)|(((imm>>11)&1)<<20)|(((imm>>12)&0xff)<<12)|(rd<<7)|0x6f

def encode(op):
    t,rd,rs1,rs2,imm = op
    return {'add': lambda: r(0,rs2,rs1,0,rd,0x33), 'sub': lambda: r(0x20,rs2,rs1,0,rd,0x33),
            'xor': lambda: r(0,rs2,rs1,4,rd,0x33), 'addi': lambda: ienc(imm,rs1,0,rd,0x13),
            'lw':  lambda: ienc(imm,rs1,2,rd,0x03), 'sw': lambda: senc(imm,rs2,rs1),
            'beq': lambda: benc(imm,rs2,rs1,0), 'bne': lambda: benc(imm,rs2,rs1,1),
            'jal': lambda: jenc(imm,rd), 'spin': lambda: 0x0000006f}[t]()

# ---------------- reference model (what the CPU should do) ----------------
def iss(ops):
    x=[0]*32; mem={}; pc=0
    for _ in range(10000):
        t,rd,rs1,rs2,imm = ops[pc//4]; npc=pc+4; v=None
        if t=='spin': break
        if   t=='add':  v=(x[rs1]+x[rs2])&M
        elif t=='sub':  v=(x[rs1]-x[rs2])&M
        elif t=='xor':  v=x[rs1]^x[rs2]
        elif t=='addi': v=(x[rs1]+imm)&M
        elif t=='lw':   v=mem.get((x[rs1]+imm)&M, 0x13)   # BRAM is pre-filled with NOP (0x13)
        elif t=='sw':   mem[(x[rs1]+imm)&M]=x[rs2]
        elif t=='beq' and x[rs1]==x[rs2]: npc=pc+imm
        elif t=='bne' and x[rs1]!=x[rs2]: npc=pc+imm
        elif t=='jal':  v=pc+4; npc=pc+imm
        if v is not None and rd: x[rd]=v
        pc=npc
    return x

# ---------------- directed cases ----------------
N=('addi',0,0,0,0)
PRE=[('addi',5,0,0,42),('addi',6,0,0,7),N,N,N,('sw',0,0,5,DATA),('sw',0,0,6,DATA+4),N,N,N]
DIRECTED = {
  "A load, then immediate use":         [('lw',1,0,0,DATA),('add',2,1,1,0)],
  "B load, independent, then use":      [('lw',1,0,0,DATA),('addi',8,0,0,1),('add',9,1,8,0)],
  "C load, two independent, then use":  [('lw',1,0,0,DATA),('addi',11,0,0,2),('addi',12,0,0,3),('add',13,1,11,0)],
  "D load, then taken branch":          [('lw',14,0,0,DATA),('beq',0,0,0,8),('addi',15,0,0,99),('addi',16,0,0,5)],
  "E two loads back to back, then use": [('lw',17,0,0,DATA),('lw',18,0,0,DATA+4),('add',19,18,18,0)],
  "F load, then 5 independent instrs":  [('lw',1,0,0,DATA)]+[('addi',20+k,0,0,k+1) for k in range(5)],
  "G first instruction not repeated":   [],   # PRE starts at address 0; see below
}

def random_prog(rng, n=40):
    ops=[]
    for k in range(n):
        t=rng.choices(['add','sub','xor','addi','lw','sw','beq','bne','jal'],[3,2,2,4,5,3,2,2,1])[0]
        rd,rs1,rs2=rng.randint(1,6),rng.randint(0,6),rng.randint(0,6)
        if t in('beq','bne','jal'):
            off=4*rng.randint(1,3)
            if k*4+off>n*4: t,off='addi',0
        if   t=='addi': ops.append((t,rd,rs1,0,rng.randint(-50,50)))
        elif t=='lw':   ops.append((t,rd,0,0,DATA+4*rng.randint(0,7)))
        elif t=='sw':   ops.append((t,0,0,rs2,DATA+4*rng.randint(0,7)))
        elif t in('beq','bne'): ops.append((t,0,rs1,rs2,off))
        elif t=='jal':  ops.append((t,rd,0,0,off))
        else:           ops.append((t,rd,rs1,rs2,0))
    return ops

TB = r'''`timescale 1ns/1ps
module tb;
  reg clk=0; always #10 clk=~clk; reg rst_n=0; wire tx; wire [7:0] gpio; wire pwm; integer i;
  soc_top #(.INIT_FILE("prog.hex")) dut(.clk(clk),.rst(rst_n),.uart_tx(tx),.uart_rx(1'b1),.gpio_pins(gpio),.pwm_out(pwm));
  initial begin
    repeat(5) @(posedge clk); rst_n=1; repeat(1500) @(posedge clk);
    $write("REGS"); for (i=1;i<32;i=i+1) $write(" %h", dut.core.regfile.regs[i]); $display("");
    $finish;
  end
endmodule
'''
SRCS = ["core/rv32i_alu.v","core/rv32i_decode.v","core/rv32i_regfile.v","core/rv32i_hazard.v",
        "core/rv32i_core.v","bus/wb_interconnect.v","peripherals/wb_bram.v","peripherals/wb_gpio.v",
        "peripherals/wb_pwm.v","peripherals/wb_timer.v","peripherals/wb_uart.v","top/soc_top.v"]

def run_hw(ops):
    (BUILD/"prog.hex").write_text("\n".join(f"{encode(o):08x}" for o in ops)+"\n")
    out=subprocess.run(["vvp","-n","sim"],cwd=BUILD,capture_output=True,text=True).stdout
    line=[l for l in out.splitlines() if l.startswith("REGS")][0]
    return [0]+[int(v,16) for v in line.split()[1:]]

def main():
    n_rand=int(sys.argv[1]) if len(sys.argv)>1 else 1000
    BUILD.mkdir(exist_ok=True)
    (BUILD/"tb.v").write_text(TB)
    subprocess.run(["iverilog","-g2005","-o",str(BUILD/"sim"),str(BUILD/"tb.v")]+[str(RTL/s) for s in SRCS],check=True)
    print("Directed cases:")
    ok_all=True
    for name,body in DIRECTED.items():
        ops = ([('addi',3,3,0,14)] + PRE if name.startswith("G") else PRE+body) + [N]*6 + [('spin',0,0,0,0)]
        exp, got = iss(ops), run_hw(ops)
        ok = exp==got; ok_all &= ok
        bad=[f"x{i}: expected {exp[i]}, got {got[i]}" for i in range(32) if exp[i]!=got[i]]
        print(f"  {'PASS' if ok else 'FAIL'}  {name}" + ("" if ok else "   (" + "; ".join(bad[:3]) + ")"))
    fails=[]
    for seed in range(n_rand):
        ops=random_prog(random.Random(seed))+[('spin',0,0,0,0)]
        if iss(ops)[1:7]!=run_hw(ops)[1:7]: fails.append(seed)
    print(f"Random programs: {n_rand-len(fails)}/{n_rand} match the reference model" + (f" (first failing seeds: {fails[:8]})" if fails else ""))
    sys.exit(0 if ok_all and not fails else 1)

if __name__=="__main__": main()
