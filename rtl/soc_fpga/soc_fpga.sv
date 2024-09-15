`include "../fpga/debouncer.v"
`include "../fpga/icefun_ledscan.v"
// `include "../common/defs.sv"
// `include "../cpu/cpu.sv"
// `include "../alu/alu.sv"
// `include "../common/memory.sv"

module soc_fpga #(
    parameter INITF = "../../../software/programs/assembly/test_program.txt"
) (
    input  clk12MHz,
    output led1,
    output led2,
    output led3,
    output led4,
    output led5,
    output led6,
    output led7,
    output led8,
    output lcol1,
    output lcol2,
    output lcol3,
    output lcol4,
    input  key1,
    input  key2,
    input  key3,
    input  key4
);
    reg [45:0] clkdivider;
    always_ff @(posedge clk12MHz) begin
        clkdivider <= clkdivider + 1;
    end
    wire clk_slow = clkdivider[16];


    // // these are the led holding registers, whatever you write to these appears on the led display
    // reg [7:0] leds1;
    // reg [7:0] leds2;
    // reg [7:0] leds3;
    // reg [7:0] leds4;

    // // The output from the ledscan module
    wire [7:0] leds;
    // wire [3:0] lcol;

    // // map the output of ledscan to the port pins	
    assign {led1, led2, led3, led4, led5, led6, led7, led8} = ~leds[7:0];
    // // assign {led8, led7, led6, led5, led4, led3, led2, led1} = leds[7:0];
    // assign {lcol4, lcol3, lcol2, lcol1} = lcol[3:0];
    assign {lcol4, lcol3, lcol2, lcol1} = 4'b0111;

    // // instantiate the led scan module
    // iceFUN_LedScan scan (
    //     .clk12MHz(clk12MHz),
    //     .leds1(~leds1),
    //     .leds2(~leds2),
    //     .leds3(~leds3),
    //     .leds4(~leds4),
    //     .leds(leds),
    //     .lcol(lcol)
    // );

    wire key1_press;
    // wire key2_press;
    // wire key3_press;
    // wire key4_press;

    wire key1_state;
    // wire key2_state;
    // wire key3_state;
    // wire key4_state;

    debouncer k1 (
        .clk(clk12MHz),
        .signal(key1),
        .pressed(key1_press),
        .state(key1_state)
    );
    // debouncer k2 (
    //     .clk(clk12MHz),
    //     .signal(key2),
    //     .pressed(key2_press),
    //     .state(key2_state)
    // );
    // debouncer k3 (
    //     .clk(clk12MHz),
    //     .signal(key3),
    //     .pressed(key3_press),
    //     .state(key3_state)
    // );
    // debouncer k4 (
    //     .clk(clk12MHz),
    //     .signal(key4),
    //     .pressed(key4_press),
    //     .state(key4_state)
    // );

    // Memory interface
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [31:0] mem_rdata;
    wire mem_wstrobe;
    wire mem_done;
    wire instruction_sync;
    wire [31:0] reg_output;
    wire [31:0] pc_output;

    assign leds = reg_output[7:0];

    wire rst = key1_state;

    wire core_clk = clk_slow;
    // wire core_clk = clk12MHz;
    memory #(
        .WIDTH (32),
        .INIT_F(INITF),
        .DEPTH (256)
    ) mem (
        .clk(core_clk),
        .mem_addr,
        .mem_wdata,
        .mem_rdata,
        .mem_done,
        .mem_wstrobe
    );

    cpu core0 (
        .clk(core_clk),
        .rst,
        .mem_addr,
        .mem_wdata,
        .mem_rdata,
        .mem_done,
        .mem_wstrobe,
        .instruction_sync,
        .dbg_output(reg_output),
        .dbg_pc(pc_output)
    );
endmodule
