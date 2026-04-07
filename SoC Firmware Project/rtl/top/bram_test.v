// Test 2e: Actual wb_bram module test
module soc_top (
    input wire clk,
    input wire rst,
    output wire uart_tx,
    input wire uart_rx,
    inout wire [7:0] gpio_pins,
    output wire pwm_out
);

assign pwm_out = 0;
assign uart_tx = 1;

reg [23:0] counter = 0;
always @(posedge clk) counter <= counter + 1;

// LED 5 always blinks
assign gpio_pins[5] = counter[23];

// Instantiate actual wb_bram
wire [31:0] bram_data;
wire bram_ack;

wb_bram bram (
    .clk(clk),
    .rst(1'b0),
    .wb_addr(32'h00000000),  // read address 0 (word 0)
    .wb_dat_m2s(32'h0),
    .wb_cyc(1'b1),
    .wb_stb(1'b1),
    .wb_we(1'b0),
    .wb_sel(4'b1111),
    .wb_dat_s2m(bram_data),
    .wb_ack(bram_ack)
);

// Wait ~39ms then check
reg [19:0] delay = 0;
reg done = 0;
reg ok = 0;

always @(posedge clk) begin
    if (!done) begin
        delay <= delay + 1;
        if (&delay) begin
            done <= 1;
            ok <= (bram_data == 32'h00008137);
        end
    end
end

assign gpio_pins[0] = (done && ok) ? counter[23] : 1'b1;
assign gpio_pins[1] = (done && ok) ? ~counter[23] : 1'b1;
assign gpio_pins[4] = (done && !ok) ? 1'b0 : 1'b1;
assign gpio_pins[2] = 1'b1;
assign gpio_pins[3] = 1'b1;
assign gpio_pins[6] = 1'bz;
assign gpio_pins[7] = 1'bz;

endmodule
