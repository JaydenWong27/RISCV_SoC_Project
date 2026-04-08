module soc_top (
    input wire clk,
    input wire rst,      // active-low button (pulled high; press to reset)
    output wire uart_tx,
    input wire uart_rx,
    inout wire [7:0] gpio_pins,
    output wire pwm_out
);

reg [7:0] por_count;
always @(posedge clk) begin
    if (!rst)
        por_count <= 0;
    else if (!por_count[7])
        por_count <= por_count + 1;
end
wire rst_internal = ~por_count[7]; 

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

wire [31:0] bram_wb_addr;
wire [31:0] bram_wb_dat_m2s;
wire bram_wb_cyc;
wire bram_wb_stb;
wire bram_wb_we;
wire [3:0] bram_wb_sel;
wire [31:0] bram_wb_dat_s2m;
wire bram_wb_ack;

wire [31:0] uart_wb_addr;
wire [31:0] uart_wb_dat_m2s;
wire uart_wb_stb;
wire uart_wb_we;
wire [3:0] uart_wb_sel;
wire [31:0] uart_wb_dat_s2m;
wire uart_wb_ack;

wire [31:0] gpio_wb_addr;
wire [31:0] gpio_wb_dat_m2s;
wire gpio_wb_stb;
wire gpio_wb_we;
wire [3:0] gpio_wb_sel;
wire [31:0] gpio_wb_dat_s2m;
wire gpio_wb_ack;


wire [31:0] pwm_wb_addr;
wire [31:0] pwm_wb_dat_m2s;
wire pwm_wb_stb;
wire pwm_wb_we;
wire [3:0] pwm_wb_sel;
wire [31:0] pwm_wb_dat_s2m;
wire pwm_wb_ack;

wire [31:0] timer_wb_addr;
wire [31:0] timer_wb_dat_m2s;
wire timer_wb_stb;
wire timer_wb_we;
wire [3:0] timer_wb_sel;
wire [31:0] timer_wb_dat_s2m;
wire timer_wb_ack;
wire uart_wb_cyc;
wire gpio_wb_cyc;
wire pwm_wb_cyc;
wire timer_wb_cyc;

assign bram_wb_addr    = cpu_wb_addr;
assign bram_wb_dat_m2s = cpu_wb_dat_m2s;
assign bram_wb_cyc     = cpu_wb_cyc;
assign bram_wb_we      = cpu_wb_we;
assign bram_wb_sel     = cpu_wb_sel;

assign cpu_instr_ack = 1'b1;

assign uart_wb_cyc  = cpu_wb_cyc;
assign gpio_wb_cyc  = cpu_wb_cyc;
assign pwm_wb_cyc   = cpu_wb_cyc;
assign timer_wb_cyc = cpu_wb_cyc;

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
    .wb_addr(bram_wb_addr),
    .wb_dat_m2s(bram_wb_dat_m2s),
    .wb_cyc(bram_wb_cyc),
    .wb_stb(bram_wb_stb),
    .wb_we(bram_wb_we),
    .wb_sel(bram_wb_sel),
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

wb_gpio #(
    .ACTIVE_LOW_MASK(8'h3F)
) gpio(
    .clk(clk),
    .rst(rst_internal),
    .wb_addr(cpu_wb_addr),
    .wb_dat_m2s(cpu_wb_dat_m2s),
    .wb_cyc(gpio_wb_cyc),
    .wb_stb(gpio_wb_stb),
    .wb_we(cpu_wb_we),
    .wb_sel(cpu_wb_sel),
    .wb_dat_s2m(gpio_wb_dat_s2m),
    .wb_ack(gpio_wb_ack),
    .gpio_pins(gpio_pins)
);

wb_pwm pwm(
    .clk(clk),
    .rst(rst_internal),
    .wb_addr(cpu_wb_addr),
    .wb_dat_m2s(cpu_wb_dat_m2s),
    .wb_cyc(pwm_wb_cyc),
    .wb_stb(pwm_wb_stb),
    .wb_we(cpu_wb_we),
    .wb_sel(cpu_wb_sel),
    .wb_dat_s2m(pwm_wb_dat_s2m),
    .wb_ack(pwm_wb_ack),
    .pwm_out(pwm_out)
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
