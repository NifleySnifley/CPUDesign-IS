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

    // State logic
    reg [7:0] tx_sr = 0;
    reg [7:0] rx_sr = 0;
    reg [3:0] bits_to_tx = 0;
    wire spi_finished = ~(|bits_to_tx);
    // FIXME: Make this high as soon as a start is requested even before it starts txing!
    reg spi_busy;

    // reg spi_clkin_prev;
    // reg pv_txstart_clk = 0;
    // always @(posedge clk) begin
    //     if (tx_start & ~pv_txstart_clk) begin
    //         spi_busy <= 1;
    //         // Posedge of spi_clkin
    //     end else begin
    //         spi_busy <= 0;
    //     end
    //     /*
    // 	else if (spi_clkin & ~spi_clkin_prev) begin
    //         // if (spi_finished) spi_busy <= 0;
    //     end*/
    //     pv_txstart_clk <= tx_start;
    //     spi_clkin_prev <= spi_clkin;
    // end

    assign sclk = spi_clkin & (~spi_finished);

    assign datain = rx_sr;
    assign data_tx = tx_sr[7];

    // always @(negedge spi_clkin) begin
    //     if (reset) begin
    //         tx_sr <= 0;
    //         rx_sr <= 0;
    //     end else begin
    //         if (tx_start_posedge_spiclk) begin
    //             bits_to_tx <= 8;
    //             tx_sr <= dataout;
    //             rx_sr <= 0;
    //         end else if (~spi_finished) begin
    //             // Posedge of SPI clock, output data here or on negedge????
    //             // LSB first
    //             // OLD: This was LSB first
    //             // tx_sr <= {1'b0, tx_sr[7:1]};
    //             // rx_sr <= {data_rx, rx_sr[7:1]};
    //             tx_sr <= {tx_sr[6:0], 1'b0};
    //             rx_sr <= {rx_sr[6:0], data_rx};
    //             bits_to_tx <= bits_to_tx - 1;
    //         end
    //     end
    // end
    reg  spi_clkin_prev = 0;
    wire spi_clkin_negedge = (~spi_clkin) & spi_clkin_prev;
    reg  tx_start_prev = 0;
    wire tx_start_posedge = tx_start & ~tx_start_prev;

    // always @(negedge spi_clkin) begin
    // end
    always @(negedge clk) begin
        tx_start_prev  <= tx_start;
        spi_clkin_prev <= spi_clkin;
        // Handle special case where SPI is operating at max clock
        if (clkdiv == 0) begin
            if (reset) begin
                tx_sr <= 0;
                rx_sr <= 0;
            end else begin
                // Wait for SPICLK to have a negedge before actually starting the transaction
                // Immediately raise spi_busy, but wait for negedge on spi clock to open the gate for SCLK
                if (tx_start_posedge) begin
                    bits_to_tx <= 8;
                    tx_sr <= dataout;
                    rx_sr <= 0;
                    spi_busy <= 1;
                end else if (~spi_finished) begin
                    tx_sr <= {tx_sr[6:0], 1'b0};
                    rx_sr <= {rx_sr[6:0], data_rx};
                    bits_to_tx <= bits_to_tx - 1;
                end else if (spi_finished) begin
                    spi_busy <= 0;
                end
            end
        end else begin
            // Handle general case of divided clock (more lax timing)
            // Always operates on negedge
            if (reset) begin
                tx_sr <= 0;
                rx_sr <= 0;
            end else begin
                if (tx_start_posedge) begin
                    bits_to_tx <= 8;
                    tx_sr <= dataout;
                    rx_sr <= 0;
                    spi_busy <= 1;
                end else if (~spi_finished & spi_clkin_negedge) begin
                    tx_sr <= {tx_sr[6:0], 1'b0};
                    rx_sr <= {rx_sr[6:0], data_rx};
                    bits_to_tx <= bits_to_tx - 1;
                end else if (spi_finished) begin
                    spi_busy <= 0;
                end
            end
        end
    end
endmodule
