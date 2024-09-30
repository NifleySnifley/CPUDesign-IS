module fontROM #(
    parameter FONT_HEIGHT = 16,
    parameter FONT_WIDTH = 8,
    parameter N_CHARS = 256,
    parameter ROM_BINFILE = "",
    parameter ROM_HEXFILE = ""
) (
    // Character index (ASCII-ish)
    input [$clog2(N_CHARS)-1:0] codepoint,
    // Row in the character
    input [$clog2(FONT_HEIGHT)-1:0] row,

    // Read clock (ASYNC=0)
    input clk,
    // Output row of the character bitmap
    output [FONT_WIDTH-1:0] bitmap_row
);
    reg [FONT_WIDTH-1:0] ROM[(N_CHARS*FONT_HEIGHT)-1:0];

    initial begin
        // Load ROM contents
        if (ROM_BINFILE != "") $readmemb(ROM_BINFILE, ROM);
        if (ROM_HEXFILE != "") $readmemh(ROM_HEXFILE, ROM);
    end

    wire [$clog2(FONT_HEIGHT)+$clog2(N_CHARS)-1:0] index = {codepoint, row};

    assign bitmap_row = ROM[index];
endmodule
