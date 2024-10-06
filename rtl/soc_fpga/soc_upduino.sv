`include "../fpga/debouncer.v"

`ifdef IVERILOG_LINT
`include "../cpu/cpu.sv"
`include "../common/memory.sv"
`include "../common/memory_spram.sv"
`include "../common/bus_hub_1.sv"
`include "../common/bus_hub_2.sv"
`include "../common/bus_hub_3.sv"
`include "../common/bus_hub_4.sv"
`include "../fpga/parallel_port.sv"
`include "../graphics/rtl/bw_textmode_gpu.sv"
`endif

module soc_upduino #(
    parameter MEMSIZE = 2560
) (
    // System inputs
    input clk12MHz,
    input reset,

    // TODO: Make a PWM peripheral and hook it to this!
    output wire led_green,
    output wire led_red,
    output wire led_blue,

    // TODO: Make a UART peripheral and hook it to this!
    // ftdi_serial_txd
    // ftdi_serial_rxd
    output fpga_flash_spi_cs,
    // ftdi_spi_sck
    // ftdi_spi_ssn
    // ftdi_spi_mosi
    // ftdi_spi_miso

    inout gpio0,
    inout gpio1,
    inout gpio2,
    inout gpio3,
    inout gpio4,
    inout gpio5,
    inout gpio6,
    inout gpio7,
    inout gpio8,
    inout gpio9,
    inout gpio10,
    inout gpio11,
    inout gpio12,
    inout gpio13,
    inout gpio14,
    inout gpio15,
    inout gpio16,
    inout gpio17,

    // SPI Peripheral
    output spi_hw_cs,
    output spi_sclk,
    input  spi_rx,
    output spi_tx,

    // VGA Video
    output hsync,
    output vsync,
    output red_l,
    output red_h,
    output grn_l,
    output grn_h,
    output blu_l,
    output blu_h
);
    assign fpga_flash_spi_cs = 1'b1;
    wire core_clk = clk12MHz;

    // RESET BUTTON
    wire rst_press;
    wire rst_state;
    debouncer resetter (
        .clk(core_clk),
        .signal(reset),
        .pressed(rst_press),
        .state(rst_state)
    );
    wire rst = rst_state;

    // Bus output from CPU
    wire [31:0] bus_addr;
    wire [31:0] bus_wdata;
    wire [31:0] bus_rdata;
    wire bus_wen;
    wire bus_ren;
    wire bus_done;
    wire [3:0] bus_wmask;

    // Debugging outputs
    wire instruction_sync;
    wire [31:0] pc_output;

    // Main CPU
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

    // Bus hub
    bus_hub_5 hub (
        .clk(core_clk),
        .host_address(bus_addr),
        .host_data_write(bus_wdata),
        .host_write_mask(bus_wmask),
        .host_data_read(bus_rdata),
        .host_ready(bus_done),
        .host_wen(bus_wen),
        .host_ren(bus_ren),

        .device_address({mem_addr, spram_addr, pp_addr, gpu_addr, spi_addr}),
        .device_data_write({mem_wdata, spram_wdata, pp_wdata, gpu_wdata, spi_wdata}),
        .device_write_mask({mem_wmask, spram_wmask, pp_wmask, gpu_wmask, spi_wmask}),
        .device_ren({mem_rstrobe, spram_ren, pp_ren, gpu_ren, spi_ren}),
        .device_wen({mem_wstrobe, spram_wen, pp_wen, gpu_wen, spi_wen}),
        .device_ready({mem_done, spram_done, pp_done, gpu_done, spi_done}),
        .device_data_read({mem_rdata, spram_rdata, pp_rdata, gpu_rdata, spi_rdata}),
        .device_active({mem_active, spram_active, pp_active, gpu_active, spi_active})
    );

    // BRAM Writeable memory (TODO: Bootloader in here)
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

    // 128K of SPRAM (not programmable/initializeable)
    wire [31:0] spram_addr;
    wire [31:0] spram_wdata;
    wire [3:0] spram_wmask;
    wire spram_wen;
    wire spram_ren;
    wire [31:0] spram_rdata;
    wire spram_done;
    wire spram_active;

    ice40_spram spram (
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

    // Parallel output
    wire [31:0] pp_addr;
    wire [31:0] pp_wdata;
    wire [3:0] pp_wmask;
    wire pp_wen;
    wire pp_ren;
    wire [31:0] pp_rdata;
    wire pp_done;
    wire pp_active;

    wire [31:0] parallel_io;
    assign {
        gpio17,
        gpio16,
        gpio15,
        gpio14,
        gpio13,
        gpio12,
        gpio11,
        gpio10,
        gpio9,
        gpio8,
        gpio7,
        gpio6,
        gpio5,
        gpio4,
        gpio3,
        gpio2,
        gpio1,
        gpio0
    } = parallel_io[17:0];

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

    // VGA Graphics out
    wire [31:0] gpu_addr;
    wire [31:0] gpu_wdata;
    wire [3:0] gpu_wmask;
    wire gpu_wen;
    wire gpu_ren;
    wire [31:0] gpu_rdata;
    wire gpu_done;
    wire gpu_active;

    wire hsync_internal;
    wire vsync_internal;
    wire video_internal;
    wire clk_pix;

    bw_textmode_gpu #(
        .FONTROM_INITFILE("../graphics/spleen8x16.txt")
    ) gpu (
        // CLK for bus domain
        .clk(core_clk),
        .rst,

        .addr(gpu_addr),
        .wdata(gpu_wdata),
        .wmask(gpu_wmask),
        .wen(gpu_wen),
        .ren(gpu_ren),
        .rdata(gpu_rdata),  // Read data output
        .ready(gpu_done),  // Read or write done
        .active(gpu_active),

        // Input clock for video clock generation
        .clk_12MHz(clk12MHz),
        .hsync(hsync_internal),
        .vsync(vsync_internal),
        .video(video_internal),  // 1-bit video output.
        .clk_pix
    );

    // Special IO for VGA output
    SB_IO #(
        .PIN_TYPE(6'b010100)  // PIN_OUTPUT_REGISTERED
    ) vga_io[2:0] (
        .PACKAGE_PIN({hsync, vsync, red_h}),
        .OUTPUT_CLK(clk_pix),
        .D_OUT_0({hsync_internal, vsync_internal, video_internal}),
        .D_OUT_1()
    );

    wire [31:0] spi_addr;
    wire [31:0] spi_wdata;
    wire [3:0] spi_wmask;
    wire spi_wen;
    wire spi_ren;
    wire [31:0] spi_rdata;
    wire spi_done;
    wire spi_active;

    // SPI Peripheral
    spi_controller spi (
        .clk(core_clk),
        .addr(spi_addr),
        .wdata(spi_wdata),
        .wmask(spi_wmask),
        .wen(spi_wen),
        .ren(spi_ren),
        .rdata(spi_rdata),
        .ready(spi_done),
        .active(spi_active),
        .sclk(spi_sclk),
        .data_tx(spi_tx),
        .data_rx(spi_rx),
        .cs(spi_hw_cs)
    );
endmodule
