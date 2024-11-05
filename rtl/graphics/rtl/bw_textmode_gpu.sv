module bw_textmode_gpu #(
    parameter SCREENBUFFER_BASE_ADDR = 32'h82000000,
    parameter FONTROM_INITFILE = ""  // spleen8x16.txt
    // parameter FONTRAM_BASE_ADDR = 32'h10000
) (
    // CLK for bus domain
    input wire clk,
    input wire rst,

    input wire [31:0] addr,
    input wire [31:0] wdata,
    input wire [3:0] wmask,
    input wire wen,
    input wire ren,
    output wire [31:0] rdata,  // Read data output
    output wire ready,  // Read or write done
    output wire active,

    // Input clock for video clock generation
    output reg  hsync,
    output reg  vsync,
    output wire video,   // 1-bit video output.
    input  wire clk_pix
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

    // Font ROM instance for getting character data
    fontROM #(
        .FONT_HEIGHT(16),
        .FONT_WIDTH(8),
        .N_CHARS(256),
        .ROM_BINFILE(FONTROM_INITFILE),
    ) rom (
        .clk(clk_pix),
        .codepoint(current_char),
        .row(char_row),
        .bitmap_row(current_char_bitmap)
    );
    // wire [7:0] bitmap_row;
    wire [7:0] current_char_bitmap;
    // always @(posedge clk) begin
    //     current_char_bitmap <= bitmap_row;
    // end

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
        if (rst_clk_pix | ~vsync) begin
            screenbuffer_index <= 0;
        end else if (~blanking) begin
            // At the end of a column
            if ((x == (SCREEN_W - 1)) & ~(y[3:0] == 4'b1111)) begin
                screenbuffer_index <= screenbuffer_index - (COLS - 1);
            end else if (x[2:0] == 3'b111) begin
                screenbuffer_index <= screenbuffer_index + 1;
            end
        end
    end

    reg [7:0] current_char;  // Codepoint
    wire [3:0] char_row = y[3:0];  // 0-15
    wire [2:0] char_col = x[2:0];  // 0-7

    assign video = (~blanking) & current_char_bitmap[7-char_col];

    reg [31:0] char_reg;

    wire [31:0] sb_prefetch_idx = (x == LINE) ? (screenbuffer_index[11:2]) : (screenbuffer_index[11:2]+1);
    always @(posedge clk_pix) begin
        if ((x == LINE) || (x[4:0] == 5'b11111)) begin
            // Prefetch next character
            char_reg <= screenbuffer[sb_prefetch_idx];
        end
    end

    // Demux screenbuffer words
    always_comb begin
        case (screenbuffer_index[1:0])
            0: current_char = char_reg[7:0];
            1: current_char = char_reg[15:8];
            2: current_char = char_reg[23:16];
            3: current_char = char_reg[31:24];
            default: current_char = 0;
        endcase
    end

    // BUS ACCESS of SCREENBUFFER!
    wire [31:0] local_addr = addr - SCREENBUFFER_BASE_ADDR;
    reg [SB_ADDRBITS-1:0] xact_addr;

    // Don't lock up when attempted read, just give zeros
    assign ready = ren | (word_addr == xact_addr);

    wire [SB_ADDRBITS-1:0] word_addr = local_addr[1+SB_ADDRBITS:2];
    assign active = (addr >= SCREENBUFFER_BASE_ADDR) && (addr < (SCREENBUFFER_BASE_ADDR + SB_NWORDS*4));

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
