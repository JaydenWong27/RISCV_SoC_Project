// Minimal board test — no CPU, just blinks LEDs and sends "Hi\n" on UART
// Use this to verify pin assignments and synthesis are correct
module soc_top (
    input wire clk,
    input wire rst,
    output reg uart_tx,
    input wire uart_rx,
    inout wire [7:0] gpio_pins,
    output wire pwm_out
);

assign pwm_out = 0;

// --- LED blink (active-low: 0 = ON) ---
reg [23:0] counter;
always @(posedge clk) counter <= counter + 1;

// Blink LED 0 at ~1.6 Hz (27MHz / 2^24)
// Active-low: drive 0 to turn on, 1 to turn off
assign gpio_pins[0] = counter[23];  // LED 0 blinks
assign gpio_pins[1] = ~counter[23]; // LED 1 blinks opposite
assign gpio_pins[2] = 1'bz;
assign gpio_pins[3] = 1'bz;
assign gpio_pins[4] = 1'bz;
assign gpio_pins[5] = 1'bz;
assign gpio_pins[6] = 1'bz;
assign gpio_pins[7] = 1'bz;

// --- UART TX: send "Hi!\n" once, then idle ---
// 27MHz / 234 = 115384 baud (~115200)
localparam BAUD_DIV = 234;

reg [7:0] baud_cnt;
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
        if (baud_cnt == BAUD_DIV) begin
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
