module rv32i_core (
    input wire clk,
    input wire rst,
    input wire [31:0] instr_data,
    input wire instr_ack,
    input wire [31:0] wb_dat_s2m,
    input wire wb_ack,
    input wire timer_irq,

    output wire [31:0] instr_addr,
    output wire instr_cyc,
    output wire instr_stb,
    output wire [31:0] wb_addr,
    output wire [31:0] wb_dat_m2s,
    output wire wb_cyc,
    output wire wb_stb,
    output wire wb_we,
    output wire [3:0] wb_sel
);

//decode outputs
wire[4:0] decode_rs1, decode_rs2, decode_rd;
wire [31:0] decode_imm;
wire[3:0] decode_alu_op;
wire decode_reg_write, decode_mem_read, decode_mem_write;
wire decode_branch, decode_jump, decode_mem_to_reg;
wire [2:0] decode_funct3;
wire decode_lui, decode_auipc;
wire decode_jalr;


//regfile outputs
wire[31:0] regfile_rs1_data, regfile_rs2_data;

//ALU
wire [31:0] alu_a, alu_b, alu_result;
wire alu_zero;


// Program Counter
reg [31:0] pc;
reg [31:0] pc_prev;   
reg flush_delay;       

//IF/ID pipeline register
reg [31:0] if_id_instr; 
reg [31:0] if_id_pc;


// Flush: buffer is cleared (NOP inserted) on branch/jump or flush_delay.
reg [31:0] fetch_buf_instr;
reg [31:0] fetch_buf_pc;
reg        fetch_buf_valid;

//ID/EX pipeline register
reg[31:0] id_ex_pc;
reg [31:0] id_ex_rs1_data;
reg [31:0] id_ex_rs2_data;
reg [31:0] id_ex_imm;
reg [4:0] id_ex_rd;
reg [3:0] id_ex_alu_op;
reg id_ex_reg_write;
reg id_ex_mem_read;
reg id_ex_mem_write;
reg id_ex_branch;
reg id_ex_jump;
reg id_ex_mem_to_reg;
reg id_ex_use_imm;
reg [2:0] id_ex_funct3;
reg id_ex_lui;
reg id_ex_auipc;
reg id_ex_jalr;
reg [4:0] id_ex_rs1;
reg [4:0] id_ex_rs2;


// EX/MEM pipeline register
reg [31:0] ex_mem_alu_result;
reg [31:0] ex_mem_rs2_data;
reg [4:0] ex_mem_rd;
reg ex_mem_reg_write;
reg ex_mem_mem_read;
reg ex_mem_mem_write;
reg ex_mem_mem_to_reg;
reg ex_mem_jump;
reg [31:0] ex_mem_pc;
reg ex_mem_lui;
reg [31:0] ex_mem_imm;
reg [2:0] ex_mem_funct3;
reg [1:0] ex_mem_addr_low;
reg [31:0] ex_mem_mem_data;

// MEM/WB pipeline register
reg [31:0] mem_wb_alu_result;
reg [31:0] mem_wb_mem_data;
reg [4:0] mem_wb_rd;
reg mem_wb_reg_write;
reg mem_wb_mem_to_reg;
reg mem_wb_jump;
reg [31:0] mem_wb_pc;
reg mem_wb_lui;
reg [31:0] mem_wb_imm;
reg [2:0] mem_wb_funct3;
reg [1:0] mem_wb_addr_low;

//writeback signals
wire[4:0] wb_rd;
wire[31:0] wb_rd_data;
wire wb_reg_write;

//hazard input wires
wire [4:0] hazard_ex_mw_rd;
wire hazard_ex_mw_reg_write;
wire hazard_ex_mw_mem_read;
wire [4:0] hazard_id_rs1;
wire [4:0] hazard_id_rs2;
wire hazard_branch_taken;
wire hazard_stall;
wire hazard_flush;

//branch target
wire [31:0] branch_target;

// Memory stall: wait 1 cycle for BRAM registered read to complete
reg mem_wait;
wire mem_stall = ex_mem_mem_read && !mem_wait;
wire pipeline_stall = hazard_stall || mem_stall;

