import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge

# Must match the defaults in rtl/peripherals/wb_uart.v. The UART holds each
# bit for exactly BAUD_DIV = CLK_FREQ_HZ / BAUD_RATE clock cycles.
CLK_FREQ_HZ = 50_000_000
BAUD_RATE = 115200
BIT_CYCLES = CLK_FREQ_HZ // BAUD_RATE   # 434 at 50 MHz

TEST_BYTE = 0x55

# Line levels for one frame, in order: start bit, 8 data bits LSB-first, stop bit.
FRAME = [0] + [(TEST_BYTE >> i) & 1 for i in range(8)] + [1]


async def tick(dut):
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)


async def ticks(dut, n):
    for _ in range(n):
        await tick(dut)


async def reset (dut):
    dut.rst.value = 1
    dut.uart_rx.value = 1
    dut.wb_cyc.value = 0
    dut.wb_stb.value = 0
    dut.wb_we.value = 0
    dut.wb_addr.value = 0
    dut.wb_dat_m2s.value = 0
    await tick(dut)
    await tick(dut)
    dut.rst.value = 0


@cocotb.test()
async def test_tx_count(dut):

    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    await reset(dut)

    dut.wb_dat_m2s.value = TEST_BYTE
    dut.wb_addr.value = 0x00
    dut.wb_we.value = 1
    dut.wb_cyc.value = 1
    dut.wb_stb.value = 1

    await tick(dut)

    dut.wb_we.value = 0
    dut.wb_cyc.value = 1
    dut.wb_stb.value = 1

    for i, expected in enumerate(FRAME):
        await ticks(dut, BIT_CYCLES)
        assert dut.uart_tx.value == expected, \
            f"bit {i}: expected {expected}, got {dut.uart_tx.value}"


@cocotb.test()
async def test_rx_count(dut):

    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    await reset(dut)

    dut.uart_rx.value = 1

    for level in FRAME:
        dut.uart_rx.value = level
        await ticks(dut, BIT_CYCLES)

    dut.wb_addr.value = 0x08
    dut.wb_we.value = 0
    dut.wb_cyc.value = 1
    dut.wb_stb.value = 1
     
    await tick(dut)

    assert dut.wb_dat_s2m.value == TEST_BYTE
