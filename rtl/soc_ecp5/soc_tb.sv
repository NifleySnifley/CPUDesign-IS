`timescale 1ns / 1ps
module example_tb ();
    // Clock and reset signals
    reg  clk;
    reg  reset;

    wire led;
    wire phy_rst_;
    wire J1_1;
    wire J1_2;
    wire J1_3;
    wire J1_5;
    wire J1_6;
    wire J1_7;
    wire J1_8;
    wire J1_9;
    wire J1_10;
    wire J1_11;
    wire J1_12;
    wire J1_13;
    wire J1_14;
    wire J1_15;

    // DUT instantiation
    soc_ecp5 soc (
        .osc_clk25(clk),
        .button(~reset),
        .led,
        .phy_rst_,
        .J1_1,
        .J1_2,
        .J1_3,
        .J1_5,
        .J1_6,
        .J1_7,
        .J1_8,
        .J1_9,
        .J1_10,
        .J1_11,
        .J1_12,
        .J1_13,
        .J1_14,
        .J1_15
    );

    // generate the clock
    initial begin
        clk = 1'b0;
        forever #1 clk = ~clk;
    end

    // Generate the reset
    initial begin
        reset = 1'b1;
        #10 reset = 1'b0;
    end

    // Test stimulus
    initial begin
        // Use the monitor task to display the FPGA IO
        // $monitor("time=%3d, in_a=%b, in_b=%b, q=%2b \n", $time, in_a, in_b, q);

        // Generate each input with a 20 ns delay between them
        #10000;
    end


endmodule : example_tb
