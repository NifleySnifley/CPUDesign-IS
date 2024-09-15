// `include "../alu/alu.sv"

`ifdef IVERILOG_LINT
`include "../alu/alu.sv"
`endif

module cpu (
    input wire rst,
    input wire clk,

    // Memory interface
    output wire [31:0] mem_addr,
    output reg [31:0] mem_wdata,
    input [31:0] mem_rdata,
    output reg mem_wstrobe,
    input wire mem_done,  // Read or write done

    // Debugging outputs
    output wire instruction_sync,
    output wire [31:0] dbg_output,
    output wire [31:0] dbg_pc
);
    wire [31:0] reg_dbg_x0 = registers[0];
    wire [31:0] reg_dbg_x1 = registers[1];
    wire [31:0] reg_dbg_x2 = registers[2];
    wire [31:0] reg_dbg_x3 = registers[3];
    wire [31:0] reg_dbg_x4 = registers[4];
    wire [31:0] reg_dbg_x5 = registers[5];
    wire [31:0] reg_dbg_x6 = registers[6];
    wire [31:0] reg_dbg_x7 = registers[7];
    wire [31:0] reg_dbg_x8 = registers[8];
    wire [31:0] reg_dbg_x9 = registers[9];
    wire [31:0] reg_dbg_x10 = registers[10];
    wire [31:0] reg_dbg_x11 = registers[11];
    wire [31:0] reg_dbg_x12 = registers[12];
    wire [31:0] reg_dbg_x13 = registers[13];
    wire [31:0] reg_dbg_x14 = registers[14];
    wire [31:0] reg_dbg_x15 = registers[15];
    wire [31:0] reg_dbg_x16 = registers[16];
    wire [31:0] reg_dbg_x17 = registers[17];
    wire [31:0] reg_dbg_x18 = registers[18];
    wire [31:0] reg_dbg_x19 = registers[19];
    wire [31:0] reg_dbg_x20 = registers[20];
    wire [31:0] reg_dbg_x21 = registers[21];
    wire [31:0] reg_dbg_x22 = registers[22];
    wire [31:0] reg_dbg_x23 = registers[23];
    wire [31:0] reg_dbg_x24 = registers[24];
    wire [31:0] reg_dbg_x25 = registers[25];
    wire [31:0] reg_dbg_x26 = registers[26];
    wire [31:0] reg_dbg_x27 = registers[27];
    wire [31:0] reg_dbg_x28 = registers[28];
    wire [31:0] reg_dbg_x29 = registers[29];
    wire [31:0] reg_dbg_x30 = registers[30];
    wire [31:0] reg_dbg_x31 = registers[31];
    assign instruction_sync = (state == STATE_INST_FETCH) & clk;  // High when instruction finishes
    assign dbg_output = registers[10];
    assign dbg_pc = pc;



    // Processor state (one-hot)
    localparam STATE_INST_FETCH = 4'b0001;
    localparam STATE_INST_FETCH_IDX = 0;
    localparam STATE_DECODE = 4'b0010;
    localparam STATE_DECODE_IDX = 1;
    localparam STATE_EXEC = 4'b0100;
    localparam STATE_EXEC_IDX = 2;
    localparam STATE_WRITEBACK = 4'b1000;
    localparam STATE_WRITEBACK_IDX = 3;
    reg [ 3:0] state;

    // Register file
    reg [31:0] registers[0:31];
    initial begin
        registers[0] = 0;
    end

    // PC
    reg [31:0] pc = 0;

    //////////////////// INSTRUCTION DECODING ////////////////////
    // Current instruction (@PC)
    reg [31:0] instruction;

    wire [4:0] opcode = instruction[6:2];
    wire [1:0] instruction_length = instruction[1:0];  // NOTE: MUST be 2'b11 for rv32i
    // Registers
    wire [4:0] rd = instruction[11:7];
    wire [4:0] rs1 = instruction[19:15];
    wire [4:0] rs2 = instruction[24:20];

    wire inst_has_rs1 = ~(inst_is_lui || inst_is_auipc || inst_is_jal);
    wire inst_has_rs2 = ALU_is_register || inst_is_store || inst_is_branch;

    // Immediates
    wire [31:0] imm_s = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
    wire [31:0] imm_i = {{20{instruction[31]}}, instruction[31:20]};
    wire [31:0] imm_b = {
        {20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0
    };
    wire [31:0] imm_u = {instruction[31:12], 12'b0};
    wire [31:0] imm_j = {
        {12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0
    };

    // Instruction types
    wire ALU_is_register = opcode == 5'b01100;
    wire inst_is_ALU = ALU_is_register | (opcode == 5'b00100);
    wire inst_is_load = ~|opcode;
    wire inst_is_store = opcode == 5'b01000;
    wire inst_is_branch = opcode == 5'b11000;
    wire inst_is_jal = opcode == 5'b11011;
    wire inst_is_jalr = opcode == 5'b11001;
    wire inst_is_lui = opcode == 5'b01101;
    wire inst_is_auipc = opcode == 5'b00101;
    wire inst_is_system = opcode == 5'b11100;

    ////////////// ALU STUFF //////////////
    wire [2:0] funct3 = instruction[14:12];
    // HACK: funct7 only NEEDS to be 0 when adding immediates AFAIK
    // Because the only instructions that use funct7 are shifts (mask the funct7 bits of the immediate) and add (0x20 for sub on REGISTER ONLY)
    wire [6:0] funct7 = (ALU_is_register || (~|funct3)) ? instruction[31:25] : 7'b0;

    wire [31:0] alu_op1 = rs1_value;
    wire [31:0] alu_op2 = ALU_is_register ? rs2_value : imm_i;
    wire [31:0] alu_out;

    // TODO: Add all wires and fix intellisense????
    alu _alu (
        .in1(alu_op1),
        .in2(alu_op2),
        .out(alu_out),
        .clk,
        .rst,
        .funct3,
        .funct7
    );

    reg [31:0] rs1_value;
    reg [31:0] rs2_value;

    ////////////// BRANCH STUFF //////////////
    wire [2:0] branch_cond_type_onehot = 3'b1 << funct3[2:1];  // Equal, LT, LT(U)
    wire branch_cond_inverted = funct3[0];  // Flip output
    reg branch_test = (branch_cond_type_onehot[0] ? rs1_value == rs2_value : 1'b0) |
    (branch_cond_type_onehot[1] ? $signed(
        rs1_value
    ) < $signed(
        rs2_value
    ) : 1'b0) | (branch_cond_type_onehot[2] ? rs1_value < rs2_value : 1'b0);  // Lt (U)
    wire branch_cond = branch_test ^ branch_cond_inverted;

    ////////////// PC STUFF //////////////
    wire [31:0] pc_advanced = pc + 4;
    wire jumping = inst_is_jal || inst_is_jalr || (inst_is_branch && branch_cond);
    wire [31:0] pc_op1 = inst_is_jalr ? rs1_value : pc;
    wire [31:0] pc_op2 = (inst_is_branch ? imm_b : 0) | (inst_is_jal ? imm_j : 0) | (inst_is_jalr ? imm_i : 0);
    wire [31:0] pc_next = (~jumping) ? pc_advanced : (pc_op1 + pc_op2);

    // TODO: Multiplex this for loads/stores
    assign mem_addr = (state == STATE_INST_FETCH | state == STATE_WRITEBACK) ? pc : 32'b0;

    wire inst_is_exec = inst_is_ALU;  // TODO: So far ALU, add memory operations and system instructions

    wire inst_has_writeback = ~(inst_is_branch || inst_is_store);
    // reg [31:0] writeback_value;
    wire [31:0] writeback_value = (inst_is_lui ? imm_u : 32'b0) | 
        (inst_is_auipc ? (imm_u + pc) : 32'b0) | 
        ((inst_is_jal | inst_is_jalr) ? pc_advanced : 32'b0) | 
        (inst_is_ALU ? alu_out : 32'b0);

    wire exec_done = inst_is_ALU;

    always @(posedge clk) begin
        if (rst) begin
            instruction <= 32'b0;
            state <= STATE_INST_FETCH;
            pc <= 32'b0;
            mem_wstrobe <= 1'b0;
            mem_wdata <= 32'b0;
        end else begin
            unique case (1'b1)
                state[STATE_INST_FETCH_IDX]: begin
                    if (mem_done) begin
                        instruction <= mem_rdata;
                        state <= STATE_DECODE;
                    end else begin
                        state <= STATE_INST_FETCH;
                    end
                end
                state[STATE_DECODE_IDX]: begin
                    if (inst_has_rs1) rs1_value <= registers[rs1];
                    if (inst_has_rs2) rs2_value <= registers[rs2];

                    state <= inst_is_exec ? STATE_EXEC : STATE_WRITEBACK;
                end
                state[STATE_EXEC_IDX]: begin
                    // Only for ALU, mem, etc.
                    if (exec_done) state <= STATE_WRITEBACK;
                end
                state[STATE_WRITEBACK_IDX]: begin
                    pc <= jumping ? pc_next : pc_advanced;

                    // Don't write to x0 (always 32'b0)
                    if (inst_has_writeback & (|rd)) begin
                        registers[rd] <= writeback_value;
                    end

                    state <= STATE_INST_FETCH;
                end
                default: state <= STATE_INST_FETCH;
            endcase
        end
    end
endmodule
