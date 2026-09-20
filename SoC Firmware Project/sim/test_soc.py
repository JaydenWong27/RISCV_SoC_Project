"""Full-SoC integration tests.

These run the real firmware image out of firmware/firmware.hex, which the
runner copies alongside the simulation so wb_bram's $readmemh finds it. That
image is led_test: it sets GPIO_DIR = 0x3F, drives GPIO_OUT = 0x01, then
spins forever.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge

# Enough cycles to clear the 128-cycle power-on reset and run the ~20
# instructions of firmware before it reaches its final spin loop.
BOOT_CYCLES = 600


async def tick(dut):
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)


async def boot(dut, cycles=BOOT_CYCLES):
    """Hold the active-low reset, release it, then let the CPU run."""
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())  # 50 MHz
    dut.rst.value = 0
    dut.uart_rx.value = 1
    for _ in range(5):
        await tick(dut)
    dut.rst.value = 1          # release the button
    for _ in range(cycles):
        await tick(dut)


@cocotb.test()
async def test_firmware_image_loaded(dut):
    """$readmemh must populate the unified BRAM before anything runs."""
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    await tick(dut)

    first = int(dut.bram.mem[0].value)
    assert first == 0x00008137, (
        f"mem[0] = 0x{first:08x}, expected 0x00008137 (lui sp, 0x8). "
        "firmware.hex was probably not found by $readmemh."
    )


@cocotb.test()
async def test_cpu_executes_firmware(dut):
    """The CPU should run crt0 + main and configure the GPIO direction."""
    await boot(dut)

    gpio_dir = int(dut.gpio.gpio_dir.value)
    assert gpio_dir == 0x3F, (
        f"gpio_dir = 0x{gpio_dir:02x}, expected 0x3F. "
        "The CPU did not reach main() and store to GPIO_DIR."
    )


@cocotb.test()
async def test_gpio_output_drives_led(dut):
    """main() writes GPIO_OUT = 1, which must reach the LED pin."""
    await boot(dut)

    gpio_out = int(dut.gpio.gpio_out.value)
    assert gpio_out == 0x01, f"gpio_out = 0x{gpio_out:02x}, expected 0x01"

    # ACTIVE_LOW_MASK is 8'h00, so the pin follows gpio_out directly.
    assert str(dut.gpio_pins.value[0]) == '1', (
        f"gpio_pins[0] = {dut.gpio_pins.value[0]}, expected '1'"
    )


@cocotb.test()
async def test_pc_advances(dut):
    """The program counter must leave reset and fetch real instructions."""
    await boot(dut, cycles=200)

    pc = int(dut.core.pc.value)
    assert pc != 0, "PC never advanced past 0"


@cocotb.test()
async def test_reset_returns_to_start(dut):
    """Asserting the button again must restart execution from the top."""
    await boot(dut)
    assert int(dut.gpio.gpio_dir.value) == 0x3F

    dut.rst.value = 0                 # press reset
    for _ in range(10):
        await tick(dut)

    # The internal reset clears the GPIO registers.
    assert int(dut.gpio.gpio_dir.value) == 0, "gpio_dir survived a reset"
