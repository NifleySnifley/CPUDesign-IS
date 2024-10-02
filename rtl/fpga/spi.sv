// Assumes:
// clock polarity is 0 (active-high) 
// so data is received (sampled) on the rising edge of sclk

`default_nettype none

module spi_controller #(
    parameter ADDR = 32'hd000
) (
    // Bus interface
    input wire clk,
    input wire [31:0] addr,
    input wire [31:0] wdata,
    input wire [3:0] wmask,
    input wire wen,
    input wire ren,
    output reg [31:0] rdata,  // Read data output
    output wire ready,  // Read or write done
    output wire active,

    // input wire spi_clkin,

    output wire sclk,
    output reg  data_tx,
    input  wire data_rx
);
    parameter REG_STATUS = ADDR + 0;
    parameter REG_CONTROL = ADDR + 4;
    parameter REG_DATA = ADDR + 8;  // +0 = DATAOUT, +1=DATAIN

    wire [31:0] status;
    // Default clock divider = 3
    reg  [31:0] control = {26'b0, 4'd3, 1'b0, 1'b0};
    reg  [ 7:0] dataout;
    wire [ 7:0] datain;

    assign active = (addr == REG_STATUS) | (addr == REG_CONTROL) | (addr == REG_DATA);
    assign ready  = 1;

    // Bus interface for control and data registers
    always @(posedge clk) begin
        if (wen) begin
            case (addr)
                REG_CONTROL: begin
                    if (wmask[0]) control[7:0] <= wdata[7:0];
                    if (wmask[1]) control[15:8] <= wdata[15:8];
                    if (wmask[2]) control[23:16] <= wdata[23:16];
                    if (wmask[3]) control[31:24] <= wdata[31:24];
                end
                REG_DATA: begin
                    if (wmask[0]) dataout <= wdata[7:0];
                    // No write to datain
                    // if (wmask[1]) datain <= wdata[15:8];
                end
                default: ;
            endcase
        end
    end

    always_comb begin
        case (addr)
            REG_STATUS: rdata = status;
            REG_CONTROL: rdata = control;
            REG_DATA: rdata = {16'b0, datain, dataout};
            default: rdata = 32'b0;
        endcase
    end

    // Control bits
    wire tx_start = control[0];
    wire reset = control[1];
    wire [3:0] clkdiv = control[5:2];  // 4 bits of clock divider
    // Status bits
    assign status = {30'b0, spi_busy, spi_finished};

    // SPI Clock Divider
    reg [14:0] div_ctr;
    always @(posedge clk) begin
        div_ctr <= div_ctr + 1;
    end
    // spi_clk = clk/(2^clkdiv) 
    wire spi_clkin = clkdiv == 0 ? clk : div_ctr[clkdiv-1];

    // TX start crossover into SPI clock domain (not strictly neccesary because they are the same clock though)
    reg  tx_start_prev = 0;
    always @(negedge spi_clkin) begin
        tx_start_prev <= tx_start;
    end
    wire tx_start_posedge_spiclk = tx_start & ~tx_start_prev;

    // State logic
    reg [7:0] tx_sr = 0;
    reg [7:0] rx_sr = 0;
    reg [3:0] bits_to_tx = 0;
    wire spi_finished = ~(|bits_to_tx);
    // FIXME: Make this high as soon as a start is requested even before it starts txing!
    wire spi_busy = tx_start_posedge_spiclk | (~spi_finished);

    assign sclk = spi_clkin & (~spi_finished);

    assign datain = rx_sr;
    assign data_tx = tx_sr[7];

    always @(negedge spi_clkin) begin
        if (reset) begin
            tx_sr <= 0;
            rx_sr <= 0;
        end else begin
            if (tx_start_posedge_spiclk) begin
                bits_to_tx <= 8;
                tx_sr <= dataout;
                rx_sr <= 0;
            end else if (~spi_finished) begin
                // Posedge of SPI clock, output data here or on negedge????
                // LSB first
                // OLD: This was LSB first
                // tx_sr <= {1'b0, tx_sr[7:1]};
                // rx_sr <= {data_rx, rx_sr[7:1]};
                tx_sr <= {tx_sr[6:0], 1'b0};
                rx_sr <= {rx_sr[6:0], data_rx};
                bits_to_tx <= bits_to_tx - 1;
            end
        end
    end
endmodule
