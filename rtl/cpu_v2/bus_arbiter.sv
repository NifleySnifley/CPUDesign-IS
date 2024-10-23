module bus_arbiter (
    input wire clk,

    // (FE) Instruction fetch port
    input wire [31:0] inst_addr,
    input wire inst_req,
    output wire inst_fetched,
    output wire [31:0] inst_data,

    // (EX) Execute port
    input wire [31:0] ls_addr,
    input wire [31:0] ls_wdata,
    input wire [3:0] ls_wmask,
    input wire ls_wen,
    input wire ls_ren,
    output wire ls_done,
    output wire [31:0] ls_rdata,

    // Bus attachment
    output wire [31:0] bus_addr,
    output wire [31:0] bus_wdata,
    output wire [3:0] bus_wmask,
    output wire bus_ren,
    output wire bus_wen,
    input wire bus_done,
    input wire [31:0] bus_rdata
);
    wire is_ls = ls_wen | ls_ren;
    wire is_inst = inst_req & ~is_ls;
    // TODO: Implement an instruction cache to allow instruction fetches to be possibly concurrent on cache hit

    assign bus_addr  = is_ls ? ls_addr : inst_addr;
    assign bus_wdata = is_ls ? ls_wdata : '0;
    assign bus_wmask = is_ls ? ls_wmask : '0;
    assign bus_ren   = ls_ren | is_inst;
    assign bus_wen   = ls_wen;

    assign ls_done   = is_ls ? bus_done : '0;
    assign ls_rdata  = is_ls ? bus_rdata : '0;

    // Latch instruction fetches
    reg [31:0] inst_reg = 0;
    reg [31:0] inst_addr_reg = 32'hFFFFFFFF;
    always @(posedge clk) begin
        if (is_inst && bus_done) begin
            inst_reg <= bus_rdata;
            inst_addr_reg <= inst_addr;
        end
    end
    assign inst_data = inst_reg;
    assign inst_fetched = (inst_addr_reg == inst_addr) && inst_req;

endmodule
