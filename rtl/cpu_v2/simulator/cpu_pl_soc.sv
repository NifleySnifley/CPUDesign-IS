`ifdef IVERILOG_LINT
`include "../bus_arbiter.sv"
`endif


module cpu_pl_soc #(
    parameter INIT_H = "",
    parameter PROGROM_SIZE_W = 32768
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

    cpu_pipelined #(
        .PROGROM_SIZE_W(PROGROM_SIZE_W)
    ) core0 (
        .clk,
        .rst,
        .bus_addr,
        .bus_wdata,
        .bus_wmask,
        .bus_rdata,
        .bus_done,
        .bus_wen,
        .bus_ren
    );

    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0] mem_wmask;
    wire mem_wstrobe;
    wire mem_rstrobe;
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

        .device_address({spram_addr}),
        .device_data_write({spram_wdata}),
        .device_write_mask({spram_wmask}),
        .device_ren({spram_ren}),
        .device_wen({spram_wen}),
        .device_ready({spram_done}),
        .device_data_read({spram_rdata}),
        .device_active({spram_active})
    );


    wire [31:0] spram_addr;
    wire [31:0] spram_wdata;
    wire [3:0] spram_wmask;
    wire spram_wen;
    wire spram_ren;
    wire [31:0] spram_rdata;
    wire spram_done;
    wire spram_active;

    sim_spram #(
        .BASE_ADDR(0)
    ) spram (
        .clk,
        .addr(spram_addr),
        .wdata(spram_wdata),
        .wmask(spram_wmask),
        .wen(spram_wen),
        .ren(spram_ren),
        .rdata(spram_rdata),
        .done(spram_done),
        .active(spram_active)
    );
endmodule
