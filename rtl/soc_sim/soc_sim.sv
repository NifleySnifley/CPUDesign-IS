// `ifdef COCOTB_SIM
// `include "../cpu/cpu.sv"
// `include "../common/memory.sv"

module soc_sim #(
    parameter INITF = ""
) (
    input  wire clk,
    input  wire rst,
    output wire instruction_sync
);
    // Memory interface
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [31:0] mem_rdata;
    wire mem_wstrobe;
    wire mem_done;

    memory #(
        .WIDTH (32),
        .INIT_F(INITF)
    ) mem (
        .clk,
        .mem_addr,
        .mem_wdata,
        .mem_rdata,
        .mem_done,
        .mem_wstrobe
    );

    wire [31:0] dbg_output;
    wire [31:0] dbg_pc;
    //
    cpu core0 (
        .clk,
        .rst,
        .mem_addr,
        .mem_wdata,
        .mem_rdata,
        .mem_done,
        .mem_wstrobe,
        .instruction_sync,
        .dbg_output,
        .dbg_pc
    );
endmodule
