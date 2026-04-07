// Debug version of soc_top — full SoC with diagnostic LEDs
// GPIO module removed — all 6 LEDs used for debug
// LED 5: blinks if PC is advancing (CPU alive)
// LED 4: ON if CPU ever does a store
// LED 3: ON if CPU ever writes to GPIO range
// LED 2: ON if CPU ever writes to UART range
// LED 1: ON if PC ever reaches address 200 (main function)
// LED 0: ON if PC ever reaches address 28 (jal to main)
module soc_top (
    input wire clk,
    input wire rst,
    output wire uart_tx,
    input wire uart_rx,
    inout wire [7:0] gpio_pins,
    output wire pwm_out
);

assign pwm_out = 0;

// Internal power-on reset — no external pin needed
// Holds CPU in reset for first 128 clock cycles, then releases
reg [7:0] por_count;
always @(posedge clk) begin
    if (!por_count[7])
        por_count <= por_count + 1;
end
wire rst_internal = ~por_count[7];  // HIGH (reset) for 128 cycles, then LOW

wire [31:0] cpu_instr_addr;
wire [31:0] cpu_instr_data;
wire cpu_instr_cyc;
wire cpu_instr_stb;
wire cpu_instr_ack;
wire timer_irq;

wire [31:0] cpu_wb_addr;
wire [31:0] cpu_wb_dat_m2s;
wire cpu_wb_cyc;
wire cpu_wb_stb;
wire cpu_wb_we;
wire [3:0] cpu_wb_sel;

wire [31:0] cpu_wb_dat_s2m;
wire cpu_wb_ack;

wire bram_wb_stb;
wire [31:0] bram_wb_dat_s2m;
wire bram_wb_ack;

wire uart_wb_stb;
wire [31:0] uart_wb_dat_s2m;
wire uart_wb_ack;

wire gpio_wb_stb;
wire [31:0] gpio_wb_dat_s2m;
wire gpio_wb_ack;

wire pwm_wb_stb;
wire [31:0] pwm_wb_dat_s2m;
wire pwm_wb_ack;

wire timer_wb_stb;
wire [31:0] timer_wb_dat_s2m;
wire timer_wb_ack;
wire uart_wb_cyc;
wire timer_wb_cyc;

// Instruction port is always available (dual-port BRAM, no arbitration needed)
assign cpu_instr_ack = 1'b1;

assign uart_wb_cyc = cpu_wb_cyc;
assign timer_wb_cyc = cpu_wb_cyc;

// ===== DEBUG: execution milestones =====
reg [23:0] heartbeat;
always @(posedge clk) heartbeat <= heartbeat + 1;

reg ever_store;
reg ever_uart;
reg reached_main;     // PC ever reached 0xC8 (main function, mem[50])
reg reached_print;    // PC ever reached 0x70 (print_string, mem[28])
reg ever_load;        // CPU ever did a load from any address

initial begin
    por_count = 0;
    heartbeat = 0;
    ever_store = 0;
    ever_uart = 0;
    reached_main = 0;
    reached_print = 0;
    ever_load = 0;
end

assign gpio_wb_dat_s2m = 32'h0;
assign gpio_wb_ack = gpio_wb_stb && cpu_wb_cyc;
assign pwm_wb_dat_s2m = 32'h0;
assign pwm_wb_ack = pwm_wb_stb && cpu_wb_cyc;

