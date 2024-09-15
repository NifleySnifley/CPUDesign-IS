module memory #(
    parameter WIDTH = 32,  // 13-bit address
    parameter DEPTH = 8192 - 1,  // 13-bit address
    parameter INIT_F = ""
) (
    input wire [WIDTH-1:0] mem_wdata,  // IGNORE
    input reg mem_wstrobe,  // IGNORE

    input wire [WIDTH-1:0] mem_addr,

    output wire [WIDTH-1:0] mem_rdata,  // Read data output
    output wire mem_done,  // Read or write done

    input wire clk
);

    reg [WIDTH-1:0] memory[DEPTH-1:0];

    assign mem_done = 1'b1;  // HUHHH yes

    initial begin
        if (INIT_F != "") $readmemb(INIT_F, memory);
    end

    wire [31:0] word_addr = {2'b0, mem_addr[31:2]};

    always @(posedge clk) begin
        // Write port
        if (mem_wstrobe) memory[word_addr] <= mem_wdata;
    end

    // Read port
    assign mem_rdata = memory[word_addr];

endmodule
