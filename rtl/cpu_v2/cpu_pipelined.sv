`ifdef IVERILOG_LINT
`include "../alu/alu.sv"
`endif

// `include "rom.sv"

module cpu_pipelined #(
    parameter PROGROM_SIZE_W = 8192,
    parameter INIT_H = ""
) (
    input wire rst,
    input wire clk,

    output wire [31:0] bus_addr,
    output wire [31:0] bus_wdata,
    output wire [3:0] bus_wmask,
    input [31:0] bus_rdata,
    output wire bus_wen,
    output wire bus_ren,
    input wire bus_done,

    input wire [31:0] progMEM_waddr,
    input wire [31:0] progMEM_wdata,
    output reg [31:0] progMEM_rdata,
    input wire progMEM_wen,
    input wire [3:0] progMEM_wmask

    // output wire [3:0] debug
);
    // TODO: Turn progMEM into a L1 instruction cache
    // Keep the modified harvard (for speed) but it would be good to share program & data memory

    // NOTE: Specifying ram_style explicitly here makes sure that instead of overloading 
    // yosys with FF/LUT RAMs, it just fails synthesis if anything isn't right to use DP16KD
    (* ram_style = "block" *)
    reg [31:0] progMEM[PROGROM_SIZE_W-1:0];
    parameter PROGROM_ADDRBITS = $clog2(PROGROM_SIZE_W);

    initial begin
`ifdef YOSYS_SIM
        // int i;
        // for (i = 0; i < PROGROM_SIZE_W; i = i + 1) begin
        //     progMEM[i] = '0;
        // end
        $readmemh("../../software/programs/test_embedded/build/ecp5_test.hex", progMEM);
`else
        if (INIT_H != "") begin
            $readmemh(INIT_H, progMEM);
        end
