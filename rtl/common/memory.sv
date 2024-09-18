module memory #(
    parameter SIZE   = 256,
    parameter INIT_F = ""
) (
    input wire clk,
    input wire [31:0] mem_addr,

    input wire [31:0] mem_wdata,
    input wire [3:0] mem_wmask,
    input wire mem_wstrobe,

    input wire mem_rstrobe,
    output reg [31:0] mem_rdata,  // Read data output
    output wire mem_done,  // Read or write done

    // TODO: Add base address to parameters
    output wire active
);
    reg [31:0] memory[SIZE-1:0];
    localparam DEPTH_B = $clog2(SIZE);

    reg [DEPTH_B-1:0] xact_addr;

    assign mem_done = word_addr == xact_addr;  // HUHHH yes

    initial begin
        if (INIT_F != "") $readmemb(INIT_F, memory);
    end

    wire [DEPTH_B-1:0] word_addr = mem_addr[1+DEPTH_B:2];
    assign active = word_addr < SIZE;

    always @(posedge clk) begin
        // NOTE: WRITE PORT (sync)
        if (mem_wstrobe) begin
            if (mem_wmask[0]) memory[word_addr][7:0] <= mem_wdata[7:0];
            if (mem_wmask[1]) memory[word_addr][15:8] <= mem_wdata[15:8];
            if (mem_wmask[2]) memory[word_addr][23:16] <= mem_wdata[23:16];
            if (mem_wmask[3]) memory[word_addr][31:24] <= mem_wdata[31:24];
        end
        if (mem_rstrobe) begin
            mem_rdata <= memory[word_addr];
        end

        if (mem_rstrobe | mem_wstrobe) xact_addr <= word_addr;
    end
endmodule
