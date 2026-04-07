`timescale 1ns/1ps

module soc_top_smoke_tb;
    reg clk = 0;
    reg rst = 0; // active-low reset asserted at start
    wire uart_tx;
    reg uart_rx = 1'b1;
    tri [7:0] gpio_pins;
    wire pwm_out;

    integer uart_writes = 0;
    integer uart_status_reads = 0;
    integer gpio_dir_writes = 0;
    integer gpio_out_writes = 0;
    integer cycles = 0;
    reg saw_led_on = 0;
    reg saw_led_off = 0;

    soc_top dut (
        .clk(clk),
        .rst(rst),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx),
        .gpio_pins(gpio_pins),
        .pwm_out(pwm_out)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        cycles <= cycles + 1;

        if (dut.cpu_wb_cyc && dut.cpu_wb_stb && dut.cpu_wb_we) begin
            if (dut.cpu_wb_addr == 32'h1000_0000)
                uart_writes <= uart_writes + 1;
            if (dut.cpu_wb_addr == 32'h1000_1004)
                gpio_dir_writes <= gpio_dir_writes + 1;
            if (dut.cpu_wb_addr == 32'h1000_1000)
                gpio_out_writes <= gpio_out_writes + 1;
        end else if (dut.cpu_wb_cyc && dut.cpu_wb_stb && !dut.cpu_wb_we) begin
            if (dut.cpu_wb_addr == 32'h1000_0004)
                uart_status_reads <= uart_status_reads + 1;
        end

        if (gpio_pins[0] === 1'b0)
            saw_led_on <= 1;
        if (gpio_pins[0] === 1'b1)
            saw_led_off <= 1;

        if (cycles == 10)
            rst <= 1;

        if (uart_writes >= 19 && gpio_dir_writes >= 1 &&
            gpio_out_writes >= 2 && saw_led_on && saw_led_off) begin
            $display(
                "PASS cycles=%0d uart_writes=%0d gpio_dir_writes=%0d gpio_out_writes=%0d led0=%b",
                cycles, uart_writes, gpio_dir_writes, gpio_out_writes, gpio_pins[0]
            );
            $finish;
        end

        if (cycles == 2000000) begin
            $display(
                "TIMEOUT cycles=%0d uart_writes=%0d uart_status_reads=%0d gpio_dir_writes=%0d gpio_out_writes=%0d led_on=%0d led_off=%0d led0=%b pc=%08h ifpc=%08h idpc=%08h expc=%08h wbpc=%08h a0=%08h a5=%08h tx_busy=%0d bit_count=%0d baud=%0d",
                cycles, uart_writes, uart_status_reads, gpio_dir_writes, gpio_out_writes,
                saw_led_on, saw_led_off, gpio_pins[0],
                dut.cpu_instr_addr, dut.core.if_id_pc, dut.core.id_ex_pc,
                dut.core.ex_mem_pc, dut.core.mem_wb_pc,
                dut.core.regfile.regs[10], dut.core.regfile.regs[15],
                dut.uart.tx_busy, dut.uart.bit_count, dut.uart.baud_counter
            );
            $finish;
        end
    end
endmodule
