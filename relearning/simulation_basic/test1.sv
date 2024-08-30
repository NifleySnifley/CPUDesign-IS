`default_nettype none

module test1 (
    input [99:0] inp,
    output logic out_xor
);
    always_comb begin
        out_xor = ^inp;
    end
endmodule
