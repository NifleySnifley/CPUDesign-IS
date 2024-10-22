module bus_arbiter (
    input wire clk,

    // (FE) Instruction fetch port
    input wire [31:0] inst_addr,
    input wire inst_req,
    output reg inst_fetched,
    output reg [31:0] inst_data,

    // (EX) Execute port
    input wire [31:0] ls_address,
    input wire [31:0] ls_wdata,
    input wire [3:0] ls_wmask,
    input wire ls_wen,
    input wire ls_ren,
    output reg ls_done,
    output wire [31:0] ls_rdata,

    // Bus attachment
    output reg [31:0] bus_address,
    output reg [31:0] bus_wdata,
    output reg [3:0] bus_wmask,
    output reg bus_ren,
    output reg bus_wen,
    input wire bus_done,
    input wire [31:0] bus_rdata
);
    wire ls_req = ls_wen | ls_ren;
    // TODO: Implement an instruction cache to allow instruction fetches to be possibly concurrent on cache hit

    always_comb begin
        // Highest priority
        if (inst_req) begin
            bus_address = inst_addr;
            bus_ren = 1;
            bus_wen = 0;
            bus_wmask = 0;
            bus_wdata = 0;

            inst_data = bus_rdata;
            ls_done = 0;
            ls_rdata = 0;
            inst_fetched = bus_done;
        end else if (ls_req) begin
            bus_address = ls_address;
            bus_ren = ls_ren;
            bus_wen = ls_wen;
            bus_wmask = ls_wmask;
            bus_wdata = ls_wdata;

            inst_data = 0;
            ls_done = bus_done;
            ls_rdata = bus_rdata;
            inst_fetched = 0;
        end else begin
            bus_address = 0;
            bus_ren = 0;
            bus_wen = 0;
            bus_wmask = 0;
            bus_wdata = 0;

            inst_fetched = 0;
            inst_data = 0;
            ls_done = 0;
            ls_rdata = 0;
        end
    end

endmodule
