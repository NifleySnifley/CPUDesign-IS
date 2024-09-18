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

    wire mem_active;

    memory #(
        .SIZE(2048)
    ) mem (
        .clk,
        .mem_addr(bus_addr),
        .mem_wdata(bus_wdata),
        .mem_wmask(bus_wmask),
        .mem_wstrobe(bus_wen),
        .mem_rstrobe(bus_ren),
        .mem_rdata(bus_rdata),
        .mem_done(bus_done),
        .active(mem_active)
    );

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
endmodule
