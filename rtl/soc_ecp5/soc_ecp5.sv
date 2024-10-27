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
`include "pll_5MHz.sv"
`include "pll_10MHz.sv"

module soc_ecp5 #(
    parameter MEMSIZE = 8192  // 27648 is the absolute max
) (
    input  wire osc_clk25,
    input  wire button,
    output wire led,
    output wire phy_rst_,
    output wire J1_1,
    output wire J1_2,
    output wire J1_3,
    output wire J1_5,
    output wire J1_6,
    output wire J1_7,
    output wire J1_8,
    output wire J1_9,
    output wire J1_10,
    output wire J1_11,
    output wire J1_12,
    output wire J1_13,
    output wire J1_14,
    output wire J1_15
);
    assign phy_rst_ = 1'b1;

    // RESET BUTTON
    // wire rst_press;
    wire rst = ~button;

    ////////////////////// SOC SIM //////////////////////

    // wire core_clk;
    // wire clk_5m;
    wire pll_locked;
    // `ifndef VERILATOR_LINT
    //     pll_10MHz pll (
    //         .clkin  (osc_clk25),
    //         .clkout0(clk_5m),
    //         .locked (pll_locked)
    //     );
    // `endif

    reg core_clk = 0;
    reg [6:0] ctr = 0;
    always @(posedge osc_clk25) begin
        if (ctr == 24) begin
            ctr <= 0;
            core_clk = ~core_clk;
        end else begin
            ctr <= ctr + 1;
        end
    end

    // wire core_clk = osc_clk25;

    wire [31:0] bus_addr;
    wire [31:0] bus_wdata;
    wire [31:0] bus_rdata;
    wire bus_wen;
    wire bus_ren;
    wire bus_done;
    wire [3:0] bus_wmask;

    wire [31:0] progMEM_waddr;
    wire [3:0] progMEM_wmask;
    wire [31:0] progMEM_wdata;
    wire [31:0] progMEM_rdata;
    wire progMEM_wen;

    wire [3:0] debug;

    cpu_pipelined #(
        .PROGROM_SIZE_W(MEMSIZE),
        .INIT_H("../../software/programs/test_embedded/build/ecp5_test.hex")
    ) core0 (
        .clk(core_clk),
        .rst,
        .bus_addr,
        .bus_wdata,
        .bus_wmask,
        .bus_rdata,
        .bus_done,
        .bus_wen,
        .bus_ren,

        .progMEM_waddr,
        .progMEM_wdata,
        .progMEM_rdata,
        .progMEM_wen,
        .progMEM_wmask,
        .debug
    );

    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0] mem_wmask;
    wire mem_wen;
    wire mem_ren;
    wire [31:0] mem_rdata;
    reg mem_done = 0;
    wire mem_active;

    always @(posedge core_clk) begin
        mem_done <= (mem_ren | mem_wen) & mem_active;
    end

    assign mem_rdata = mem_active ? progMEM_rdata : '0;
    // assign mem_done = 0;  // HACK: Fix this to be "real" done
    assign mem_active = mem_addr < (MEMSIZE * 4);

    assign progMEM_waddr = {2'b0, mem_addr[31:2]};
    assign progMEM_wdata = mem_wdata;
    assign progMEM_wmask = mem_wmask;
    assign progMEM_wen = mem_wen & mem_active;

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
        .device_ren({mem_ren, pp_ren}),
        .device_wen({mem_wen, pp_wen}),
        .device_ready({mem_done, pp_done}),
        .device_data_read({mem_rdata, pp_rdata}),
        .device_active({mem_active, pp_active})
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
    assign led = ~parallel_io[0];

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

    assign {J1_8, J1_13, J1_14, J1_15} = debug;
endmodule
