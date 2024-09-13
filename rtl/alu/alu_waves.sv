`include "alu.sv"
`default_nettype none `timescale 1ps / 1ps

module tb_alu;
    reg clk;
    reg rst_n;
    reg alu_start;

    wire alu_done;
    wire [31:0] out;

    reg [31:0] in1;
    reg [31:0] in2;
    reg [6:0] funct7;
    reg [2:0] funct3;

    alu dut (
        .rst(~rst_n),
        .out,
        .clk,
        .in1,
        .in2,
        .alu_start,
        .alu_done,
        .funct3,
        .funct7
    );

    localparam CLK_PERIOD = 2;
    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        $dumpfile("tb_alu.vcd");
        $dumpvars(0, tb_alu);
    end

    task exec(reg [2:0] f3, reg [6:0] f7, reg [31:0] opa, reg [31:0] opb);
        funct3 = f3;
        funct7 = f7;
        in1 = opa;
        in2 = opb;
        alu_start = 1'b1;
        @(posedge clk);
        alu_start = 1'b0;
        // @(posedge clk);
        while (~alu_done) begin
            @(posedge clk);
        end
    endtask

    initial begin
        alu_start = 1'b0;
        #1 rst_n = 1'bx;
        clk = 1'bx;
        #1 rst_n = 1;
        #1 rst_n = 0;
        clk = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        repeat (2) @(posedge clk);

        exec(3'h0, 7'h0, 120, 14);
        exec(3'h1, 7'h0, 120, 14);

        $finish(2);
    end

endmodule
`default_nettype wire
