`include "vga_pll.sv"
`include "fontROM_bram.sv"

module bw_textmode_gpu #(
    parameter SCREENBUFFER_BASE_ADDR = 32'h8000,
    parameter FONTRAM_BASE_ADDR = 32'h10000
) (
    // CLK for bus domain
    input wire clk,
    input wire rst,

    input wire [31:0] addr,
    input wire [31:0] wdata,
    input wire [3:0] wmask,
    input wire wen,
    input wire ren,
    output reg [31:0] rdata,  // Read data output
    output wire ready,  // Read or write done
    output wire active,

    // Input clock for video clock generation
    input wire clk_12MHz,
    output reg hsync,
    output reg vsync,
    output wire video  // 1-bit video output.
);
    localparam FONT_W = 8;
    localparam FONT_H = 16;
    localparam SCREEN_W = 640;
    localparam SCREEN_H = 480;
    localparam ROWS = SCREEN_H / FONT_H;
    localparam COLS = SCREEN_W / FONT_W;

    localparam SB_NWORDS = ((ROWS * COLS) / 4);
    localparam SB_ADDRBITS = $clog2(SB_NWORDS);

    // Character screenbuffer NOTE: This is comprised of 32-bit words!
    reg [31:0] screenbuffer[SB_NWORDS-1:0];

    // 25.175 (ish) MHz
    wire clk_pix;
    wire pll_locked;
    vga_pll pll (
        .clock_in(clk_12MHz),
        .clock_out(clk_pix),
        .locked(pll_locked)
    );



    // Font ROM instance for getting character data
    fontROM #(
        .FONT_HEIGHT(16),
        .FONT_WIDTH(8),
        .N_CHARS(256),
        .ROM_BINFILE("spleen8x16.txt"),
        .ASYNC(0)
    ) rom (
        .clk(clk_pix),
        .codepoint(current_char),
        .row(char_row),
        .bitmap_row(current_char_bitmap)
    );




    // CDC for reset signal
    reg rst_clk_pix;
    reg rst_clk_pipe;
    always @(posedge clk_pix) begin
        {rst_clk_pix, rst_clk_pipe} <= {rst_clk_pipe, rst};
    end




    // Video generation signals
    reg [9:0] x;
    reg [9:0] y;
    reg blanking;
    // TODO: Keep incrementing this every valid row/column segment?
    // Increment by one every 8 pixels
    // Decrement by 80 at the end of a row, if the row is not the 16th row in the line
    // At the end of the screen, reset to zero
    reg [11:0] screenbuffer_index;

    // Timing constants credit to Project F: FPGA Graphics - Simple 640x480p60 Display
    // (C)2022 Will Green, open source hardware released under the MIT License
    // Learn more at https://projectf.io/posts/fpga-graphics/
    parameter HA_END = 639;  // end of active pixels
    parameter HS_STA = HA_END + 16;  // sync starts after front porch
    parameter HS_END = HS_STA + 96;  // sync ends
    parameter LINE = 799;  // last pixel on line (after back porch)
    parameter VA_END = 479;  // end of active pixels
    parameter VS_STA = VA_END + 10;  // sync starts after front porch
    parameter VS_END = VS_STA + 2;  // sync ends
    parameter SCREEN = 524;  // last line on screen (after back porch)

    // Sync
    always_comb begin
        hsync = ~(x >= HS_STA && x < HS_END);  // invert: negative polarity
        vsync = ~(y >= VS_STA && y < VS_END);  // invert: negative polarity
        blanking = ~(x <= HA_END && y <= VA_END);
    end

    // calculate horizontal and vertical screen position
    always_ff @(posedge clk_pix) begin
        if (x == LINE) begin  // last pixel on line?
            x <= 0;
            y <= (y == SCREEN) ? 0 : y + 1;
        end else begin
            x <= x + 1;
        end
        if (rst_clk_pix) begin
            x <= 0;
            y <= 0;
        end
    end



    // TODO: This is SKETCH. Need to check!
    always @(posedge clk_pix) begin
        if (rst_clk_pix) begin
            screenbuffer_index <= 0;
        end else if (~blanking) begin
            // At the end of a column
            if (x[2:0] == 3'b111) begin
                if ((x == (COLS - 1)) && (y == (ROWS - 1))) begin
                    // Final pixel, reset
                    screenbuffer_index <= 0;
                end else if ((x == (COLS - 1)) && ~(y[3:0] == 4'b1111)) begin
                    // End of a row but not the bottom (bottom keeps going)
                    // Go to start of line (left)
                    screenbuffer_index <= screenbuffer_index - 80;
                end else begin
                    // Increment (right)
                    screenbuffer_index <= screenbuffer_index + 1;
                end
            end
        end
    end

    reg [7:0] current_char;  // Codepoint
    wire [3:0] char_row = y[3:0];  // 0-15
    wire [2:0] char_col = x[2:0];  // 0-7
    wire [7:0] current_char_bitmap;

    assign video = (~blanking) & current_char_bitmap[char_col];

    always @(posedge clk_pix) begin
        // Demux screenbuffer words
        case (screenbuffer_index[1:0])
            0: current_char <= screenbuffer[screenbuffer_index[9:0]][7:0];
            1: current_char <= screenbuffer[screenbuffer_index[9:0]][15:8];
            2: current_char <= screenbuffer[screenbuffer_index[9:0]][23:16];
            3: current_char <= screenbuffer[screenbuffer_index[9:0]][31:24];
            default: current_char <= 0;
        endcase
    end




    // BUS ACCESS of SCREENBUFFER!
    wire [31:0] local_addr = addr - SCREENBUFFER_BASE_ADDR;
    reg [SB_ADDRBITS-1:0] xact_addr;

    // Don't lock up when attempted read, just give zeros
    assign ready = ren | (word_addr == xact_addr);

    wire [SB_ADDRBITS-1:0] word_addr = local_addr[1+SB_ADDRBITS:2];
    assign active = (addr >= SCREENBUFFER_BASE_ADDR) && (addr < (SCREENBUFFER_BASE_ADDR + SB_NWORDS));

    always @(posedge clk) begin
        if (wen & active) begin
            if (wmask[0]) screenbuffer[word_addr][7:0] <= wdata[7:0];
            if (wmask[1]) screenbuffer[word_addr][15:8] <= wdata[15:8];
            if (wmask[2]) screenbuffer[word_addr][23:16] <= wdata[23:16];
            if (wmask[3]) screenbuffer[word_addr][31:24] <= wdata[31:24];
        end

        if (wen) xact_addr <= word_addr;
    end
    assign rdata = 0;  // No reading! Nuh uh not allowed.
endmodule
