`include "../fpga/debouncer.v"

`ifdef IVERILOG_LINT
`include "../cpu/cpu.sv"
`include "../common/memory.sv"
`include "../fpga/memory_spram.sv"
`include "../common/bus_hub_1.sv"
`include "../common/bus_hub_2.sv"
`include "../common/bus_hub_3.sv"
`include "../fpga/parallel_port.sv"
`endif

module soc_iceFUN #(
    parameter MEMSIZE = 2048
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
    // SLOW CLOCK
    reg [45:0] clkdivider;
    always_ff @(posedge clk12MHz) begin
        clkdivider <= clkdivider + 1;
    end
    wire clk_slow = clk12MHz;  //clkdivider[10];

    // LEDS
    wire [7:0] leds;
    wire [3:0] lcols;

    assign {led1, led2, led3, led4, led5, led6, led7, led8} = ~leds;
    assign {lcol4, lcol3, lcol2, lcol1} = ~lcols;

    // RESET BUTTON
    wire key1_press;
    wire key1_state;

    debouncer k1 (
        .clk(clk12MHz),
        .signal(key1),
        .pressed(key1_press),
        .state(key1_state)
    );

    // Memory interface
    wire [31:0] bus_addr;
    wire [31:0] bus_wdata;
    wire [31:0] bus_rdata;
    wire bus_wen;
    wire bus_ren;
    wire bus_done;
    wire instruction_sync;
    wire [31:0] pc_output;
    wire [3:0] bus_wmask;

    wire rst = key1_state;

    wire core_clk = clk_slow;

    cpu core0 (
        .clk(core_clk),
        .rst,
        .bus_addr,
        .bus_wdata,
        .bus_wmask,
        .bus_rdata,
        .bus_done,
        .bus_wen,
        .bus_ren,
        .instruction_sync,
        .dbg_pc(pc_output)
    );

    bus_hub_2 hub (
        .clk(core_clk),
        .host_address(bus_addr),
        .host_data_write(bus_wdata),
        .host_write_mask(bus_wmask),
        .host_data_read(bus_rdata),
        .host_ready(bus_done),
        .host_wen(bus_wen),
        .host_ren(bus_ren),

        .device_address({mem_addr, pp_addr}),
        .device_data_write({mem_wdata, pp_wdata}),
        .device_write_mask({mem_wmask, pp_wmask}),
        .device_ren({mem_rstrobe, pp_ren}),
        .device_wen({mem_wstrobe, pp_wen}),
        .device_ready({mem_done, pp_done}),
        .device_data_read({mem_rdata, pp_rdata}),
        .device_active({mem_active, pp_active})
    );

    // TODO: Find a better way to make all these WIRES!!!
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0] mem_wmask;
    wire mem_wstrobe;
    wire mem_rstrobe;
    wire [31:0] mem_rdata;
    wire mem_done;
    wire mem_active;

    memory #(
        .INIT_H("build/phony.hex"),
        .SIZE  (MEMSIZE)
    ) mem (
        .clk(core_clk),
        .mem_addr,
        .mem_wdata,
        .mem_wmask,
        .mem_wstrobe,
        .mem_rstrobe,
        .mem_rdata,
        .mem_done,
        .active(mem_active)
    );

    wire [31:0] pp_addr;
    wire [31:0] pp_wdata;
    wire [3:0] pp_wmask;
    wire pp_wen;
    wire pp_ren;
    wire [31:0] pp_rdata;
    wire pp_done;
    wire pp_active;

    wire [31:0] parallel_io;
    assign leds  = parallel_io[7:0];
    assign lcols = parallel_io[11:8];

    parallel_output pp (
        .clk(core_clk),
        .addr(pp_addr),
        .wdata(pp_wdata),
        .wmask(pp_wmask),
        .ren(pp_ren),
        .wen(pp_wen),
        .rdata(pp_rdata),
        .ready(pp_done),
        .active(pp_active),
        .io(parallel_io)
    );
endmodule
