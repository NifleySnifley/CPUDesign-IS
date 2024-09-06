module add_sub (
    input is_sub,
    input [31:0] a,
    input [31:0] b,
    output [31:0] out,
    output carry_flag
);

    // Is this better? or is it better to have a different "operand" with negation?
    assign {carry_flag, out} = (is_sub ? (a - b) : (a + b));
endmodule
