// 32 KB unified instruction/data memory, inferred as a true dual-port BRAM.
//
// Port A is a read-only instruction fetch port; port B is the Wishbone data
// port with byte enables. Vivado infers RAMB36 blocks from this template.
//
// Collision note: if port B writes the same word port A is fetching in the
// same cycle, the fetched value is undefined. The firmware does not modify
// its own code, so this never happens in practice.
module wb_bram #(
    parameter INIT_FILE = "firmware.hex"
) (
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

reg [31:0] mem [0:8191];
integer i;

initial begin
    // NOP (addi x0, x0, 0) everywhere the firmware image does not reach.
    for (i = 0; i < 8192; i = i + 1)
        mem[i] = 32'h00000013;

    $readmemh(INIT_FILE, mem);
end

// Port A: instruction fetch
always @(posedge clk) begin
    instr_data <= mem[instr_addr[14:2]];
end

// Port B: data memory (read-write)
always @(posedge clk) begin
    if (rst) begin
        wb_dat_s2m <= 0;
        wb_ack <= 0;
    end else begin
        if (wb_cyc && wb_stb) begin
            if (wb_we) begin
                if (wb_sel[0]) mem[wb_addr[14:2]][7:0] <= wb_dat_m2s[7:0];
                if (wb_sel[1]) mem[wb_addr[14:2]][15:8] <= wb_dat_m2s[15:8];
                if (wb_sel[2]) mem[wb_addr[14:2]][23:16] <= wb_dat_m2s[23:16];
                if (wb_sel[3]) mem[wb_addr[14:2]][31:24] <= wb_dat_m2s[31:24];
            end else begin
                wb_dat_s2m <= mem[wb_addr[14:2]];
            end
            wb_ack <= 1;
        end else begin
            wb_ack <= 0;
        end
    end
end

endmodule
