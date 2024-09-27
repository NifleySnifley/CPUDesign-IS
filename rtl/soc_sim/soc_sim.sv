module soc_sim #(
    parameter INITF = ""
) (
    input  wire clk,
    input  wire rst,
    output wire instruction_sync
);
    wire [31:0] bus_addr;
    wire [31:0] bus_wdata;
    wire [31:0] bus_rdata;
    wire bus_wen;
    wire bus_ren;
    wire bus_done;
    wire [31:0] pc_output;
    wire [3:0] bus_wmask;

    cpu core0 (
        .clk,
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


    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0] mem_wmask;
    wire mem_wstrobe;
    wire mem_rstrobe;
    wire [31:0] mem_rdata;
    wire mem_done;
    wire mem_active;

    // wire mem_active;

    memory #(
        .SIZE(2048)
    ) mem (
        .clk,
        .mem_addr,
        .mem_wdata,
        .mem_wmask,
        .mem_wstrobe,
        .mem_rstrobe,
        .mem_rdata,
        .mem_done,
        .active(mem_active)
    );


    bus_hub_2 hub (
        .clk,
        .host_address(bus_addr),
        .host_data_write(bus_wdata),
        .host_write_mask(bus_wmask),
        .host_data_read(bus_rdata),
        .host_ready(bus_done),
        .host_wen(bus_wen),
        .host_ren(bus_ren),

        .device_address({mem_addr, spram_addr}),
        .device_data_write({mem_wdata, spram_wdata}),
        .device_write_mask({mem_wmask, spram_wmask}),
        .device_ren({mem_rstrobe, spram_ren}),
        .device_wen({mem_wstrobe, spram_wen}),
        .device_ready({mem_done, spram_done}),
        .device_data_read({mem_rdata, spram_rdata}),
        .device_active({mem_active, spram_active})
    );


    wire [31:0] spram_addr;
    wire [31:0] spram_wdata;
    wire [3:0] spram_wmask;
    wire spram_wen;
    wire spram_ren;
    wire [31:0] spram_rdata;
    wire spram_done;
    wire spram_active;

    sim_spram spram (
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
