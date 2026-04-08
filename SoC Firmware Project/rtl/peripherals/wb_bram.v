module wb_bram (
    input wire clk,
    input wire rst,

    // Port A: instruction fetch (read-only)
    input wire [31:0] instr_addr,
    input wire instr_we,
    output reg [31:0] instr_data,

    // Port B: data access (read/write, directly from CPU data bus)
    input wire [31:0] wb_addr,
    input wire [31:0] wb_dat_m2s,
    input wire wb_cyc,
    input wire wb_stb,
    input wire wb_we,
    input wire [3:0] wb_sel,

    output reg [31:0] wb_dat_s2m,
    output reg wb_ack

);

// Two separate single-port BRAMs avoid Gowin's unsupported DPB WRITE_MODE0=10.
reg [31:0] mem_i [0:8191];
reg [31:0] mem_d [0:8191];
integer i;

initial begin
    // Initialize with NOPs (addi x0, x0, 0)
    for (i = 0; i < 1024; i = i + 1) begin
        mem_i[i] = 32'h00000013;
        mem_d[i] = 32'h00000013;
    end
    for (i = 1024; i < 2048; i = i + 1) begin
        mem_i[i] = 32'h00000013;
        mem_d[i] = 32'h00000013;
    end
    for (i = 2048; i < 3072; i = i + 1) begin
        mem_i[i] = 32'h00000013;
        mem_d[i] = 32'h00000013;
    end
    for (i = 3072; i < 4096; i = i + 1) begin
        mem_i[i] = 32'h00000013;
        mem_d[i] = 32'h00000013;
    end
    for (i = 4096; i < 5120; i = i + 1) begin
        mem_i[i] = 32'h00000013;
        mem_d[i] = 32'h00000013;
    end
    for (i = 5120; i < 6144; i = i + 1) begin
        mem_i[i] = 32'h00000013;
        mem_d[i] = 32'h00000013;
    end
    for (i = 6144; i < 7168; i = i + 1) begin
        mem_i[i] = 32'h00000013;
        mem_d[i] = 32'h00000013;
    end
    for (i = 7168; i < 8192; i = i + 1) begin
        mem_i[i] = 32'h00000013;
        mem_d[i] = 32'h00000013;
    end

    // Load firmware from hex file

    mem_i[0] = 32'h00008137; mem_d[0] = 32'h00008137;
    mem_i[1] = 32'h00000293; mem_d[1] = 32'h00000293;
    mem_i[2] = 32'h00000313; mem_d[2] = 32'h00000313;
    mem_i[3] = 32'h0062d863; mem_d[3] = 32'h0062d863;
    mem_i[4] = 32'h0002a023; mem_d[4] = 32'h0002a023;
    mem_i[5] = 32'h00428293; mem_d[5] = 32'h00428293;
    mem_i[6] = 32'hfe62cce3; mem_d[6] = 32'hfe62cce3;
    mem_i[7] = 32'h008000ef; mem_d[7] = 32'h008000ef;
    mem_i[8] = 32'h0000006f; mem_d[8] = 32'h0000006f;
    mem_i[9] = 32'hff010113; mem_d[9] = 32'hff010113;
    mem_i[10] = 32'h00112623; mem_d[10] = 32'h00112623;
    mem_i[11] = 32'h00812423; mem_d[11] = 32'h00812423;
    mem_i[12] = 32'h01010413; mem_d[12] = 32'h01010413;
    mem_i[13] = 32'h100017b7; mem_d[13] = 32'h100017b7;
    mem_i[14] = 32'h00478793; mem_d[14] = 32'h00478793;
    mem_i[15] = 32'h03f00713; mem_d[15] = 32'h03f00713;
    mem_i[16] = 32'h00e7a023; mem_d[16] = 32'h00e7a023;
    mem_i[17] = 32'h100017b7; mem_d[17] = 32'h100017b7;
    mem_i[18] = 32'h00100713; mem_d[18] = 32'h00100713;
    mem_i[19] = 32'h00e7a023; mem_d[19] = 32'h00e7a023;
    mem_i[20] = 32'h0000006f; mem_d[20] = 32'h0000006f;
end

// Port A: instruction fetch
always @(posedge clk) begin
    instr_data <= mem_i[instr_addr[14:2]];
end

// Port B: data memory (read-write)
always @(posedge clk) begin
    if (rst) begin
        wb_dat_s2m <= 0;
        wb_ack <= 0;
    end else begin
        if (wb_cyc && wb_stb) begin
            if (wb_we) begin
                if (wb_sel[0]) mem_d[wb_addr[14:2]][7:0] <= wb_dat_m2s[7:0];
                if (wb_sel[1]) mem_d[wb_addr[14:2]][15:8] <= wb_dat_m2s[15:8];
                if (wb_sel[2]) mem_d[wb_addr[14:2]][23:16] <= wb_dat_m2s[23:16];
                if (wb_sel[3]) mem_d[wb_addr[14:2]][31:24] <= wb_dat_m2s[31:24];
            end else begin
                wb_dat_s2m <= mem_d[wb_addr[14:2]];
            end
            wb_ack <= 1;
        end else begin
            wb_ack <= 0;
        end
    end
end

endmodule