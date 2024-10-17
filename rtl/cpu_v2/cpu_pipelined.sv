`ifdef IVERILOG_LINT
`include "../alu/alu.sv"
`endif

module cpu_pipelined #(
    parameter PROGROM_SIZE_W = 2048,
    parameter RAM_SIZE_W = 2048
) (
    input wire rst,
    input wire clk
);
    // TODO: Turn progMEM into a L1 instruction cache
    // Keep the modified harvard (for speed) but it would be good to share program & data memory
    reg [31:0] progMEM[PROGROM_SIZE_W-1:0];
    reg [31:0] ramMEM[RAM_SIZE_W-1:0];
    parameter PROGROM_ADDRBITS = $clog2(PROGROM_SIZE_W);
    parameter RAM_ADDRBITS = $clog2(RAM_SIZE_W);

    (* no_rw_check *)
    reg [31:0] registers[31:0];
    initial begin
        registers[0] = 0;
    end

    // Fetch = FE
    // Decode = DE
    // Execute = EX
    // Writeback = WB

    // FETCH
    reg [31:0] FE_pc = 0;
    // wire FE_flush = DE_flush;

    wire unsafe_executing = DE_pc_unsafe || EX_pc_unsafe;

    always @(posedge clk) begin
        if (DE_open && ~unsafe_executing) begin
            DE_instruction <= progMEM[FE_pc[PROGROM_ADDRBITS+1:2]];
            FE_pc <= WB_pc_unsafe ? WB_jump_pc : FE_pc + 4;

            DE_pc <= FE_pc;
            DE_valid <= 1'b1;
        end else begin
            DE_valid <= ~unsafe_executing;
        end
    end

    // DECODE
    wire DE_open = EX_open & ~DE_hazard;
    // wire DE_flush = EX_flush;
    reg [31:0] DE_pc = 0;
    reg [31:0] DE_instruction;
    wire [4:0] DE_opcode = DE_instruction[6:2];
    reg DE_valid = 0;
    wire DE_pc_unsafe = DE_opcode[4];
    // wire DE_instruction_valid = DE_instruction[1:0] == 2'b11;

    wire [4:0] DE_rs1_index = DE_instruction[19:15];
    wire [4:0] DE_rs2_index = DE_instruction[24:20];

    // Detect hazard (dependency) of the current instruction to decode and active instructions in WB and EX.
    wire DE_has_rs1 = ~((DE_opcode == 5'b11011) || (DE_opcode == 5'b00101) || (DE_opcode == 5'b11001));
    wire DE_has_rs2 = DE_has_rs1 && ((DE_opcode == 5'b01100) || (DE_opcode == 5'b01000) || (DE_opcode == 5'b11000));
    wire DE_hazard = DE_has_rs1 && (((EX_rd_idx == DE_rs1_index)&&EX_valid || (WB_rd_idx == DE_rs1_index)&&WB_valid) && (DE_rs1_index != 0)) ||
                     DE_has_rs2 && (((EX_rd_idx == DE_rs2_index)&&EX_valid || (WB_rd_idx == DE_rs2_index)&&WB_valid) && (DE_rs2_index != 0));

    always @(posedge clk) begin
        if (EX_open & DE_valid & ~DE_hazard) begin
            // Load into execute stage
            EX_ALU_is_register <= DE_opcode == 5'b01100;
            EX_inst_is_ALU <= (DE_opcode == 5'b01100) || (DE_opcode == 5'b00100);
            EX_inst_is_load <= DE_opcode == 5'b00000;
            EX_inst_is_store <= DE_opcode == 5'b01000;
            EX_inst_is_branch <= DE_opcode == 5'b11000;
            EX_inst_is_jal <= DE_opcode == 5'b11011;
            EX_inst_is_jalr <= DE_opcode == 5'b11001;
            EX_inst_is_lui <= DE_opcode == 5'b01101;
            EX_inst_is_auipc <= DE_opcode == 5'b00101;
            EX_inst_is_system <= DE_opcode == 5'b11100;

            // TODO: Implement result forwarding here (take from before writeback stage)
            EX_rs1 <= registers[DE_rs1_index];
            EX_rs2 <= registers[DE_rs2_index];

            EX_rd_idx <= DE_instruction[11:7];

            EX_imm_s <= {{20{DE_instruction[31]}}, DE_instruction[31:25], DE_instruction[11:7]};
            EX_imm_i <= {{20{DE_instruction[31]}}, DE_instruction[31:20]};
            EX_imm_b <= {
                {20{DE_instruction[31]}},
                DE_instruction[7],
                DE_instruction[30:25],
                DE_instruction[11:8],
                1'b0
            };
            EX_imm_u <= {DE_instruction[31:12], 12'b0};
            EX_imm_j <= {
                {12{DE_instruction[31]}},
                DE_instruction[19:12],
                DE_instruction[20],
                DE_instruction[30:21],
                1'b0
            };

            EX_instruction <= DE_instruction;

            EX_begin <= 1'b1;
            // EX_valid <= 1'b1;
            EX_pc_unsafe <= DE_pc_unsafe;
            EX_pc <= DE_pc;
        end else begin
            EX_begin <= 1'b0;
            // EX_valid <= 1'b1;
        end

        if (EX_open) EX_valid <= DE_valid & ~DE_hazard & (DE_instruction[1:0] == 2'b11);
    end

    // EXECUTE
    wire EX_open = EX_done & WB_open;
    // wire EX_flush = 0;  // Branch miss flush here?
    reg EX_valid = 0;
    reg EX_pc_unsafe = 0;
    reg [31:0] EX_pc = 0;
    reg [31:0] EX_instruction;
    wire [2:0] EX_funct3 = EX_instruction[14:12];
    wire [6:0] EX_funct7 = EX_instruction[31:25];

    wire [3:0] EX_branch_cond_type_onehot = 3'b1 << EX_funct3[2:1];  // Equal, LT, LT(U)
    wire EX_branch_cond_inverted = EX_funct3[0];  // Flip output
    wire EX_branch_cond =  ((EX_branch_cond_type_onehot[0] ? EX_rs1 == EX_rs2 : 1'b0) |
                    (EX_branch_cond_type_onehot[2] ? $signed(
        EX_rs1
    ) < $signed(
        EX_rs2
    ) : 1'b0) | (EX_branch_cond_type_onehot[3] ? EX_rs1 < EX_rs2 : 1'b0)) ^
        EX_branch_cond_inverted;  // Lt (U);

    reg [4:0] EX_rd_idx = 0;
    reg [31:0] EX_rs1 = 0;
    reg [31:0] EX_rs2 = 0;

    reg [31:0] EX_imm_s = 0;
    reg [31:0] EX_imm_i = 0;
    reg [31:0] EX_imm_b = 0;
    reg [31:0] EX_imm_u = 0;
    reg [31:0] EX_imm_j = 0;

    reg EX_ALU_is_register = 0;
    reg EX_inst_is_ALU = 0;
    reg EX_inst_is_load = 0;
    reg EX_inst_is_store = 0;
    reg EX_inst_is_branch = 0;
    reg EX_inst_is_jal = 0;
    reg EX_inst_is_jalr = 0;
    reg EX_inst_is_lui = 0;
    reg EX_inst_is_auipc = 0;
    reg EX_inst_is_system = 0;

    reg EX_begin = 0;

    wire [31:0] alu_op1 = EX_rs1;
    wire [31:0] alu_op2 = EX_ALU_is_register ? EX_rs2 : EX_imm_i;
    wire [31:0] alu_out;
    wire alu_done;

    alu alu0 (
        .in1(alu_op1),
        .in2(alu_op2),
        .is_imm(EX_inst_is_ALU && ~EX_ALU_is_register),
        .out(alu_out),
        .ready(EX_begin),
        .clk,
        .rst,
        .funct3(EX_funct3),
        .funct7(EX_funct7),
        .done(alu_done)
    );

    reg EX_waiting = 0;
    // TODO: Implement proper bus, instead of single-cycle local stores
    // ((EX_inst_is_load || EX_inst_is_store) & bus_done)

    wire EX_done = (~EX_valid) || (EX_inst_is_ALU & alu_done) || ((EX_inst_is_load && bus_done) || (EX_inst_is_store && bus_done) || EX_inst_is_auipc || EX_inst_is_branch || EX_inst_is_jal || EX_inst_is_jalr || EX_inst_is_system || EX_inst_is_lui);
    wire EX_has_writeback = ~(EX_inst_is_branch || EX_inst_is_store || EX_inst_is_system);

    always @(posedge clk) begin
        if (EX_done & EX_valid & WB_open) begin
            WB_pc <= EX_pc;
            WB_rd_idx <= EX_has_writeback ? EX_rd_idx : '0;
            WB_pc_unsafe <= EX_pc_unsafe;
            WB_valid <= 1'b1;

            // Output result
            case (1'b1)
                EX_inst_is_ALU: WB_value <= alu_out;
                EX_inst_is_lui: WB_value <= EX_imm_u;
                EX_inst_is_auipc: WB_value <= EX_pc + EX_imm_u;
                (EX_inst_is_jal | EX_inst_is_jalr): WB_value <= EX_pc + 4;
                EX_inst_is_load: WB_value <= load_value;
                default: WB_value <= '0;
            endcase

            if (EX_inst_is_branch) begin
                WB_jump_pc <= EX_branch_cond ? (EX_pc + EX_imm_b) : (EX_pc + 4);
            end else if (EX_inst_is_jal) begin
                WB_jump_pc <= EX_pc + EX_imm_j;
            end else if (EX_inst_is_jalr) begin
                WB_jump_pc <= EX_pc + EX_rs1 + EX_imm_i;
            end
        end else begin
            WB_valid <= 1'b0;
        end
    end

    ////////////////////////// SIMULATED BUS //////////////////////////

    wire [31:0] loadstore_addr = EX_rs1 + (EX_inst_is_store ? EX_imm_s : EX_imm_i);
    wire [29:0] loadstore_word_addr = loadstore_addr[31:2];
    wire [1:0] mem_loadstore_offset = loadstore_addr[1:0];

    reg [31:0] bus_rdata;
    reg [31:0] bus_xact_addr = 0;
    wire bus_done = bus_xact_addr == {bus_ren, bus_wen, loadstore_word_addr};
    always @(posedge clk) begin
        if (bus_wen) begin
            if (bus_wmask[0]) ramMEM[loadstore_word_addr[RAM_ADDRBITS-1:0]][7:0] <= bus_wdata[7:0];
            if (bus_wmask[1])
                ramMEM[loadstore_word_addr[RAM_ADDRBITS-1:0]][15:8] <= bus_wdata[15:8];
            if (bus_wmask[2])
                ramMEM[loadstore_word_addr[RAM_ADDRBITS-1:0]][23:16] <= bus_wdata[23:16];
            if (bus_wmask[3])
                ramMEM[loadstore_word_addr[RAM_ADDRBITS-1:0]][31:24] <= bus_wdata[31:24];
            bus_xact_addr <= {bus_ren, bus_wen, loadstore_word_addr};
            // bus_rdata <= bus_wdata;
        end else if (bus_ren) begin
            bus_rdata <= ramMEM[loadstore_word_addr[RAM_ADDRBITS-1:0]];
            bus_xact_addr <= {bus_ren, bus_wen, loadstore_word_addr};
        end
    end

    wire bus_ren = EX_inst_is_load && EX_valid;
    wire bus_wen = EX_inst_is_store && EX_valid;

    // Bytewise shifting for write alignment bytes and half
    wire [31:0] bus_wdata = {
        mem_loadstore_offset[0] ? EX_rs2[7:0] : mem_loadstore_offset[1] ? EX_rs2[15:8] : EX_rs2[31:24],
        mem_loadstore_offset[1] ? EX_rs2[7:0] : EX_rs2[23:16],
        mem_loadstore_offset[0] ? EX_rs2[7:0] : EX_rs2[15:8],
        EX_rs2[7:0]
    };

    wire [2:0] loadstore_size_onehot = 3'b1 << EX_funct3[1:0];
    wire load_signext = ~bus_rdata[14];  // funct3[2]

    wire[3:0] bus_wmask = (loadstore_size_onehot[2] ? 4'b1111 : 0) | 
                        (loadstore_size_onehot[1] ? (mem_loadstore_offset[1] ? 4'b1100 : 4'b0011) : 0) |
                        (loadstore_size_onehot[0] ? (
                            mem_loadstore_offset[0] ? (mem_loadstore_offset[1] ? 4'b1000:4'b0010): (mem_loadstore_offset[1] ? 4'b0100:4'b0001) 
                        ) : 0);

    wire [7:0] load_byte = mem_loadstore_offset[0] ? (mem_loadstore_offset[1] ? bus_rdata[31:24]:bus_rdata[15:8]): (mem_loadstore_offset[1] ? bus_rdata[23:16]:bus_rdata[7:0]);
    wire [15:0] load_half = mem_loadstore_offset[1] ? bus_rdata[31:16] : bus_rdata[15:0];
    wire [31:0] load_value = (loadstore_size_onehot[0] ? ({load_signext ? {24{load_byte[7]}}:24'b0, load_byte}) : 32'b0) |
                            (loadstore_size_onehot[1] ? ({load_signext ? {16{load_half[15]}}:16'b0, load_half}) : 32'b0) |
                            (loadstore_size_onehot[2] ? bus_rdata : 32'b0);



    // TODO: Prevent writing over and over again when execute is waiting for like, division or something!
    wire WB_open = 1;
    reg WB_valid = 0;
    reg [31:0] WB_pc = 0;
    reg [31:0] WB_value;
    reg [4:0] WB_rd_idx = 0;
    reg WB_pc_unsafe = 0;
    reg [31:0] WB_jump_pc = 0;

    always @(posedge clk) begin
        if (WB_valid && WB_rd_idx != 0) begin
            registers[WB_rd_idx] <= WB_value;
        end
    end

endmodule
