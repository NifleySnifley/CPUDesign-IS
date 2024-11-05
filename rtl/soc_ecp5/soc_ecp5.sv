`include "../fpga/debouncer.v"

`ifdef IVERILOG_LINT
`include "../cpu/cpu.sv"
`include "../cpu_v2/cpu_pipelined.sv"
`include "../common/memory.sv"
`include "../common/memory_spram.sv"
`include "../common/bus_hub_2_pl.sv"
`include "../common/bus_hub_3_pl.sv"
`include "../fpga/parallel_port.sv"
`endif

`include "pll_50MHz.sv"
`include "pll_40MHz.sv"
`include "pll_5MHz.sv"
`include "pll_10MHz.sv"
`include "pll_75MHz.sv"

module soc_ecp5 #(
    parameter MEMSIZE = 12800  // 27648 is the absolute max
) (
    input  wire osc_clk25,
    input  wire button,
    output wire led,
    output wire phy_rst_,
    output wire HUB75_R0,
    output wire HUB75_G0,
    output wire HUB75_B0,
    output wire HUB75_R1,
    output wire HUB75_G1,
    output wire HUB75_B1,
    output wire HUB75_E,
    output wire HUB75_A,
    output wire HUB75_B,
    output wire HUB75_C,
    output wire HUB75_D,
    output wire HUB75_CLK,
    output wire HUB75_STB,
    output wire HUB75_OE
);
    assign phy_rst_ = 1'b1;

    // RESET BUTTON
    // wire rst_press;
    wire rst = ~button;

    ////////////////////// SOC SIM //////////////////////

    wire core_clk;
    wire pll_locked;
`ifndef YOSYS_SIM
    pll_50MHz pll (
        .clkin  (osc_clk25),
        .clkout0(core_clk),
        .locked (pll_locked)
    );
`else
    assign core_clk   = osc_clk25;
    assign pll_locked = 1;
`endif

    // reg core_clk = 0;
    // reg [6:0] ctr = 0;
    // always @(posedge osc_clk25) begin
    //     if (ctr == 24) begin
    //         ctr <= 0;
    //         core_clk = ~core_clk;
    //     end else begin
    //         ctr <= ctr + 1;
    //     end
    // end

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

    // wire [3:0] debug;

    cpu_pipelined #(
        .PROGROM_SIZE_W(MEMSIZE),
        .INIT_H("build/phony.hex")
    ) core0 (
        .clk(core_clk),
        .rst(rst | ~pll_locked),
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
        .progMEM_wmask
        // .debug
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
        mem_done <= (mem_ren | mem_wen);
    end

    assign mem_rdata = mem_active ? progMEM_rdata : '0;
    // assign mem_done = 0;  // HACK: Fix this to be "real" done
    assign mem_active = mem_addr < (MEMSIZE * 4);

    assign progMEM_waddr = {2'b0, mem_addr[31:2]};
    assign progMEM_wdata = mem_wdata;
    assign progMEM_wmask = mem_wmask;
    assign progMEM_wen = mem_wen & mem_active;

    bus_hub_3_pl hub (
        .clk(core_clk),
        .host_address(bus_addr),
        .host_data_write(bus_wdata),
        .host_write_mask(bus_wmask),
        .host_data_read(bus_rdata),
        .host_ready(bus_done),
        .host_wen(bus_wen),
        .host_ren(bus_ren),

        .device_address({mem_addr, pp_addr, disp_addr}),
        .device_data_write({mem_wdata, pp_wdata, disp_wdata}),
        .device_write_mask({mem_wmask, pp_wmask, disp_wmask}),
        .device_ren({mem_ren, pp_ren, disp_ren}),
        .device_wen({mem_wen, pp_wen, disp_wen}),
        .device_ready({mem_done, pp_done, disp_ready}),
        .device_data_read({mem_rdata, pp_rdata, disp_rdata}),
        .device_active({mem_active, pp_active, disp_active})
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

    wire [7:0] parallel_b_0 = parallel_io[7:0];
    wire [7:0] parallel_b_1 = parallel_io[15:8];
    wire [7:0] parallel_b_2 = parallel_io[23:16];
    wire [7:0] parallel_b_3 = parallel_io[31:24];

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

    wire [31:0] disp_addr;
    wire [31:0] disp_wdata;
    wire [3:0] disp_wmask;
    wire disp_wen;
    wire disp_ren;
    wire [31:0] disp_rdata;
    wire disp_ready;
    wire disp_active;

    wire output_clk;
    pll_75MHz video_pll (
        .clkin  (osc_clk25),  // 25 MHz, 0 deg
        .clkout0(output_clk)  // 100 MHz, 0 deg
    );

    hub75_driver display (
        .clk(core_clk),
        .output_clk,

        // Bus device
        .addr(disp_addr),
        .wdata(disp_wdata),
        .wmask(disp_wmask),
        .wen(disp_wen),
        .ren(disp_ren),
        .rdata(disp_rdata),
        .ready(disp_ready),
        .active(disp_active),

        // HUB75 Interface
        .R0(HUB75_R0),
        .R1(HUB75_R1),
        .G0(HUB75_G0),
        .G1(HUB75_G1),
        .B0(HUB75_B0),
        .B1(HUB75_B1),
        .ROWSEL({HUB75_E, HUB75_D, HUB75_C, HUB75_B, HUB75_A}),
        .CLK_HUB75(HUB75_CLK),
        .LATCH(HUB75_STB),
        .OE(HUB75_OE)
    );

    // For easy single-cycle access
    // assign HUB75_CLK = parallel_b_3[0];

    // // Second byte, color
    // assign {HUB75_B1, HUB75_B0, HUB75_G1, HUB75_G0, HUB75_R1, HUB75_R0} = parallel_b_1[5:0];

    // // Third byte, control
    // assign {HUB75_OE, HUB75_STB, HUB75_E, HUB75_D, HUB75_C, HUB75_B, HUB75_A} = parallel_b_2[6:0];
    // assign {J1_8, J1_13, J1_14, J1_15} = debug;
endmodule
