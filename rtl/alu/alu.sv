`include "../common/defs.sv"

module alu (
    input wire clk,
    input wire rst,

    // Operands
    input [31:0] in1,
    input [31:0] in2,
    input is_imm,
    input ready,
    // Operator
    input [2:0] funct3,
    input [6:0] funct7,
    // Output
    output reg [31:0] out,
    output wire done
);
    // Shift amount bits
    wire [4:0] samt;
    assign samt = in2[4:0];

    (* onehot *)
    wire [7:0] onehot_funct3 = 1 << funct3;

    //////////////////////////////////////// SHIFTER ////////////////////////////////////////
    wire [31:0] shifter_in = shift_is_left ? {in1[0],in1[1],in1[2],in1[3],in1[4],in1[5],in1[6],in1[7],in1[8],in1[9],in1[10],in1[11],in1[12],in1[13],in1[14],in1[15],in1[16],in1[17],in1[18],in1[19],in1[20],in1[21],in1[22],in1[23],in1[24],in1[25],in1[26],in1[27],in1[28],in1[29],in1[30],in1[31]}: in1;
    wire shift_is_left = onehot_funct3[1];
    wire shifter_ext = (funct7 == FUNCT7_SRA);
    wire [32:0] shl = $signed({shifter_ext & shifter_in[31], shifter_in}) >>> samt;
    wire [31:0] shifter_out = shift_is_left ? {shl[0],shl[1],shl[2],shl[3],shl[4],shl[5],shl[6],shl[7],shl[8],shl[9],shl[10],shl[11],shl[12],shl[13],shl[14],shl[15],shl[16],shl[17],shl[18],shl[19],shl[20],shl[21],shl[22],shl[23],shl[24],shl[25],shl[26],shl[27],shl[28],shl[29],shl[30],shl[31]} : shl[31:0];

    wire is_m_extension = (~is_imm) && (funct7 == FUNCT7_M);

    //////////////////////////////////////// MULTIPLIER ////////////////////////////////////////
    wire mul = onehot_funct3[0];
    wire mulh = onehot_funct3[1];
    wire mulhsu = onehot_funct3[2];
    wire mulhu = onehot_funct3[3];
    wire signed [63:0] mul_out = $signed(
        {(mul | mulh | mulhsu) & in1[31], $signed(in1)}
    ) * $signed(
        {(mul | mulh) & in2[31], $signed(in2)}
    );  // Infers DSP Multiplier on FPGA

    //////////////////////////////////////// DIVIDER ////////////////////////////////////////
    wire is_division = is_m_extension && (|onehot_funct3[7:4]);
    // Extra wide to simplify shifting logic
    reg [63:0] dividend;
    reg [63:0] divisor;
    reg [31:0] quotient;
    wire [31:0] remainder = dividend[31:0];
    reg [5:0] div_bit = 0;
    wire division_busy = |div_bit;
    wire [63:0] next_dividend = dividend - divisor;

    always @(posedge clk) begin
        if (is_division) begin
            if (ready) begin
                div_bit <= 6'd31;
                $display("%d, %d\n", in1, in2);
                dividend <= {32'b0, in1};  // TODO: Sign extend?
                divisor  <= {1'b0, in2, 31'b0};  // TODO: Sign extend?
                quotient <= 0;
            end else begin
                quotient <= {quotient[30:0], ~next_dividend[63]};
                divisor  <= divisor >> 1;  //
                if (~next_dividend[63]) dividend <= next_dividend;
                div_bit <= div_bit - 1;
            end
        end
    end

    assign done = is_division ? ~division_busy : 1'b1;

    always_comb begin
        unique case (1'b1)
            onehot_funct3[0]: begin
                if (~is_imm && (funct7 == FUNCT7_SUB)) begin
                    out = (in1 - in2);
                end else if (is_m_extension) begin
                    out = mul_out[31:0];
                end else begin  // FUNCT7_I -> MUL
                    out = (in1 + in2);
                end
            end
            onehot_funct3[1]: out = (is_m_extension) ? mul_out[63:32] : shifter_out;
            onehot_funct3[2]:
            out = (is_m_extension) ? mul_out[63:32] : {31'b0, $signed(in1) < $signed(in2)};
            onehot_funct3[3]: out = (is_m_extension) ? mul_out[63:32] : {31'b0, in1 < in2};
            onehot_funct3[4]: out = is_m_extension ? quotient : (in1 ^ in2);
            onehot_funct3[5]: out = is_m_extension ? quotient : shifter_out;
            onehot_funct3[7]: out = is_m_extension ? remainder : (in1 & in2);
            onehot_funct3[6]: out = is_m_extension ? remainder : (in1 | in2);
            default: out = 32'b0;
        endcase
    end
    // default: out = 32'b0;

endmodule
