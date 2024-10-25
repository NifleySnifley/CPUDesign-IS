`ifdef IVERILOG_LINT
`include "../bus_arbiter.sv"
`endif


module cpu_pl_soc #(
    parameter INIT_H  = "",
    parameter MEMSIZE = 25600
) (
    input wire clk,
    input wire rst
);
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

    cpu_pipelined #(
        .PROGROM_SIZE_W(MEMSIZE),
        .INIT_H(INIT_H)
    ) core0 (
        .clk,
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
        .progMEM_wmask
    );

    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0] mem_wmask;
    wire mem_wen;
    wire mem_ren;
    wire [31:0] mem_rdata;
    wire mem_done;
    wire mem_active;

    bus_hub_1 hub (
        .clk,
        .host_address(bus_addr),
        .host_data_write(bus_wdata),
        .host_write_mask(bus_wmask),
        .host_data_read(bus_rdata),
        .host_ready(bus_done),
        .host_wen(bus_wen),
        .host_ren(bus_ren),

        .device_address({mem_addr}),
        .device_data_write({mem_wdata}),
        .device_write_mask({mem_wmask}),
        .device_ren({mem_ren}),
        .device_wen({mem_wen}),
        .device_ready({mem_done}),
        .device_data_read({mem_rdata}),
        .device_active({mem_active})
    );

    assign mem_rdata = mem_active ? progMEM_rdata : '0;
    assign mem_done = 1;  // HACK: Fix this to be "real" done
    assign mem_active = mem_addr < (MEMSIZE * 4);

    assign progMEM_waddr = {2'b0, mem_addr[31:2]};
    assign progMEM_wdata = mem_wdata;
    assign progMEM_wmask = mem_wmask;
    assign progMEM_wen = mem_wen;


    // wire [31:0] mem_addr;
    // wire [31:0] mem_wdata;
    // wire [3:0] mem_wmask;
    // wire mem_wen;
    // wire mem_ren;
    // wire [31:0] mem_rdata;
    // wire mem_done;
    // wire mem_active;

    // sim_spram #(
    //     .BASE_ADDR(0)
    // ) spram (
    //     .clk,
    //     .addr(mem_addr),
    //     .wdata(mem_wdata),
    //     .wmask(mem_wmask),
    //     .wen(mem_wen),
    //     .ren(mem_ren),
    //     .rdata(mem_rdata),
    //     .done(mem_done),
    //     .active(mem_active)
    // );
endmodule
