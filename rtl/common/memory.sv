module memory #(
    parameter SIZE   = 256,
    parameter INIT_F = ""
) (
    input wire clk,
    input wire [31:0] mem_addr,

    input wire [31:0] mem_wdata,
    input wire [3:0] mem_wmask,
    input reg mem_wstrobe,

    input reg mem_rstrobe,
    output wire [31:0] mem_rdata,  // Read data output
    output wire mem_done  // Read or write done
);
    reg [31:0] memory[SIZE-1:0];
    localparam DEPTH_B = $clog2(SIZE);

    assign mem_done = 1'b1;  // HUHHH yes

    initial begin
        if (INIT_F != "") $readmemb(INIT_F, memory);
    end


    wire [DEPTH_B-1:0] word_addr = mem_addr[1+DEPTH_B:2];
    always @(posedge clk) begin
        // Write port
        if (mem_wstrobe)
            memory[word_addr] <= {
                mem_wmask[3] ? mem_wdata[31:24] : mem_rdata[31:24],
                mem_wmask[2] ? mem_wdata[23:16] : mem_rdata[23:16],
                mem_wmask[1] ? mem_wdata[15:8] : mem_rdata[15:8],
                mem_wmask[0] ? mem_wdata[7:0] : mem_rdata[7:0]
            };
        // if (mem_rstrobe) mem_rdata <= memory[word_addr];
    end

    // Read port
    assign mem_rdata = memory[word_addr];

endmodule