always @(posedge clk) begin
    if (rst_internal) begin
        ever_store <= 0;
        ever_uart <= 0;
        reached_main <= 0;
        reached_print <= 0;
        ever_load <= 0;
    end else begin
        if (cpu_wb_cyc && cpu_wb_stb && cpu_wb_we)
            ever_store <= 1;
        if (cpu_wb_cyc && cpu_wb_stb && !cpu_wb_we)
            ever_load <= 1;
        if (cpu_wb_cyc && cpu_wb_stb && cpu_wb_we &&
            cpu_wb_addr[31:28] == 4'h1 && cpu_wb_addr[15:12] == 4'h0)
            ever_uart <= 1;
        if (cpu_instr_addr >= 32'hC8)
            reached_main <= 1;
        if (cpu_instr_addr >= 32'h70 && cpu_instr_addr < 32'hC8)
            reached_print <= 1;
    end
end

// Active-low LEDs: 0 = ON, 1 = OFF
// Milestones light up left-to-right as CPU progresses
assign gpio_pins[5] = heartbeat[23];                  // blinks = design loaded
assign gpio_pins[4] = ever_store ? 1'b0 : 1'b1;       // ON = did stores (stack frame)
assign gpio_pins[3] = reached_main ? 1'b0 : 1'b1;     // ON = reached main() at 0xC8
assign gpio_pins[2] = reached_print ? 1'b0 : 1'b1;    // ON = reached print_string at 0x70
assign gpio_pins[1] = ever_load ? 1'b0 : 1'b1;        // ON = did a data bus load
assign gpio_pins[0] = ever_uart ? 1'b0 : 1'b1;        // ON = wrote to UART
assign gpio_pins[6] = 1'bz;
assign gpio_pins[7] = 1'bz;

rv32i_core core(
    .clk(clk),
    .rst(rst_internal),
    .instr_data(cpu_instr_data),
    .instr_ack(cpu_instr_ack),
    .wb_dat_s2m(cpu_wb_dat_s2m),
    .wb_ack(cpu_wb_ack),
    .timer_irq(timer_irq),
    .instr_addr(cpu_instr_addr),
    .instr_cyc(cpu_instr_cyc),
    .instr_stb(cpu_instr_stb),
    .wb_addr(cpu_wb_addr),
    .wb_dat_m2s(cpu_wb_dat_m2s),
    .wb_cyc(cpu_wb_cyc),
    .wb_stb(cpu_wb_stb),
    .wb_we(cpu_wb_we),
    .wb_sel(cpu_wb_sel)
);

wb_interconnect bus_fabric(
    .wb_addr(cpu_wb_addr),
    .wb_dat_m2s(cpu_wb_dat_m2s),
    .wb_cyc(cpu_wb_cyc),
    .wb_stb(cpu_wb_stb),
    .wb_we(cpu_wb_we),
    .wb_sel(cpu_wb_sel),
    .wb_dat_s2m(cpu_wb_dat_s2m),
    .wb_ack(cpu_wb_ack),
    .ram_stb(bram_wb_stb),
    .uart_stb(uart_wb_stb),
    .gpio_stb(gpio_wb_stb),
    .pwm_stb(pwm_wb_stb),
    .timer_stb(timer_wb_stb),
    .ram_dat_s2m(bram_wb_dat_s2m),
    .ram_ack(bram_wb_ack),
    .uart_dat_s2m(uart_wb_dat_s2m),
    .uart_ack(uart_wb_ack),
    .gpio_dat_s2m(gpio_wb_dat_s2m),
    .gpio_ack(gpio_wb_ack),
    .pwm_dat_s2m(pwm_wb_dat_s2m),
    .pwm_ack(pwm_wb_ack),
    .timer_dat_s2m(timer_wb_dat_s2m),
    .timer_ack(timer_wb_ack)
);

wb_bram bram(
    .clk(clk),
    .rst(rst_internal),
    // Port A: instruction fetch (read-only, always active)
    .instr_addr(cpu_instr_addr),
    .instr_we(1'b0),
    .instr_data(cpu_instr_data),
    // Port B: data access (through interconnect)
    .wb_addr(cpu_wb_addr),
    .wb_dat_m2s(cpu_wb_dat_m2s),
    .wb_cyc(cpu_wb_cyc),
    .wb_stb(bram_wb_stb),
    .wb_we(cpu_wb_we),
    .wb_sel(cpu_wb_sel),
    .wb_dat_s2m(bram_wb_dat_s2m),
    .wb_ack(bram_wb_ack)
);

wb_uart uart(
    .clk(clk),
    .rst(rst_internal),
    .wb_addr(cpu_wb_addr),
    .wb_dat_m2s(cpu_wb_dat_m2s),
    .wb_cyc(uart_wb_cyc),
    .wb_stb(uart_wb_stb),
    .wb_we(cpu_wb_we),
    .wb_sel(cpu_wb_sel),
    .wb_dat_s2m(uart_wb_dat_s2m),
    .wb_ack(uart_wb_ack),
    .uart_tx(uart_tx),
    .uart_rx(uart_rx)
);

wb_timer timer(
    .clk(clk),
    .rst(rst_internal),
    .wb_addr(cpu_wb_addr),
    .wb_dat_m2s(cpu_wb_dat_m2s),
    .wb_cyc(timer_wb_cyc),
    .wb_stb(timer_wb_stb),
    .wb_we(cpu_wb_we),
    .wb_sel(cpu_wb_sel),
    .wb_dat_s2m(timer_wb_dat_s2m),
    .wb_ack(timer_wb_ack),
    .timer_irq(timer_irq)
);

endmodule
