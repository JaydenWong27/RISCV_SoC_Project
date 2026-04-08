`timescale 1ns/1ps

module soc_debug_trace_tb;
    reg clk = 0;
    reg rst = 0;
    wire uart_tx;
    reg uart_rx = 1'b1;
    wire [7:0] gpio_pins;
    wire pwm_out;

    soc_top dut (
        .clk(clk),
        .rst(rst),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx),
        .gpio_pins(gpio_pins),
        .pwm_out(pwm_out)
    );

    always #5 clk = ~clk;

    always @(negedge clk) begin
        if (!dut.rst_internal && dut.core.id_ex_pc == 32'h000000ac) begin
            $display(
                "prebranch t=%0t pc=%08h idpc=%08h id_branch=%b id_f3=%03b id_r1=%08h id_r2=%08h rs1_fwd=%08h rs2_fwd=%08h alu=%08h zero=%b br_taken=%b memwb_rd=%0d memwb_data=%08h memwb_regw=%b exmem_rd=%0d exmem_memr=%b",
                $time,
                dut.cpu_instr_addr,
                dut.core.id_ex_pc,
                dut.core.id_ex_branch,
                dut.core.id_ex_funct3,
                dut.core.id_ex_rs1_data,
                dut.core.id_ex_rs2_data,
                dut.core.rs1_forwarded,
                dut.core.rs2_forwarded,
                dut.core.alu_result,
                dut.core.alu_zero,
                dut.core.branch_taken,
                dut.core.mem_wb_rd,
                dut.core.mem_wb_mem_data,
                dut.core.mem_wb_reg_write,
                dut.core.ex_mem_rd,
                dut.core.ex_mem_mem_read
            );
        end
    end

    initial begin
        repeat (25000) begin
            @(posedge clk);
            if (!dut.rst_internal) begin
                if (dut.cpu_instr_addr == 32'h0000001c ||
                    dut.cpu_instr_addr == 32'h00000020 ||
                    dut.cpu_instr_addr == 32'h00000024 ||
                    dut.cpu_instr_addr == 32'h00000040 ||
                    dut.cpu_instr_addr == 32'h00000048 ||
                    dut.cpu_instr_addr == 32'h00000050 ||
                    dut.cpu_instr_addr == 32'h00000058 ||
                    dut.cpu_instr_addr == 32'h0000006c ||
                    dut.cpu_instr_addr == 32'h00000070 ||
                    dut.cpu_instr_addr == 32'h00000074 ||
                    dut.cpu_instr_addr == 32'h00000078 ||
                    dut.cpu_instr_addr == 32'h00000080 ||
                    dut.cpu_instr_addr == 32'h00000084 ||
                    dut.cpu_instr_addr == 32'h00000088 ||
                    dut.cpu_instr_addr == 32'h0000008c ||
                    dut.cpu_instr_addr == 32'h00000090 ||
                    dut.cpu_instr_addr == 32'h00000094 ||
                    dut.cpu_instr_addr == 32'h00000098 ||
                    dut.cpu_instr_addr == 32'h0000009c ||
                    dut.cpu_instr_addr == 32'h000000a0 ||
                    dut.cpu_instr_addr == 32'h000000a4 ||
                    dut.cpu_instr_addr == 32'h000000a8 ||
                    dut.cpu_instr_addr == 32'h000000ac ||
                    dut.cpu_instr_addr == 32'h000000b0 ||
                    dut.cpu_instr_addr == 32'h000000b4 ||
                    dut.cpu_instr_addr == 32'h000000b8 ||
                    dut.cpu_instr_addr == 32'h000000bc ||
                    dut.cpu_instr_addr == 32'h000000c0 ||
                    dut.cpu_instr_addr == 32'h000000c4 ||
                    dut.cpu_instr_addr == 32'h000000c8 ||
                    dut.cpu_instr_addr == 32'h000000ec ||
                    dut.cpu_instr_addr == 32'h000000f0) begin
                    $display(
                        "t=%0t pc=%08h instr=%08h ifpc=%08h if_instr=%08h idpc=%08h id_branch=%b id_f3=%03b id_rs1=%0d id_rs2=%0d id_r1=%08h id_r2=%08h id_memr=%b id_rd=%0d ex_pc=%08h ex_memr=%b ex_rd=%0d wbpc=%08h wb_memr=%b wb_rd=%0d ra=%08h sp=%08h a0=%08h a5=%08h s0=%08h rs1_fwd=%08h rs2_fwd=%08h alu=%08h zero=%b br_taken=%b hz_stall=%b hz_flush=%b wb_addr=%08h wb_we=%b wb_sel=%b wb_dat=%08h wb_rsp=%08h mem_wait=%b mem_stall=%b",
                        $time,
                        dut.cpu_instr_addr,
                        dut.cpu_instr_data,
                        dut.core.if_id_pc,
                        dut.core.if_id_instr,
                        dut.core.id_ex_pc,
                        dut.core.id_ex_branch,
                        dut.core.id_ex_funct3,
                        dut.core.id_ex_rs1,
                        dut.core.id_ex_rs2,
                        dut.core.id_ex_rs1_data,
                        dut.core.id_ex_rs2_data,
                        dut.core.id_ex_mem_read,
                        dut.core.id_ex_rd,
                        dut.core.ex_mem_pc,
                        dut.core.ex_mem_mem_read,
                        dut.core.ex_mem_rd,
                        dut.core.mem_wb_pc,
                        dut.core.mem_wb_mem_to_reg,
                        dut.core.mem_wb_rd,
                        dut.core.regfile.regs[1],
                        dut.core.regfile.regs[2],
                        dut.core.regfile.regs[10],
                        dut.core.regfile.regs[15],
                        dut.core.regfile.regs[8],
                        dut.core.rs1_forwarded,
                        dut.core.rs2_forwarded,
                        dut.core.alu_result,
                        dut.core.alu_zero,
                        dut.core.branch_taken,
                        dut.core.hazard_stall,
                        dut.core.hazard_flush,
                        dut.cpu_wb_addr,
                        dut.cpu_wb_we,
                        dut.cpu_wb_sel,
                        dut.cpu_wb_dat_m2s,
                        dut.cpu_wb_dat_s2m,
                        dut.core.mem_wait,
                        dut.core.mem_stall
                    );
                end

                if (dut.cpu_wb_cyc && dut.cpu_wb_stb) begin
                    $display(
                        "  bus t=%0t addr=%08h we=%b sel=%b dat_m2s=%08h dat_s2m=%08h ack=%b",
                        $time,
                        dut.cpu_wb_addr,
                        dut.cpu_wb_we,
                        dut.cpu_wb_sel,
                        dut.cpu_wb_dat_m2s,
                        dut.cpu_wb_dat_s2m,
                        dut.cpu_wb_ack
                    );
                end
            end
        end
        $finish;
    end
endmodule