wire branch_condition;
assign branch_condition = (id_ex_funct3 == 3'b000) ?  alu_zero : // BEQ
                          (id_ex_funct3 == 3'b001) ? !alu_zero : // BNE
                          (id_ex_funct3 == 3'b100) ?  alu_result[0] : // BLT
                          (id_ex_funct3 == 3'b101) ? !alu_result[0] : // BGE
                          (id_ex_funct3 == 3'b110) ?  alu_result[0] : // BLTU
                          (id_ex_funct3 == 3'b111) ? !alu_result[0] : // BGEU
                          1'b0;

wire branch_taken = id_ex_branch && branch_condition;
wire jump_taken = id_ex_jump;
wire [31:0] jump_target = id_ex_jalr ? (alu_result & 32'hFFFFFFFE) : branch_target;

assign hazard_branch_taken = branch_taken || jump_taken;

wire [31:0] ex_forward_data = ex_mem_mem_read ? (ex_mem_mem_data & 32'hff) :
                              ex_mem_lui ? ex_mem_imm :
                              ex_mem_jump ? (ex_mem_pc + 4) :
                              ex_mem_alu_result;
wire [31:0] rs1_forwarded = (ex_mem_reg_write && !ex_mem_mem_read &&
                             (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs1)) ? ex_forward_data :
                            (mem_wb_reg_write && (mem_wb_rd != 5'b0) &&
                             (mem_wb_rd == id_ex_rs1)) ? wb_rd_data :
                            id_ex_rs1_data;
wire [31:0] rs2_forwarded = (ex_mem_reg_write && !ex_mem_mem_read &&
                             (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs2)) ? ex_forward_data :
                            (mem_wb_reg_write && (mem_wb_rd != 5'b0) &&
                             (mem_wb_rd == id_ex_rs2)) ? wb_rd_data :
                            id_ex_rs2_data;

wire [31:0] store_data = (ex_mem_funct3 == 3'b000) ? ({4{ex_mem_rs2_data[7:0]}} << (8 * ex_mem_addr_low)) :
                         (ex_mem_funct3 == 3'b001) ? ({2{ex_mem_rs2_data[15:0]}} << (8 * ex_mem_addr_low)) :
                         ex_mem_rs2_data;
wire [3:0] store_sel = (ex_mem_funct3 == 3'b000) ? (4'b0001 << ex_mem_addr_low) :
                       (ex_mem_funct3 == 3'b001) ? (ex_mem_addr_low[1] ? 4'b1100 : 4'b0011) :
                       4'b1111;
wire [31:0] load_shifted = mem_wb_mem_data >> (8 * mem_wb_addr_low);

wire [31:0] load_data = (mem_wb_funct3 == 3'b000) ? {{24{load_shifted[7]}}, load_shifted[7:0]} :
                        (mem_wb_funct3 == 3'b001) ? (mem_wb_addr_low[1] ?
                            {{16{mem_wb_mem_data[31]}}, mem_wb_mem_data[31:16]} :
                            {{16{mem_wb_mem_data[15]}}, mem_wb_mem_data[15:0]}) :
                        (mem_wb_funct3 == 3'b100) ? {24'b0, load_shifted[7:0]} :
                        (mem_wb_funct3 == 3'b101) ? (mem_wb_addr_low[1] ?
                            {16'b0, mem_wb_mem_data[31:16]} :
                            {16'b0, mem_wb_mem_data[15:0]}) :
                        mem_wb_mem_data;

//ALU inputs
assign alu_a = id_ex_auipc ? id_ex_pc : rs1_forwarded;
assign alu_b = id_ex_use_imm ? id_ex_imm : rs2_forwarded;

// Writeback: mux between ALU result and memory data
assign wb_rd_data = mem_wb_lui ? mem_wb_imm :
                   mem_wb_jump ? mem_wb_pc + 4 :
                   mem_wb_mem_to_reg ? load_data :
                   mem_wb_alu_result;
assign wb_rd = mem_wb_rd;
assign wb_reg_write = mem_wb_reg_write;

//Hazard input: connect pipeline stage signals to hazard unit
assign hazard_ex_mw_rd = ex_mem_rd;
assign hazard_ex_mw_reg_write = ex_mem_reg_write;
assign hazard_ex_mw_mem_read = ex_mem_mem_read;
assign hazard_id_rs1 = decode_rs1;
assign hazard_id_rs2 = decode_rs2;

// Fetch signals to instruction memory
assign instr_addr = pc;
assign instr_cyc  = 1;
assign instr_stb  = 1;


assign branch_target = id_ex_pc + id_ex_imm;

//wishbone data memory outputs

assign wb_addr = ex_mem_alu_result;
assign wb_dat_m2s = store_data;
assign wb_we = ex_mem_mem_write;
assign wb_cyc = ex_mem_mem_read | ex_mem_mem_write;
assign wb_stb = ex_mem_mem_read | ex_mem_mem_write;
assign wb_sel = ex_mem_mem_write ? store_sel : 4'b1111;



 rv32i_decode decode(
    .instr(if_id_instr),
    .rs1(decode_rs1),
    .rs2(decode_rs2),
    .rd(decode_rd),
    .imm(decode_imm),
    .alu_op(decode_alu_op),
    .reg_write(decode_reg_write),
    .mem_read(decode_mem_read),
    .mem_write(decode_mem_write),
    .branch(decode_branch),
    .jump(decode_jump),
    .mem_to_reg(decode_mem_to_reg),
    .decode_funct3(decode_funct3),
    .lui(decode_lui),
    .auipc(decode_auipc),
    .jalr(decode_jalr)
);

rv32i_regfile regfile(
    .clk(clk),
    .rst(rst),
    .rs1_addr(decode_rs1),
    .rs2_addr(decode_rs2),
    .rs1_data(regfile_rs1_data),
    .rs2_data(regfile_rs2_data),
    .rd_addr(wb_rd),
    .rd_data(wb_rd_data),
    .rd_we(wb_reg_write)
);

rv32i_alu alu(
    .a(alu_a),
    .b(alu_b),
    .op(id_ex_alu_op),
    .result(alu_result),
    .zero(alu_zero)
);

rv32i_hazard hazard (
    .ex_mw_rd(hazard_ex_mw_rd),
    .ex_mw_reg_write(hazard_ex_mw_reg_write),
    .ex_mw_mem_read(hazard_ex_mw_mem_read),
    .id_rs1(hazard_id_rs1),
    .id_rs2(hazard_id_rs2),
    .branch_taken(hazard_branch_taken),
    .stall(hazard_stall),
    .flush(hazard_flush)
);

always @(posedge clk) begin
    if (rst) begin
        pc <= 0;
        pc_prev <= 0;
        flush_delay <= 0;
        mem_wait <= 0;
    end else begin
        flush_delay <= hazard_flush;
        pc_prev <= pc;
        mem_wait <= ex_mem_mem_read && !mem_wait;
        if (pipeline_stall)
            pc <= pc; // freeze if there is hazard or memory stall
        else if (jump_taken)
            pc <= jump_target; // JAL: pc+imm, JALR: (rs1+imm)&~1
        else if (branch_taken)
            pc <= branch_target; // conditional branch
        else
            pc <= pc + 4; // normal; next instruction
    end
end

always @(posedge clk) begin
    if (rst || hazard_flush || flush_delay) begin
        fetch_buf_instr <= 32'h00000013;
        fetch_buf_pc    <= 0;
        fetch_buf_valid <= 0;
    end else if (!pipeline_stall || !fetch_buf_valid) begin
        fetch_buf_instr <= instr_data;
        fetch_buf_pc    <= pc_prev;
        fetch_buf_valid <= 1;
    end
end

//IF/ID block: latches from the fetch buffer (total 2-cycle BRAM-to-IF/ID latency)
always @(posedge clk) begin
    if (rst || hazard_flush || flush_delay) begin
        if_id_instr <= 32'h00000013;
        if_id_pc    <= 0;
    end else if (!pipeline_stall && fetch_buf_valid) begin
        if_id_instr <= fetch_buf_instr;
        if_id_pc    <= fetch_buf_pc;
    end
end

//ID/EX block: latches decode outputs
always @(posedge clk) begin
    if (rst || hazard_flush || flush_delay) begin
        id_ex_rs1_data <= 0;
        id_ex_rs2_data <= 0;
        id_ex_imm <= 0;
        id_ex_rd <= 0;
        id_ex_alu_op <= 0;
        id_ex_reg_write <= 0; 
        id_ex_mem_read <= 0;
        id_ex_mem_write <= 0;
        id_ex_branch <= 0;
        id_ex_jump <= 0;
        id_ex_mem_to_reg <= 0;
        id_ex_pc <= 0;
        id_ex_use_imm <= 0;
        id_ex_funct3 <= 0;
        id_ex_lui <= 0;
        id_ex_auipc <= 0;
        id_ex_jalr <= 0;
        id_ex_rs1 <= 0;
        id_ex_rs2 <= 0;
    end else if (hazard_stall) begin
        id_ex_rs1_data <= 0;
        id_ex_rs2_data <= 0;
        id_ex_imm <= 0;
        id_ex_rd <= 0;
        id_ex_alu_op <= 0;
        id_ex_reg_write <= 0;
        id_ex_mem_read <= 0;
        id_ex_mem_write <= 0;
        id_ex_branch <= 0;
        id_ex_jump <= 0;
        id_ex_mem_to_reg <= 0;
        id_ex_pc <= 0;
        id_ex_use_imm <= 0;
        id_ex_funct3 <= 0;
        id_ex_lui <= 0;
        id_ex_auipc <= 0;
        id_ex_jalr <= 0;
        id_ex_rs1 <= 0;
        id_ex_rs2 <= 0;
    end else if (!pipeline_stall) begin
        id_ex_rs1_data <= regfile_rs1_data; //latch register value
        id_ex_rs2_data <= regfile_rs2_data; 
        id_ex_imm <= decode_imm;
        id_ex_rd <= decode_rd; //latch destination register
        id_ex_alu_op <= decode_alu_op; //latch what operation to do
        id_ex_reg_write <= decode_reg_write;
        id_ex_mem_read <= decode_mem_read;
        id_ex_mem_write <= decode_mem_write;
        id_ex_branch <= decode_branch;
        id_ex_jump <= decode_jump;
        id_ex_mem_to_reg <= decode_mem_to_reg;
        id_ex_pc <= if_id_pc;
        id_ex_use_imm <= (if_id_instr[6:0] != 7'b0110011) &&
                         (if_id_instr[6:0] != 7'b1100011);
        id_ex_funct3 <= decode_funct3;
        id_ex_lui <= decode_lui;
        id_ex_auipc <= decode_auipc;
        id_ex_jalr <= decode_jalr;
        id_ex_rs1 <= decode_rs1;
        id_ex_rs2 <= decode_rs2;
    end
end
//ex/mem block :latches ALU result

always @(posedge clk) begin 
    if (rst) begin
        ex_mem_alu_result <= 0; // save what ALU computed
        ex_mem_rs2_data <= 0;
        ex_mem_rd <= 0; //keep track of destination register
        ex_mem_reg_write <= 0;
        ex_mem_mem_read <= 0;
        ex_mem_mem_write <= 0;
        ex_mem_mem_to_reg <= 0;
        ex_mem_jump <= 0;
        ex_mem_pc <= 0;
        ex_mem_lui <= 0;
        ex_mem_imm <= 0;
        ex_mem_funct3 <= 0;
        ex_mem_addr_low <= 0;
        ex_mem_mem_data <= 0;

    end else if (mem_stall) begin
    end else begin
        ex_mem_alu_result <= alu_result;
        ex_mem_rs2_data <= rs2_forwarded;
        ex_mem_rd <= id_ex_rd;
        ex_mem_reg_write <= id_ex_reg_write;
        ex_mem_mem_read <= id_ex_mem_read;
        ex_mem_mem_write <= id_ex_mem_write;
        ex_mem_mem_to_reg <= id_ex_mem_to_reg;
        ex_mem_jump <= id_ex_jump;
        ex_mem_pc <= id_ex_pc;
        ex_mem_lui <= id_ex_lui;
        ex_mem_imm <= id_ex_imm;
        ex_mem_funct3 <= id_ex_funct3;
        ex_mem_addr_low <= alu_result[1:0];
        ex_mem_mem_data <= wb_dat_s2m;
    end
 end

//mem/wb block then latches memory data
 always @(posedge clk) begin
    if (rst) begin
        mem_wb_alu_result <= 0;
        mem_wb_mem_data <= 0;
        mem_wb_rd <= 0;
        mem_wb_reg_write <= 0;
        mem_wb_mem_to_reg <= 0;
        mem_wb_jump <= 0;
        mem_wb_pc <= 0;
        mem_wb_lui <= 0;
        mem_wb_imm <= 0;
        mem_wb_funct3 <= 0;
        mem_wb_addr_low <= 0;
    end else if (mem_stall) begin
        // freeze: wait for BRAM data before latching into WB
    end else begin
        mem_wb_alu_result <= ex_mem_alu_result; 
        mem_wb_mem_data <= wb_dat_s2m; 
        mem_wb_rd <= ex_mem_rd; 
        mem_wb_reg_write <= ex_mem_reg_write;
        mem_wb_mem_to_reg <= ex_mem_mem_to_reg;
        mem_wb_jump <= ex_mem_jump;
        mem_wb_pc <= ex_mem_pc;
        mem_wb_lui <= ex_mem_lui;
        mem_wb_imm <= ex_mem_imm;
        mem_wb_funct3 <= ex_mem_funct3;
        mem_wb_addr_low <= ex_mem_addr_low;
    end
 end

endmodule
