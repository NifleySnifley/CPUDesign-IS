`include "../common/defs.sv"

module alu (
    input wire clk,
    input wire rst,

    // Control
    input  alu_start,  // FIXME: UNUSED
    output alu_done,   // FIXME: UNUSED

    // Operands
    input [31:0] in1,
    input [31:0] in2,
    // Operator
    input [2:0] funct3,
    input [6:0] funct7,
    // Output
    output reg [31:0] out
);
    wire start_posedge;
    assign alu_done = 1'b1;  // HACK: Properly assign this?

    reg start_prev;
    assign start_posedge = alu_start & ~start_prev;

    // Shift amount bits
    wire [4:0] samt;
    assign samt = in2[4:0];

    // TODO: Is it more efficient to demux immediates into 32-wide inputs, or have a seperate logic chain for immediates and immediate inputs to the ALU?
    // FIXME: Make sure funct7 properly works with immediates!!!!
    always_comb begin
        case (funct3)
            // TODO: Optimize to use only one adder
            FUNCT3_ADD_SUB: out = ((funct7 == FUNCT7_SUB) ? (in1 - in2) : (in1 + in2));
            FUNCT3_XOR: out = in1 ^ in2;
            FUNCT3_OR: out = in1 | in2;
            FUNCT3_AND: out = in1 & in2;
            FUNCT3_SLL: out = in1 << samt;
            // TIL: verilog has >>> for arithmetic shifts!
            FUNCT3_SRL_SRA: out = (funct7 == FUNCT7_SRA) ? ($signed(in1) >>> samt) : (in1 >> samt);
            FUNCT3_SLT: out = {31'b0, in1 < in2};
            FUNCT3_SLTU: out = {31'b0, $signed(in1) < $signed(in2)};
            default: out = 32'b0;  // Not neccesary?
        endcase
    end
endmodule
