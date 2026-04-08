module rv32i_regfile (
    input wire clk,
    input wire rst,
    input wire [4:0] rs1_addr,
    input wire [4:0] rs2_addr,
    output reg [31:0] rs1_data,
    output reg [31:0] rs2_data,
    input wire [4:0] rd_addr,
    input wire [31:0] rd_data,
    input wire rd_we
);

    reg [31:0] regs [0:31];
    integer i;

    always @(*) begin

        if(rs1_addr == 0)begin
            rs1_data = 0;
        end else if (rd_we && rd_addr != 0 && rd_addr == rs1_addr) begin
            rs1_data = rd_data; 
        end else begin
            rs1_data = regs[rs1_addr];
        end

        if(rs2_addr == 0) begin
            rs2_data = 0;
        end else if (rd_we && rd_addr != 0 && rd_addr == rs2_addr) begin
            rs2_data = rd_data; 
        end else begin
            rs2_data = regs[rs2_addr];
        end

    end

    always @(posedge clk) begin

    if(rst) begin
            for( i = 0; i < 32; i = i + 1) begin
                regs[i] <= 0;
            end
    end else if(rd_we && rd_addr != 0) begin
            regs[rd_addr] <= rd_data;
        end
    end


endmodule