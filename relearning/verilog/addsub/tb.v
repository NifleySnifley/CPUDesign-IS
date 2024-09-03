module tb ();
    reg CLK;

    reg sub;
    reg [31:0] a;
    reg [31:0] b;
    wire signed [31:0] result;

    addsub uut (
        .is_sub(sub),
        .a(a),
        .b(b),
        .out(result)
    );

    reg [4:0] prev_LEDS = 0;
    initial begin
        #1 a <= 312;
        #1 b <= 1000;
        #1 sub <= 1'b0;
        #1 $display("a = %d, b = %d, a+b = %d\n", a, b, result);
        #1 sub <= 1'b1;
        #1 $display("a = %d, b = %d, a-b = %d\n", a, b, result);
    end
endmodule