`endif
    end

    initial begin
        registers[0]  = 0;
        registers[1]  = 0;
        registers[2]  = 0;
        registers[3]  = 0;
        registers[4]  = 0;
        registers[5]  = 0;
        registers[6]  = 0;
        registers[7]  = 0;
        registers[8]  = 0;
        registers[9]  = 0;
        registers[10] = 0;
        registers[11] = 0;
        registers[12] = 0;
        registers[13] = 0;
        registers[14] = 0;
        registers[15] = 0;
        registers[16] = 0;
        registers[17] = 0;
        registers[18] = 0;
        registers[19] = 0;
        registers[20] = 0;
        registers[21] = 0;
        registers[22] = 0;
        registers[23] = 0;
        registers[24] = 0;
        registers[25] = 0;
        registers[26] = 0;
        registers[27] = 0;
        registers[28] = 0;
        registers[29] = 0;
        registers[30] = 0;
        registers[31] = 0;
    end

    always @(posedge clk) begin
        if (progMEM_wen) begin
            if (progMEM_wmask[0]) progMEM[progMEM_waddr][7:0] <= progMEM_wdata[7:0];
            if (progMEM_wmask[1]) progMEM[progMEM_waddr][15:8] <= progMEM_wdata[15:8];
            if (progMEM_wmask[2]) progMEM[progMEM_waddr][23:16] <= progMEM_wdata[23:16];
            if (progMEM_wmask[3]) progMEM[progMEM_waddr][31:24] <= progMEM_wdata[31:24];
            // progMEM[progMEM_waddr] <= progMEM_wdata;
            // progMEM_rdata <= progMEM_wdata;
        end
        progMEM_rdata <= progMEM[progMEM_waddr];
    end

    // (* no_rw_check *)
    reg [31:0] registers[31:0];
    initial begin
        registers[0] = 0;
    end

    // Fetch = FE
    // Decode = DE
    // Execute = EX
    // Writeback = WB

    // TODO: Use this in the future for flushing failed branch-predicts?
    wire flush_FE = rst;
    wire flush_DE = rst;
    wire flush_EX = rst;
    wire flush_WB = rst;

    // FETCH
    reg [31:0] FE_pc = 0;

    wire unsafe_executing = DE_pc_unsafe || EX_pc_unsafe;
    // assign debug = {DE_valid, EX_valid, WB_valid, unsafe_executing};

    // PC for instruction to fetch
    wire [31:0] fetch_pc = ((WB_pc_unsafe && WB_valid) ? WB_jump_pc : FE_pc);
    reg [31:0] fetch_data;
    always @(posedge clk) begin
        if (~flush_FE && DE_open && ~unsafe_executing)
            DE_instruction_reg <= progMEM[fetch_pc[PROGROM_ADDRBITS+1:2]];
    end

    always @(posedge clk) begin
        if (flush_FE) begin
            FE_pc <= 0;
            DE_pc <= 0;
            // DE_instruction <= 0;
            DE_valid <= 0;
        end else begin
            if (DE_open) begin
                if (~unsafe_executing) begin
                    // DE_instruction <= progMEM[fetch_pc[PROGROM_ADDRBITS+1:2]];
                    // DE_instruction <= fetch_data;
                    FE_pc <= fetch_pc + 4;
                    DE_pc <= fetch_pc;

                    // $display("Issued instruction at PC=%x into pipeline.", fetch_pc);

                    DE_valid <= 1'b1;
                end else begin
                    // DE_instruction <= '0;
                    DE_valid <= 1'b0;
                end
            end
        end
    end

    // DECODE
    wire DE_open = EX_open & ~DE_hazard;
    // wire DE_flush = EX_flush;
    reg [31:0] DE_pc = 0;
    reg [31:0] DE_instruction_reg = 0;
    wire [31:0] DE_instruction = DE_valid ? DE_instruction_reg : '0;
    wire [4:0] DE_opcode = DE_instruction[6:2];
    reg DE_valid = 0;
    wire DE_pc_unsafe = DE_opcode[4];
    // wire DE_instruction_valid = DE_instruction[1:0] == 2'b11;

    wire [4:0] DE_rs1_index = DE_instruction[19:15];
    wire [4:0] DE_rs2_index = DE_instruction[24:20];

    // Detect hazard (dependency) of the current instruction to decode and active instructions in WB and EX.
    wire DE_has_rs1 = ~((DE_opcode == 5'b11011) || (DE_opcode == 5'b00101));
    wire DE_has_rs2 = DE_has_rs1 && ((DE_opcode == 5'b01100) || (DE_opcode == 5'b01000) || (DE_opcode == 5'b11000));
    wire DE_hazard = DE_has_rs1 && (((EX_rd_idx == DE_rs1_index)&&EX_valid) && (DE_rs1_index != 0)) ||
                     DE_has_rs2 && (((EX_rd_idx == DE_rs2_index)&&EX_valid) && (DE_rs2_index != 0));

    // Register forwarding here!
    wire WB_has_DE_rs1 = (WB_rd_idx == DE_rs1_index) && WB_valid && (WB_rd_idx != 0);
    wire WB_has_DE_rs2 = (WB_rd_idx == DE_rs2_index) && WB_valid && (WB_rd_idx != 0);

    always @(posedge clk) begin
        if (flush_DE) begin
            EX_ALU_is_register <= 0;
            EX_inst_is_ALU <= 0;
            EX_inst_is_load <= 0;
            EX_inst_is_store <= 0;
            EX_inst_is_branch <= 0;
            EX_inst_is_jal <= 0;
            EX_inst_is_jalr <= 0;
            EX_inst_is_lui <= 0;
            EX_inst_is_auipc <= 0;
            EX_inst_is_system <= 0;

            EX_rs1 <= 0;
            EX_rs2 <= 0;

            EX_rd_idx <= 0;

            EX_imm_s <= 0;
            EX_imm_i <= 0;
            EX_imm_b <= 0;
            EX_imm_u <= 0;
            EX_imm_j <= 0;

            EX_instruction <= 0;
            EX_begin <= 1'b0;
            EX_valid <= 1'b0;
            EX_pc <= 0;
            EX_pc_unsafe <= 0;
        end else begin
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

                EX_rs1 <= (WB_has_DE_rs1 ? WB_value : registers[DE_rs1_index]);
                EX_rs2 <= (WB_has_DE_rs2 ? WB_value : registers[DE_rs2_index]);

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
                EX_pc <= DE_pc;
            end else begin
                EX_begin <= 1'b0;
                // EX_valid <= 1'b1;
            end

            if (EX_open) begin
                EX_valid <= DE_valid & ~DE_hazard & (DE_instruction[1:0] == 2'b11);
                EX_pc_unsafe <= DE_pc_unsafe;
            end
        end
    end

    // EXECUTE
    wire EX_open = EX_done & WB_open;
    // wire EX_flush = 0;  // Branch miss flush here?
    reg EX_valid = 0;
    reg EX_pc_unsafe = 0;
    reg [31:0] EX_pc = 0;
    reg [31:0] EX_instruction = 0;
    wire [2:0] EX_funct3 = EX_instruction[14:12];
    wire [6:0] EX_funct7 = EX_instruction[31:25];

    wire [3:0] EX_branch_cond_type_onehot = 4'b1 << EX_funct3[2:1];  // Equal, LT, LT(U)
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

    wire EX_done = (~EX_valid) || (EX_inst_is_ALU & alu_done) || (EX_inst_is_load || EX_inst_is_store || EX_inst_is_auipc || EX_inst_is_branch || EX_inst_is_jal || EX_inst_is_jalr || EX_inst_is_system || EX_inst_is_lui);
    wire EX_has_writeback = ~(EX_inst_is_branch || EX_inst_is_store || EX_inst_is_system);

    always @(posedge clk) begin
        if (flush_EX) begin
            WB_valid <= 0;
            WB_pc <= 0;
            WB_ex_writeback <= 0;
            WB_rd_idx <= 0;
            WB_pc_unsafe <= 0;
            WB_jump_pc <= 0;
            WB_is_load_store <= 0;
            WB_loadstore_size_onehot <= 0;
            WB_mem_loadstore_offset <= 0;
            WB_load_signext <= 0;
        end else begin
            if (WB_open) begin
                if (EX_done & EX_valid) begin
                    WB_pc <= EX_pc;
                    WB_rd_idx <= EX_has_writeback ? EX_rd_idx : '0;
                    WB_pc_unsafe <= EX_pc_unsafe;

                    WB_is_load_store <= EX_inst_is_load | EX_inst_is_store;
                    WB_loadstore_size_onehot <= EX_loadstore_size_onehot;
                    WB_mem_loadstore_offset <= EX_mem_loadstore_offset;
                    WB_load_signext <= EX_load_signext;

                    WB_valid <= 1'b1;

                    // Output result
                    case (1'b1)
                        EX_inst_is_ALU: WB_ex_writeback <= alu_out;
                        EX_inst_is_lui: WB_ex_writeback <= EX_imm_u;
                        EX_inst_is_auipc: WB_ex_writeback <= EX_pc + EX_imm_u;
                        (EX_inst_is_jal | EX_inst_is_jalr): WB_ex_writeback <= EX_pc + 4;
                        // EX_inst_is_load: WB_ex_writeback <= load_value;
                        default: WB_ex_writeback <= '0;
                    endcase

                    if (EX_inst_is_branch) begin
                        WB_jump_pc <= EX_branch_cond ? (EX_pc + EX_imm_b) : (EX_pc + 4);
                    end else if (EX_inst_is_jal) begin
                        WB_jump_pc <= EX_pc + EX_imm_j;
                    end else if (EX_inst_is_jalr) begin
                        WB_jump_pc <= EX_rs1 + EX_imm_i;
                    end
                end else begin
                    WB_valid <= 1'b0;
                end
            end
        end
    end

    ////////////////////////// BUS //////////////////////////

    wire [31:0] loadstore_addr = EX_rs1 + (EX_inst_is_store ? EX_imm_s : EX_imm_i);
    wire [29:0] loadstore_word_addr = loadstore_addr[31:2];
    wire [ 1:0] EX_mem_loadstore_offset = loadstore_addr[1:0];

    assign bus_addr = (EX_inst_is_load || EX_inst_is_store) ? loadstore_addr : '0;

    assign bus_ren = EX_inst_is_load && EX_valid;
    assign bus_wen = EX_inst_is_store && EX_valid;

    // Bytewise shifting for write alignment bytes and half
    assign bus_wdata = {
        EX_mem_loadstore_offset[0] ? EX_rs2[7:0] : EX_mem_loadstore_offset[1] ? EX_rs2[15:8] : EX_rs2[31:24],
        EX_mem_loadstore_offset[1] ? EX_rs2[7:0] : EX_rs2[23:16],
        EX_mem_loadstore_offset[0] ? EX_rs2[7:0] : EX_rs2[15:8],
        EX_rs2[7:0]
    };

    wire [2:0] EX_loadstore_size_onehot = 3'b1 << EX_funct3[1:0];
    wire EX_load_signext = ~EX_funct3[2];

    assign bus_wmask = (EX_loadstore_size_onehot[2] ? 4'b1111 : 0) | 
                        (EX_loadstore_size_onehot[1] ? (EX_mem_loadstore_offset[1] ? 4'b1100 : 4'b0011) : 0) |
                        (EX_loadstore_size_onehot[0] ? (
                            EX_mem_loadstore_offset[0] ? (EX_mem_loadstore_offset[1] ? 4'b1000:4'b0010): (EX_mem_loadstore_offset[1] ? 4'b0100:4'b0001) 
                        ) : 0);

    wire [7:0] load_byte = WB_mem_loadstore_offset[0] ? (WB_mem_loadstore_offset[1] ? bus_rdata[31:24]:bus_rdata[15:8]): (WB_mem_loadstore_offset[1] ? bus_rdata[23:16]:bus_rdata[7:0]);
    wire [15:0] load_half = WB_mem_loadstore_offset[1] ? bus_rdata[31:16] : bus_rdata[15:0];
    wire [31:0] load_value = (WB_loadstore_size_onehot[0] ? ({WB_load_signext ? {24{load_byte[7]}}:24'b0, load_byte}) : 32'b0) |
                            (WB_loadstore_size_onehot[1] ? ({WB_load_signext ? {16{load_half[15]}}:16'b0, load_half}) : 32'b0) |
                            (WB_loadstore_size_onehot[2] ? bus_rdata : 32'b0);


    // Writeback
    reg WB_is_load_store = 0;
    reg [2:0] WB_loadstore_size_onehot = 0;
    reg [1:0] WB_mem_loadstore_offset = 0;
    reg WB_load_signext = 0;

    // Need to wait for writes aswell to ensure r/w consistency on high-latency devices
    wire WB_open = (WB_is_load_store && WB_valid) ? bus_done : 1; // TODO: WB needs to not be done/open when bus is not done and doing a read!!!!
    reg WB_valid = 0;
    reg [31:0] WB_pc = 0;
    reg [31:0] WB_ex_writeback = 0;
    wire [31:0] WB_value = WB_is_load_store ? load_value : WB_ex_writeback;
    reg [4:0] WB_rd_idx = 0;
    reg WB_pc_unsafe = 0;
    reg [31:0] WB_jump_pc = 0;

    always @(posedge clk) begin
        if (flush_WB) begin

        end else begin
            if (WB_valid && WB_rd_idx != 0) begin
                registers[WB_rd_idx] <= WB_value;
            end
        end
    end

endmodule
