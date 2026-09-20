// Minimal board test — no CPU, just blinks LEDs and sends "Hi\n" on UART
// Use this to verify pin assignments and synthesis are correct.
//
// This deliberately reuses the name soc_top so it drops into the same XDC.
// To build it, swap rtl/top/soc_top.v for this file in vivado/build.tcl --
// never read both, they collide.
module soc_top #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer BAUD_RATE   = 115200
) (
    input wire clk,
    input wire rst,
    output reg uart_tx,
    input wire uart_rx,
    inout wire [7:0] gpio_pins,
    output wire pwm_out
);

assign pwm_out = 0;

// --- LED blink ---
reg [24:0] counter;
always @(posedge clk) counter <= counter + 1;

// Blink LED 0 at ~1.5 Hz (50 MHz / 2^25)
assign gpio_pins[0] = counter[24];  // LED 0 blinks
assign gpio_pins[1] = ~counter[24]; // LED 1 blinks opposite
assign gpio_pins[2] = 1'bz;
assign gpio_pins[3] = 1'bz;
assign gpio_pins[4] = 1'bz;
assign gpio_pins[5] = 1'bz;
assign gpio_pins[6] = 1'bz;
assign gpio_pins[7] = 1'bz;

// --- UART TX: send "Hi!\n" once, then idle ---
// 50 MHz / 434 = 115207 baud (~115200)
localparam integer BAUD_DIV = CLK_FREQ_HZ / BAUD_RATE;
localparam integer BAUD_W   = $clog2(BAUD_DIV + 1);

reg [BAUD_W-1:0] baud_cnt;
reg [3:0] bit_idx;
reg [9:0] shift_reg;
reg tx_busy;

// Message: "Hi!\n"
reg [7:0] msg [0:3];
initial begin
    msg[0] = 8'h48; // 'H'
    msg[1] = 8'h69; // 'i'
    msg[2] = 8'h21; // '!'
    msg[3] = 8'h0A; // '\n'
end

reg [2:0] msg_idx;
reg msg_done;
reg [15:0] startup_delay;

always @(posedge clk) begin
    if (~rst) begin  // button pressed = reset (active-low button)
        tx_busy <= 0;
        baud_cnt <= 0;
        bit_idx <= 0;
        msg_idx <= 0;
        msg_done <= 0;
        uart_tx <= 1;
        startup_delay <= 0;
    end else if (startup_delay != 16'hFFFF) begin
        startup_delay <= startup_delay + 1;
        uart_tx <= 1;
    end else if (!msg_done && !tx_busy) begin
        // Load next character
        shift_reg <= {1'b1, msg[msg_idx], 1'b0}; // stop + data + start
        tx_busy <= 1;
        bit_idx <= 0;
        baud_cnt <= 0;
    end else if (tx_busy) begin
        if (baud_cnt == (BAUD_DIV - 1)) begin
            baud_cnt <= 0;
            uart_tx <= shift_reg[0];
            shift_reg <= shift_reg >> 1;
            bit_idx <= bit_idx + 1;
            if (bit_idx == 9) begin
                tx_busy <= 0;
                if (msg_idx == 3)
                    msg_done <= 1;
                else
                    msg_idx <= msg_idx + 1;
            end
        end else begin
            baud_cnt <= baud_cnt + 1;
        end
    end
end

endmodule
