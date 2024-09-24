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

module soc_upduino #(
    parameter MEMSIZE = 2048
) (
    output wire led_green,
    output wire led_red,
    output wire led_blue,

    // output serial_txd,
    // input  serial_rxd,

    output spi_cs,
    // input  spi_sck,
    // input  spi_ssn,
    // input  spi_mosi,
    // input  spi_miso,

    // output gpio_23,
    // output gpio_25,
    // output gpio_26,
    // output gpio_27,
    // output gpio_32,
    // output gpio_35,
    // output gpio_31,
    // output gpio_37,
    // output gpio_34,
    // output gpio_43,
    // output gpio_36,
    // output gpio_42,
    // output gpio_38,
    // output gpio_28,
    // output gpio_12,
    // output gpio_21,
    // output gpio_13,
    // output gpio_19,
    output gpio_18,
    output gpio_11,
    output gpio_9,
    output gpio_6,
    output gpio_44,
    output gpio_4,
    output gpio_3,
    output gpio_48,
    output gpio_45,
    // output gpio_47,
    // output gpio_46,

    input gpio_2,
    input gpio_20
    // input gpio_10
);
    wire clk12MHz = gpio_20;
    assign gpio_46 = instruction_sync;
    assign spi_cs  = 1'b1;

    wire [7:0] debug_word;
    assign {gpio_18, gpio_11, gpio_9, gpio_6, gpio_44, gpio_4, gpio_3, gpio_48} = debug_word;

    // RESET BUTTON
    wire rst_press;
    wire rst_state;

    debouncer resetter (
        .clk(clk12MHz),
        .signal(gpio_2),
        .pressed(rst_press),
        .state(rst_state)
    );
    wire rst = rst_state;


    wire core_clk = clk12MHz;


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

    bus_hub_3 hub (
        .clk(core_clk),
        .host_address(bus_addr),
        .host_data_write(bus_wdata),
        .host_write_mask(bus_wmask),
        .host_data_read(bus_rdata),
        .host_ready(bus_done),
        .host_wen(bus_wen),
        .host_ren(bus_ren),

        .device_address({mem_addr, pp_addr, spram_addr}),
        .device_data_write({mem_wdata, pp_wdata, spram_wdata}),
        .device_write_mask({mem_wmask, pp_wmask, spram_wmask}),
        .device_ren({mem_rstrobe, pp_ren, spram_ren}),
        .device_wen({mem_wstrobe, pp_wen, spram_wen}),
        .device_ready({mem_done, pp_done, spram_done}),
        .device_data_read({mem_rdata, pp_rdata, spram_rdata}),
        .device_active({mem_active, pp_active, spram_active})  // SPRAM ACTIVE!
    );


    // bus_hub_2 hub (
    //     .clk(core_clk),
    //     .host_address(bus_addr),
    //     .host_data_write(bus_wdata),
    //     .host_write_mask(bus_wmask),
    //     .host_data_read(bus_rdata),
    //     .host_ready(bus_done),
    //     .host_wen(bus_wen),
    //     .host_ren(bus_ren),

    //     .device_address({mem_addr, pp_addr}),
    //     .device_data_write({mem_wdata, pp_wdata}),
    //     .device_write_mask({mem_wmask, pp_wmask}),
    //     .device_ren({mem_rstrobe, pp_ren}),
    //     .device_wen({mem_wstrobe, pp_wen}),
    //     .device_ready({mem_done, pp_done}),
    //     .device_data_read({mem_rdata, pp_rdata}),
    //     .device_active({mem_active, pp_active})
    // );


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

    wire [31:0] spram_addr;
    wire [31:0] spram_wdata;
    wire [3:0] spram_wmask;
    wire spram_wen;
    wire spram_ren;
    wire [31:0] spram_rdata;
    wire spram_done;
    wire spram_active;

    assign debug_word = parallel_io[7:0];
    // assign gpio_45 = spram_ren;
    // assign gpio_47 = spram_done;

    memory_spram spram (
        .clk(core_clk),
        .addr(spram_addr),
        .wdata(spram_wdata),
        .wmask(spram_wmask),
        .wen(spram_wen),
        .ren(spram_ren),
        .rdata(spram_rdata),
        .done(spram_done),
        .active(spram_active)
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
