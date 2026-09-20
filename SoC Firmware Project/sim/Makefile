#=============================================================================
# cocotb test runner.
#
#   make TEST=uart          run one suite
#   make all                run every suite
#   make clean              remove build artifacts
#
# On Windows this Makefile may fail: cocotb hands vvp an absolute path ending
# in .dll for -m, which Icarus 11 cannot load. Use the standalone runner
# instead, which drives iverilog/vvp directly and works everywhere:
#
#   python run_tests.py             all 12 suites
#   python run_tests.py uart bram   just those
#
# Requires cocotb and Icarus Verilog:
#   pip install cocotb
#=============================================================================

# Rules appear before the cocotb include, so name the real default explicitly.
.DEFAULT_GOAL := sim

SIM           ?= icarus
TOPLEVEL_LANG ?= verilog

# Relative on purpose: the project path contains spaces, and make cannot handle
# spaces in prerequisite paths. Relative paths from sim/ avoid them entirely.
RTL := ../rtl

CORE_SRCS := $(RTL)/core/rv32i_alu.v \
             $(RTL)/core/rv32i_decode.v \
             $(RTL)/core/rv32i_regfile.v \
             $(RTL)/core/rv32i_hazard.v \
             $(RTL)/core/rv32i_core.v

SOC_SRCS  := $(CORE_SRCS) \
             $(RTL)/bus/wb_interconnect.v \
             $(RTL)/peripherals/wb_bram.v \
             $(RTL)/peripherals/wb_gpio.v \
             $(RTL)/peripherals/wb_pwm.v \
             $(RTL)/peripherals/wb_timer.v \
             $(RTL)/peripherals/wb_uart.v \
             $(RTL)/top/soc_top.v

TESTS := alu decode regfile hazard core interconnect bram gpio pwm timer uart soc

TOPLEVEL_alu          := rv32i_alu
TOPLEVEL_decode       := rv32i_decode
TOPLEVEL_regfile      := rv32i_regfile
TOPLEVEL_hazard       := rv32i_hazard
TOPLEVEL_core         := rv32i_core
TOPLEVEL_interconnect := wb_interconnect
TOPLEVEL_bram         := wb_bram
TOPLEVEL_gpio         := wb_gpio
TOPLEVEL_pwm          := wb_pwm
TOPLEVEL_timer        := wb_timer
TOPLEVEL_uart         := wb_uart
TOPLEVEL_soc          := soc_top

SRCS_alu          := $(RTL)/core/rv32i_alu.v
SRCS_decode       := $(RTL)/core/rv32i_decode.v
SRCS_regfile      := $(RTL)/core/rv32i_regfile.v
SRCS_hazard       := $(RTL)/core/rv32i_hazard.v
SRCS_core         := $(CORE_SRCS)
SRCS_interconnect := $(RTL)/bus/wb_interconnect.v
SRCS_bram         := $(RTL)/peripherals/wb_bram.v
SRCS_gpio         := $(RTL)/peripherals/wb_gpio.v
SRCS_pwm          := $(RTL)/peripherals/wb_pwm.v
SRCS_timer        := $(RTL)/peripherals/wb_timer.v
SRCS_uart         := $(RTL)/peripherals/wb_uart.v
SRCS_soc          := $(SOC_SRCS)

TEST ?= uart

TOPLEVEL        := $(TOPLEVEL_$(TEST))
VERILOG_SOURCES := $(SRCS_$(TEST))
MODULE          := test_$(TEST)

# wb_bram and soc_top load firmware.hex via $readmemh, relative to the
# simulator's working directory.
COCOTB_HDL_TIMEUNIT      := 1ns
COCOTB_HDL_TIMEPRECISION := 1ps

firmware.hex: ../firmware/firmware.hex
	cp $< $@

sim: firmware.hex

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: all
all: firmware.hex
	@fail=0; \
	for t in $(TESTS); do \
	    echo "=== $$t ==="; \
	    $(MAKE) --no-print-directory TEST=$$t || fail=1; \
	done; \
	exit $$fail

.PHONY: distclean
distclean: clean
	rm -rf sim_build results.xml firmware.hex __pycache__
