// `include "../alu/alu.sv"

`ifdef IVERILOG_LINT
`include "../alu/alu.sv"
`endif

module cpu (
    input wire rst,
    input wire clk,

    // Memory interface
    output wire [31:0] bus_addr,
    output wire [31:0] bus_wdata,
    output wire [3:0] bus_wmask,
    input [31:0] bus_rdata,
    output wire bus_wen,
    output wire bus_ren,
    input wire bus_done,  // Read or write done

    // Debugging outputs
    output reg instruction_sync,
    output wire [31:0] dbg_pc
);
    // Debugging stuff
    // assign instruction_sync = (state == STATE_INST_FETCH) & clk;  // High when instruction finishes
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

    (* onehot *)
    reg [ 3:0] state;

    // Register file
    (* no_rw_check *)
    reg [31:0] registers[31:0];
    initial begin
        registers[0] = 0;
    end

    // PC
    reg [31:0] pc = 0;

    //////////////////// INSTRUCTION DECODING ////////////////////
    // Current instruction (@PC)
    reg [31:0] instruction = 0;

    wire [4:0] opcode = instruction[6:2];
    wire [1:0] instruction_length = instruction[1:0];  // NOTE: MUST be 2'b11 for rv32i
    // Registers
    wire [4:0] rd = instruction[11:7];
    wire [4:0] rs1 = instruction[19:15];
    wire [4:0] rs2 = instruction[24:20];

    // wire inst_has_rs1 = ~(inst_is_lui || inst_is_auipc || inst_is_jal);
    // wire inst_has_rs2 = ALU_is_register || inst_is_store || inst_is_branch;

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

    wire [2:0] loadstore_size_onehot = 3'b1 << funct3[1:0];
    wire load_signext = ~funct3[2];

    // Instruction types
    wire ALU_is_register = opcode == 5'b01100;
    wire inst_is_ALU = ALU_is_register || (opcode == 5'b00100);
    wire inst_is_load = opcode == 5'b00000;
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
    wire [6:0] funct7 = instruction[31:25];

    wire [31:0] alu_op1 = rs1_value;
    wire [31:0] alu_op2 = ALU_is_register ? rs2_value : imm_i;
    wire [31:0] alu_out;
    wire alu_done;
    reg alu_ready;

    // TODO: Add all wires and fix intellisense????
    alu alu0 (
        .in1(alu_op1),
        .in2(alu_op2),
        .is_imm(~ALU_is_register),
        .out(alu_out),
        .ready(alu_ready),
        .clk,
        .rst,
        .funct3,
        .funct7,
        .done(alu_done)
    );

    reg [31:0] rs1_value;
    reg [31:0] rs2_value;

    ////////////// BRANCH STUFF //////////////
    (* onehot *)
    wire [3:0] branch_cond_type_onehot = 3'b1 << funct3[2:1];  // Equal, LT, LT(U)
    wire branch_cond_inverted = funct3[0];  // Flip output
    reg branch_test = (branch_cond_type_onehot[0] ? rs1_value == rs2_value : 1'b0) |
    (branch_cond_type_onehot[2] ? $signed(
        rs1_value
    ) < $signed(
        rs2_value
    ) : 1'b0) | (branch_cond_type_onehot[3] ? rs1_value < rs2_value : 1'b0);  // Lt (U)
    wire branch_cond = branch_test ^ branch_cond_inverted;

    ////////////// PC STUFF //////////////
    wire [31:0] pc_advanced = pc + 4;
    wire jumping = inst_is_jal || inst_is_jalr || (inst_is_branch && branch_cond);
    wire [31:0] pc_op1 = inst_is_jalr ? rs1_value : pc;
    wire [31:0] pc_op2 = (inst_is_branch ? imm_b : 0) | (inst_is_jal ? imm_j : 0) | (inst_is_jalr ? imm_i : 0);
    wire [31:0] pc_next = (~jumping) ? pc_advanced : (pc_op1 + pc_op2);

    wire [31:0] loadstore_addr = rs1_value + (inst_is_store ? imm_s : imm_i);

    assign bus_addr = (state[STATE_INST_FETCH_IDX]) ? pc : ((inst_is_store || inst_is_load) ? loadstore_addr : pc);
    wire [1:0] mem_loadstore_offset = loadstore_addr[1:0];
    // TODO: Actually use this read strobe
    assign bus_ren = inst_is_load && state[STATE_EXEC_IDX] || state[STATE_INST_FETCH_IDX];  // Always for just mem reads!
    assign bus_wen = inst_is_store && state[STATE_EXEC_IDX];

    // Bytewise shifting for write alignment bytes and half
    // FIXME: This will can pottentially cause partial/scrambled words to be written if unaligned accesses are attempted with words/halfs
    assign bus_wdata = {
        mem_loadstore_offset[0] ? rs2_value[7:0] : mem_loadstore_offset[1] ? rs2_value[15:8] : rs2_value[31:24],
        mem_loadstore_offset[1] ? rs2_value[7:0] : rs2_value[23:16],
        mem_loadstore_offset[0] ? rs2_value[7:0] : rs2_value[15:8],
        rs2_value[7:0]
    };

    assign bus_wmask = (loadstore_size_onehot[2] ? 4'b1111 : 0) | 
                        (loadstore_size_onehot[1] ? (mem_loadstore_offset[1] ? 4'b1100 : 4'b0011) : 0) |
                        (loadstore_size_onehot[0] ? (
                            mem_loadstore_offset[0] ? (mem_loadstore_offset[1] ? 4'b1000:4'b0010): (mem_loadstore_offset[1] ? 4'b0100:4'b0001) 
                        ) : 0);

    wire [7:0] load_byte = mem_loadstore_offset[0] ? (mem_loadstore_offset[1] ? bus_rdata[31:24]:bus_rdata[15:8]): (mem_loadstore_offset[1] ? bus_rdata[23:16]:bus_rdata[7:0]);
    wire [15:0] load_half = mem_loadstore_offset[1] ? bus_rdata[31:16] : bus_rdata[15:0];
    wire [31:0] load_value = (loadstore_size_onehot[0] ? ({load_signext ? {24{load_byte[7]}}:24'b0, load_byte}) : 32'b0) |
                            (loadstore_size_onehot[1] ? ({load_signext ? {16{load_half[15]}}:16'b0, load_half}) : 32'b0) |
                            (loadstore_size_onehot[2] ? bus_rdata : 32'b0);

    // DONE: Allow combinatorial ALU ops to skip execute phase (inst_is_ALU && ~alu_ready && alu_combinatorial)
    wire inst_is_exec = (inst_is_ALU && ~alu_ready) || inst_is_load || inst_is_store;  // TODO: So far ALU, add memory operations and system instructions

    wire inst_has_writeback = ~(inst_is_branch || inst_is_store);
    // reg [31:0] writeback_value;
    wire [31:0] writeback_value = (inst_is_lui ? imm_u : 32'b0) | 
        (inst_is_auipc ? (imm_u + pc) : 32'b0) | 
        ((inst_is_jal | inst_is_jalr) ? pc_advanced : 32'b0) | 
        (inst_is_ALU ? alu_out : 32'b0) | 
        (inst_is_load ? load_value : 32'b0);

    wire exec_done = (inst_is_ALU && alu_done) || ((inst_is_load || inst_is_store) && bus_done);

    always @(posedge clk) begin
        if (rst) begin
            instruction <= 32'b0;
            state <= STATE_INST_FETCH;
            pc <= 32'b0;
        end else begin
            unique case (1'b1)
                state[STATE_INST_FETCH_IDX]: begin
                    instruction_sync <= 1'b0;
                    if (bus_done) begin
                        instruction <= bus_rdata;
                        state <= STATE_DECODE;
                    end else begin
                        state <= STATE_INST_FETCH;
                    end
                end
                state[STATE_DECODE_IDX]: begin
                    rs1_value <= registers[rs1];
                    rs2_value <= registers[rs2];

                    state <= inst_is_exec ? STATE_EXEC : STATE_WRITEBACK;
                    alu_ready <= 1'b1;
                end
                state[STATE_EXEC_IDX]: begin
                    // Only for ALU, mem, etc.
                    alu_ready <= 1'b0;
                    if (exec_done) state <= STATE_WRITEBACK;
                end
                state[STATE_WRITEBACK_IDX]: begin
                    pc <= jumping ? pc_next : pc_advanced;
                    alu_ready <= 1'b0;

                    if (inst_has_writeback && (|rd)) begin
                        registers[rd] <= writeback_value;
                    end

                    state <= STATE_INST_FETCH;
                    instruction_sync <= 1'b1;
                end
                default: state <= STATE_INST_FETCH;
            endcase
        end
    end
endmodule
