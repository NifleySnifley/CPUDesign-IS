`include "../fpga/debouncer.v"

`ifdef IVERILOG_LINT
`include "../cpu/cpu.sv"
`include "../cpu_v2/cpu_pipelined.sv"
`include "../common/memory.sv"
`include "../common/memory_spram.sv"
`include "../common/bus_hub_1.sv"
`include "../common/bus_hub_2.sv"
`include "../common/bus_hub_3.sv"
`include "../fpga/parallel_port.sv"
`endif

`include "pll_50MHz.sv"
`include "pll_40MHz.sv"

module soc_ecp5 #(
    parameter PROGSIZE = 8192,
    parameter MEMSIZE  = 8192
) (
    input  wire osc_clk25,
    input  wire button,
    output wire led,
    output wire phy_rst_
);
    assign phy_rst_ = 1'b1;

    // RESET BUTTON
    wire rst_press;
    wire rst_state;

    debouncer reset_debounce (
        .clk(osc_clk25),
        .signal(button),
        .pressed(rst_press),
        .state(rst_state)
    );

    // Memory interface
    wire [31:0] bus_addr;
    wire [31:0] bus_wdata;
    wire [31:0] bus_rdata;
    wire bus_wen;
    wire bus_ren;
    wire bus_done;
    wire [3:0] bus_wmask;

    // wire core_clk = osc_clk25;
    wire pll_locked;
    wire core_clk;
    pll_40MHz pll (
        .clkin  (osc_clk25),
        .clkout0(core_clk),
        .locked (pll_locked)
    );

    cpu_pipelined #(
        .PROGROM_SIZE_W(PROGSIZE),
        .INIT_H("build/phony.hex")
    ) core0 (
        .clk(core_clk),
        .rst(rst_state | ~pll_locked),
        .bus_addr,
        .bus_wdata,
        .bus_wmask,
        .bus_rdata,
        .bus_done,
        .bus_wen,
        .bus_ren
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
        .INIT_H(""),
        .SIZE(MEMSIZE),
        .BASEADDR(PROGSIZE)
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
    assign led = parallel_io[0];

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
