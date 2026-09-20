// Bring-up wrapper: the full SoC, but exposing only the three pins whose
// FTG256 assignment is verified (clk = N11, rst = T13, LED1 = P11).
//
// Why this exists: with uart_tx, pwm_out and gpio_pins[7:1] left as top-level
// ports but no PACKAGE_PIN, Vivado places them on arbitrary balls. Those are
// driven outputs, so one landing on something the board already drives is a
// contention risk. Here they are simply not ports -- the tristate drivers go
// nowhere and are optimized away, so no I/O buffer is created at all.
//
// The LED port is named gpio_pins[0:0] deliberately, so vivado/a7lite.xdc
// constrains this top and the full soc_top without modification.
//
// Build with:  vivado -mode batch -source vivado/build.tcl -tclargs bringup
//
// Once the UART pins are traced, switch back to soc_top for the full design.
module soc_top_bringup #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer BAUD_RATE   = 115200,
    parameter INIT_FILE = "firmware.hex"
) (
    input wire clk,
    input wire rst,
    inout wire [0:0] gpio_pins      // gpio_pins[0] = LED1
);

// gpio_pins[7:1] exist inside the SoC but reach no package pin.
wire [7:1] gpio_unused;

soc_top #(
    .CLK_FREQ_HZ(CLK_FREQ_HZ),
    .BAUD_RATE(BAUD_RATE),
    .INIT_FILE(INIT_FILE)
) soc (
    .clk(clk),
    .rst(rst),
    .uart_tx(),                     // unconnected -- trimmed, no OBUF
    .uart_rx(1'b1),                 // idle-high, as an unconnected UART line
    .gpio_pins({gpio_unused, gpio_pins[0]}),
    .pwm_out()                      // unconnected -- trimmed, no OBUF
);

endmodule
