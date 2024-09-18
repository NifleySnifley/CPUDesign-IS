module parallel_output #(
    parameter ADDR = 32'hf000
) (
    input wire clk,
    input wire [31:0] addr,
    input wire [31:0] wdata,
    input wire [3:0] wmask,
    input wire wen,
    input wire ren,
    output wire [31:0] rdata,  // Read data output
    output wire ready,  // Read or write done
    output wire active,

    output reg [31:0] io
);
    assign ready  = 1;
    assign rdata  = 0;

    assign active = (addr[31:2] == ADDR[31:2]);

    always_ff @(posedge clk) begin
        if (wen & active) begin
            if (wmask[0]) io[7:0] <= wdata[7:0];
            if (wmask[1]) io[15:8] <= wdata[15:8];
            if (wmask[2]) io[23:16] <= wdata[23:16];
            if (wmask[3]) io[31:24] <= wdata[31:24];
        end
    end
endmodule
