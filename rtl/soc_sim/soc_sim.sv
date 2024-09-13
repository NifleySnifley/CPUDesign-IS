// `ifdef COCOTB_SIM
// `include "../cpu/cpu.sv"
// `include "../common/memory.sv"

module soc_sim (
    input wire clk,
    input wire rst
);
    // Memory interface
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [31:0] mem_rdata;
    wire mem_wstrobe;
    wire mem_done;

    memory #(
        .WIDTH (32),
        .INIT_F("../../software/programs/assembly/test_program.txt")
    ) mem (
        .clk,
        .mem_addr,
        .mem_wdata,
        .mem_rdata,
        .mem_done,
        .mem_wstrobe
    );
    //
    cpu core0 (
        .clk,
        .rst,
        .mem_addr,
        .mem_wdata,
        .mem_rdata,
        .mem_done,
        .mem_wstrobe
    );
endmodule
