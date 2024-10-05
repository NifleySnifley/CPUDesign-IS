module ice40_gpiobank #(
    parameter ADDR = 32'hA000,
    parameter N_IO = 16
) (
    input wire clk,
    input wire [31:0] addr,
    input wire [31:0] wdata,
    input wire [3:0] wmask,
    input wire wen,
    input wire ren,
    output reg [31:0] rdata,  // Read data output
    output wire ready,  // Read or write done
    output wire active,

    output wire [N_IO-1:0] io_pins
);
    assign ready = 1;
    localparam N_REGISTERS = 3;  // OE, OV, IV
    localparam OE_ADDR = ADDR + 0;
    localparam OV_ADDR = ADDR + 4;
    localparam IV_ADDR = ADDR + 8;

    localparam N_FILL = 32 - N_IO;

    assign active = (addr[31:2] >= ADDR[31:2]) && (addr[31:2] <= (ADDR[31:2] + N_REGISTERS));

    reg [N_IO-1:0] output_enable;
    reg [N_IO-1:0] output_value;
    wire [31:0] input_value;

    assign input_value[N_IO-1:0] = io_pins;
    assign input_value[31:N_IO]  = 0;
    generate
        genvar i;
        for (i = 0; i < N_IO; i = i + 1) begin
            // High-Z output enable implemented here
            assign io_pins[i] = output_enable[i] ? output_value[i] : 1'bz;
        end
    endgenerate

    // Write-side logic
    always_ff @(posedge clk) begin
        if (wen & active) begin
            unique case (addr[31:2])
                OE_ADDR: begin
                    if (wmask[0]) output_enable[7:0] <= wdata[7:0];
                    if (wmask[1]) output_enable[15:8] <= wdata[15:8];
                    if (wmask[2]) output_enable[23:16] <= wdata[23:16];
                    if (wmask[3]) output_enable[31:24] <= wdata[31:24];
                end
                OV_ADDR: begin
                    if (wmask[0]) output_value[7:0] <= wdata[7:0];
                    if (wmask[1]) output_value[15:8] <= wdata[15:8];
                    if (wmask[2]) output_value[23:16] <= wdata[23:16];
                    if (wmask[3]) output_value[31:24] <= wdata[31:24];
                end
                default: begin
                    // Do nothing here (IV)
                end
            endcase
        end
    end

    // Read-side logic
    always_comb begin
        unique case (addr[31:2])
            OE_ADDR: rdata = output_enable;
            OV_ADDR: rdata = output_value;
            IV_ADDR: rdata = input_value;
            default: rdata = 0;
        endcase
    end
endmodule
