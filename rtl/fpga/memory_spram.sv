module memory_spram #(
    parameter BASE_ADDRESS = 32'hf0000000
) (
    input wire clk,
    input wire [31:0] addr,

    input wire [31:0] wdata,
    input wire [3:0] wmask,
    input wire wen,

    input wire ren,
    output reg [31:0] rdata,  // Read data output

    output wire done,   // Read or write done
    output wire active
);
    parameter SPRAM_SIZE_WORDS = 16384;
    parameter N_WORDS = SPRAM_SIZE_WORDS * 2;
    parameter ADDR_BITS = $clog2(N_WORDS);

    // TODO: Test to make sure that the upmost word/bytes of the RAM is actually useable!
    assign active = (addr >= BASE_ADDRESS) & (addr <= (BASE_ADDRESS + SPRAM_SIZE_WORDS * 4 - 4));
    wire [31:0] local_addr = addr - BASE_ADDRESS;

    wire [ADDR_BITS-1:0] word_addr = local_addr[ADDR_BITS-1+2:2];
    wire is_spram_hi = word_addr[ADDR_BITS-1];
    wire [ADDR_BITS-2:0] spram_addr = word_addr[ADDR_BITS-2:0];

    wire [31:0] spram_read_lo;
    wire [31:0] spram_read_hi;
    assign rdata = is_spram_hi ? spram_read_hi : spram_read_lo;

    // Low half of SPRAM memory segment, most significant 16 bits
    SB_SPRAM256KA spram_lo_msb (
        .ADDRESS(spram_addr),
        .MASKWREN({wmask[3], wmask[3], wmask[2], wmask[2]}),
        .WREN(wen & (~is_spram_hi)),
        .CHIPSELECT(1'b1),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAIN(wdata[31:16]),
        .DATAOUT(spram_read_lo[31:16])
    );
    // Low half of SPRAM memory segment, lease significant 16 bits
    SB_SPRAM256KA spram_lo_lsb (
        .ADDRESS(spram_addr),
        .MASKWREN({wmask[1], wmask[1], wmask[0], wmask[0]}),
        .WREN(wen & (~is_spram_hi)),
        .CHIPSELECT(1'b1),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAIN(wdata[15:0]),
        .DATAOUT(spram_read_lo[15:0])
    );

    // High half of SPRAM memory segment, most significant 16 bits
    SB_SPRAM256KA spram_hi_msb (
        .ADDRESS(spram_addr),
        .MASKWREN({wmask[3], wmask[3], wmask[2], wmask[2]}),
        .WREN(wen & is_spram_hi),
        .CHIPSELECT(1'b1),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAIN(wdata[31:16]),
        .DATAOUT(spram_read_hi[31:16])
    );
    // High half of SPRAM memory segment, least significant 16 bits
    SB_SPRAM256KA spram_hi_lsb (
        .ADDRESS(spram_addr),
        .MASKWREN({wmask[1], wmask[1], wmask[0], wmask[0]}),
        .WREN(wen & is_spram_hi),
        .CHIPSELECT(1'b1),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAIN(wdata[15:0]),
        .DATAOUT(spram_read_hi[15:0])
    );

    wire [31:0] local_xact_addr;
    assign done = local_xact_addr == local_addr;
    always @(posedge clk) begin
        if (ren | wen) local_xact_addr <= local_addr;
    end
endmodule
