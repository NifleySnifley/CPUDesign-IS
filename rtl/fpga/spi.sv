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
    output wire data_tx,
    input  wire data_rx,
    output wire cs
);

    /////////////////////////////////////// BUS INTERFACE ///////////////////////////////////////
    parameter REG_STATUS = ADDR + 0;
    parameter REG_CONTROL = ADDR + 4;
    parameter REG_DATA = ADDR + 8;  // +0 = DATAOUT, +1=DATAIN

    wire [31:0] status;
    reg  [31:0] control = 0;
    reg  [ 7:0] dataout;
    reg  [ 7:0] datain;

    assign active = (addr == REG_STATUS) | (addr == REG_CONTROL) | (addr == REG_DATA);
    // assign ready  = 1;

    // Bus writing
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

    reg [31:0] transact_addr = 0;
    // Bus reading
    always_comb begin
        case (addr)
            REG_STATUS: rdata = status;
            REG_CONTROL: rdata = control;
            REG_DATA: rdata = {16'b0, datain, dataout};
            default: rdata = 32'b0;
        endcase
    end
    always @(posedge clk) begin
        transact_addr <= addr;
    end
    assign ready = (addr == transact_addr);

    /////////////////////////////////////// CONTROL DECODING ///////////////////////////////////////
    wire tx_start = control[0];
    wire hw_cs_n = control[1];
    wire [29:0] clkdivider = control[31:2];  // 30 bits of clock divider
    wire spi_busy, spi_finished;
    assign status = {30'b0, spi_busy, spi_finished};

    assign cs = ~hw_cs_n;

    /////////////////////////////////////// SPI CLOCKGEN ///////////////////////////////////////
    reg clock_spi;
    reg [29:0] clk_counter;
    reg txstart_prev = 0;
    always @(posedge clk) begin
        txstart_prev <= tx_start;

        // Hot-start the SPI clock for some reason (saves time in spi transaction)
        if (~txstart_prev & tx_start) begin
            clk_counter <= clkdivider;
            clock_spi   <= 1;
        end else begin
            if (clk_counter >= clkdivider) begin
                clk_counter <= 0;
                clock_spi   <= ~clock_spi;
            end else begin
                clk_counter <= clk_counter + 1;
            end
        end
    end

    /////////////////////////////////////// SPI TRANSACTION ///////////////////////////////////////
    // TODO: Everything must cross over to spi clock domain!
    parameter SPI_STATE_IDLE = 4'b0001;
    parameter SPI_STATE_TRANSCEIVING = 4'b0010;
    parameter SPI_STATE_DONE = 4'b0100;
    reg [3:0] spi_state = SPI_STATE_IDLE;
    reg [3:0] bits_remaining = 0;

    // Busy if transmission has been started and is idle
    assign spi_busy = (spi_state != SPI_STATE_IDLE) | tx_start;
    assign spi_finished = (spi_state == SPI_STATE_DONE);
    reg spi_clock_gate = 0;
    assign sclk = clock_spi & spi_clock_gate;

    reg [7:0] shift_in;
    reg [7:0] shift_out;

    assign data_tx = shift_out[7];

    reg prev_clock_spi = 0;
    wire clock_spi_posedge = (clock_spi & ~prev_clock_spi);
    wire clock_spi_negedge = (~clock_spi & prev_clock_spi);

    always @(posedge clk) begin
        prev_clock_spi <= clock_spi;
        case (spi_state)
            SPI_STATE_IDLE: begin
                if (clock_spi_negedge & tx_start) begin
                    spi_clock_gate <= 1;
                    bits_remaining <= 8;
                    shift_out <= dataout;
                    shift_in <= 0;
                    datain <= 0;
                    spi_state <= SPI_STATE_TRANSCEIVING;
                end else begin
                    spi_clock_gate <= 0;
                    datain <= shift_in;
                end
            end
            SPI_STATE_TRANSCEIVING: begin
                if (bits_remaining == 0 & clock_spi_negedge) begin
                    spi_clock_gate <= 0;
                    datain <= shift_in;
                    shift_out <= 0;

                    spi_state <= SPI_STATE_DONE;
                end else begin
                    if (clock_spi_negedge) begin
                        // Output data on falling edge, shift out MSB first
                        shift_out <= {shift_out[6:0], 1'b0};
                    end

                    if (clock_spi_posedge) begin
                        shift_in <= {shift_in[6:0], data_rx};
                        bits_remaining <= bits_remaining - 1;
                    end
                end
            end
            SPI_STATE_DONE: begin
                // When TX goes low, reset
                if (clk & ~tx_start) spi_state <= SPI_STATE_IDLE;
            end
            default: spi_state <= SPI_STATE_IDLE;
        endcase
    end

    // Receive using gated SCLK

endmodule
