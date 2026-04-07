module rv32i_decode (
    input wire [31:0] instr,
    output wire [4:0] rs1,
    output wire [4:0] rs2,
    output wire [4:0] rd,
    output reg [31:0] imm,
    output reg [3:0] alu_op,
    output reg reg_write,
    output reg mem_read,
    output reg mem_write,
    output reg branch,
    output reg jump,
    output reg mem_to_reg,

    output wire [2:0] decode_funct3,
    output reg lui,
    output reg auipc,
    output reg jalr
);
    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;

    assign rs1 = instr[19:15];
    assign rs2 = instr[24:20];
    assign rd = instr[11:7];
    assign opcode = instr[6:0];
    assign funct3 = instr[14:12];
    assign funct7 = instr[31:25];

    assign decode_funct3 = funct3;


    always @(*) begin
        imm = 0;

        case (opcode)
            7'b0110011: begin
                imm = 0;
            end // R type: no immediate imm = 0
            7'b0010011: begin
                imm = {{20{instr[31]}}, instr[31:20]};
            end // I type: I type immediate (instr[31:20], sign extend)
            7'b0000011:  begin
                imm = {{20{instr[31]}}, instr[31:20]};
            end// I type, same as above, loads use I type immediate
            7'b0100011: begin
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            end// S type, S type immediate (instr[31:25] + instr[11:7], sign extend)
            7'b1100011:begin
                imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
            end// B type, B type immediate (4 scrambled pieces + hardwired 0)
            7'b1101111: begin
                imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
            end// J type , J type immediate (4 scrambled pieces + hardwired 0)

            7'b1100111:begin
                imm = {{20{instr[31]}}, instr[31:20]};
            end // I type, same as I type, JALR uses I type immediate
            7'b0110111: begin
                imm = {instr[31:12],{12{1'b0}}};
            end // U type, u type immediate (instr[31:12] shifted up, lower 12 = 0)
            7'b0010111: begin
                imm = {instr[31:12],{12{1'b0}}};
            end // U type, same as above, auipc uses u-type immediate
        endcase
    end

        always @(*) begin
        reg_write = 0;
        mem_read = 0;
        mem_write = 0;
        branch = 0;
        jump = 0;
        mem_to_reg = 0;
        alu_op = 4'b0000;
        lui = 0;
        auipc = 0;
        jalr = 0;
        case (opcode)
            7'b0110011: begin
                reg_write = 1;
                mem_read = 0;
                mem_write = 0;
                branch = 0;
                jump = 0;
                mem_to_reg = 0;
                case(funct3)
                3'b000: begin
                    if (funct7[5]) begin
                        alu_op = 4'b0001;
                    end else begin
                        alu_op = 4'b0000;
                    end
                end
                3'b101: begin
                    if (funct7[5]) begin
                        alu_op = 4'b0111;
                    end else begin
                        alu_op = 4'b0110;
                    end
                end
                3'b001: begin
                    alu_op = 4'b0101;
                end
                3'b010: begin
                    alu_op = 4'b1000;
                end
                3'b011: begin
                    alu_op = 4'b1001;
                end
                3'b100: begin
                    alu_op = 4'b0100;
                end
                3'b110: begin
                    alu_op = 4'b0011;
                end
                3'b111: begin
                    alu_op = 4'b0010;
                end
                default: begin
                    alu_op = 4'b0000;
                end
                endcase
            end // r type    , no immediate, imm = 0
            7'b0010011: begin
                reg_write = 1;
                mem_read = 0;
                mem_write = 0;
                branch = 0;
                jump = 0;
                mem_to_reg = 0;
                case(funct3)
                3'b000: begin
                        alu_op = 4'b0000;
                end
                3'b101: begin
                    if (funct7[5]) begin
                        alu_op = 4'b0111;
                    end else begin
                        alu_op = 4'b0110;
                    end

                end
                3'b001: begin
                    alu_op = 4'b0101;
                end
                3'b010: begin
                    alu_op = 4'b1000;
                end
                3'b011: begin
                    alu_op = 4'b1001;
                end
                3'b100: begin
                    alu_op = 4'b0100;
                end
                3'b110: begin
                    alu_op = 4'b0011;
                end
                3'b111: begin
                    alu_op = 4'b0010;
                end
                default: begin
                    alu_op = 4'b0000;
                end
                endcase
            end // i type, i type immediate (instr[31:20], sign extend)
            7'b0000011:  begin
                reg_write = 1;
                mem_read = 1;
                mem_write = 0;
                branch = 0;
                jump = 0;
                mem_to_reg = 1;
                alu_op = 4'b0000;
            end// I type, same as above, loads use I type immediate
            7'b0100011: begin
                reg_write = 0;
                mem_read = 0;
                mem_write = 1;
                branch = 0;
                jump = 0;
                mem_to_reg = 0;
                alu_op = 4'b0000;
            end// S type, S type immediate (instr[31:25] + instr[11:7], sign extend)
            7'b1100011:begin
                reg_write = 0;
                mem_read = 0;
                mem_write = 0;
                branch = 1;
                jump = 0;
                mem_to_reg = 0;
                alu_op = 4'b0001;
                case (funct3) 
                    3'b000: begin
                        alu_op = 4'b0001;
                    end
                    3'b001: begin
                        alu_op = 4'b0001;
                    end
                    3'b100: begin
                        alu_op = 4'b1000;
                    end
                    3'b101: begin
                        alu_op = 4'b1000;
                    end
                    3'b110: begin
                        alu_op = 4'b1001;
                    end
                    3'b111: begin
                        alu_op = 4'b1001;
                    end
                endcase
            end// B type, B type immediate (4 scrambled pieces + hardwired 0)
            7'b1101111: begin
                reg_write = 1;
                mem_read = 0;
                mem_write = 0;
                branch = 0;
                jump = 1;
                mem_to_reg = 0;
                alu_op = 4'b0000;
            end// J type, J type immediate (4 scrambled pieces + hardwired 0)
            7'b1100111:begin
                reg_write = 1;
                mem_read = 0;
                mem_write = 0;
                branch = 0;
                jump = 1;
                mem_to_reg = 0;
                alu_op = 4'b0000;
                jalr = 1;
            end // I type, same as I type, JALR uses I-type immediate
            7'b0110111: begin
                reg_write = 1;
                mem_read = 0;
                mem_write = 0;
                branch = 0;
                jump = 0;
                mem_to_reg = 0;
                alu_op = 4'b0000;
                lui = 1;
            end // U type, U type immediate (instr[31:12] shifted up, lower 12 = 0)
            7'b0010111: begin
                reg_write = 1;
                mem_read = 0;
                mem_write = 0;
                branch = 0;
                jump = 0;
                mem_to_reg = 0;
                alu_op = 4'b0000;
                auipc = 1;
            end // U type, same as above, AUIPC uses u type immediate
            default: begin
                reg_write = 0;
                mem_read  = 0;
                mem_write = 0;
                branch    = 0;
                jump      = 0;
                mem_to_reg = 0;
                alu_op    = 4'b0000;
            end
        endcase
    end
endmodule