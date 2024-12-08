// `include "pll_100MHz.sv"

module hub75_driver #(
    parameter ROWS = 64,  // Addressable
    parameter COLS = 64,  // Shiftable
    parameter BASEADDR = 32'h81000000,
    localparam ROWS_2 = ROWS / 2,
    localparam ADDRBITS = $clog2(ROWS_2)
) (
    input wire clk,
    input wire output_clk,

    // Bus device
    input wire [31:0] addr,
    input wire [31:0] wdata,
    input wire [3:0] wmask,
    input wire wen,
    input wire ren,
    output reg [31:0] rdata,
    output reg ready,
    output wire active,

    // HUB75 Interface
    output wire R0,
    output wire R1,
    output wire G0,
    output wire G1,
    output wire B0,
    output wire B1,
    output wire [ADDRBITS-1:0] ROWSEL,
    output wire CLK_HUB75,
    output wire LATCH,  // Latches on rising edge
    output wire OE  // Active low
);
    initial rdata = 0;
    initial ready = 0;

    localparam PWM_BITS = 8;
    localparam BUFFER_SIZE_W = ROWS * COLS * 2;
    // Two buffers (A and B)
    (* ram_style = "block" *)
    reg [PWM_BITS*3-1:0] buffer[BUFFER_SIZE_W-1:0];
    reg [31:0] control = 0;  // buffer_A default (0)

    // FIXME: Register buffer swap ONLY at the end of a screen draw (last row, last col, and pwm @ 254)
    // Will prevent tearing/artifacts
    wire buffer_select = control[0];
    // reg buffer_select_registered = 0;

    // 2 buffers and control register

    localparam N_WORDS = BUFFER_SIZE_W + 1;
    localparam BUFFER_ADDRBITS = $clog2(BUFFER_SIZE_W);

    wire [29:0] word_addr = addr[31:2];
    assign active = (addr >= BASEADDR) && (addr < (BASEADDR + N_WORDS * 4));
    wire [29:0] local_word_addr = word_addr - BASEADDR[31:2];

    wire [BUFFER_ADDRBITS-1:0] buf_addr = local_word_addr[BUFFER_ADDRBITS-1:0];

    // Bus interface
    always @(posedge clk) begin
        if (active) begin
            if (local_word_addr < BUFFER_SIZE_W) begin
                // Buffer A
                if (wen) begin
                    if (wmask[0]) buffer[buf_addr][7:0] <= wdata[7:0];
                    if (wmask[1]) buffer[buf_addr][15:8] <= wdata[15:8];
                    if (wmask[2]) buffer[buf_addr][23:16] <= wdata[23:16];
                end else begin
                    // TODO: Fix reading
                    // rdata <= {8'b0, buffer[buf_addr]};
                end

            end else begin
                // Control register
                if (wen) begin
                    if (wmask[0]) control[7:0] <= wdata[7:0];
                    if (wmask[1]) control[15:8] <= wdata[15:8];
                    if (wmask[2]) control[23:16] <= wdata[23:16];
                    if (wmask[3]) control[31:24] <= wdata[31:24];
                end
                rdata <= control;
            end
            ready <= ren | wen;
        end
    end

    // pll_100MHz pll (
    //     .clkin(clk),  // 50 MHz, 0 deg
    //     .clkout0(hub75_clock)  // 100 MHz, 0 deg
    // );

    // HUB75 Control logic
    // TODO: Divider!
    wire hub75_clock = output_clk;
    // reg [7:0] div = 0;
    // always @(posedge clk) begin
    //     div <= div + 1;
    // end
    // wire hub75_clock = div[7];

    localparam H_STATE_RL = 3'b001;
    localparam H_STATE_RH = 3'b010;
    localparam H_STATE_SHIFT = 3'b100;
    reg [2:0] h_state = H_STATE_RL;

    reg [$clog2(ROWS_2)-1:0] row_2 = 0;  // Increase after row is clocked
    reg [$clog2(COLS)-1:0] col = 0;  // Increase as bits are clocked out
    reg [PWM_BITS-1:0] pwm_step = 0;  // Increase every screen draw

    // Pixel colors
    reg [(PWM_BITS*3)-1:0] pix_low;
    reg [(PWM_BITS*3)-1:0] pix_high;
    reg [(PWM_BITS*3)-1:0] pix_low_reg;
    reg [(PWM_BITS*3)-1:0] pix_high_reg;
    reg had_pl = 0;
    reg had_ph = 0;

    reg [(PWM_BITS*3)-1:0] buffer_read;
    wire [BUFFER_ADDRBITS-1:0] buffer_read_addr = {
        buffer_select, h_state == H_STATE_RH, row_2, col
    };

    always @(posedge hub75_clock) begin
        buffer_read <= buffer[buffer_read_addr];
        had_pl <= h_state == H_STATE_RL;
        had_ph <= h_state == H_STATE_RH;
        if (had_pl) pix_low_reg <= buffer_read;
        if (had_ph) pix_high_reg <= buffer_read;
    end

    always_comb begin
        pix_low  = had_pl ? buffer_read : pix_low_reg;
        pix_high = had_ph ? buffer_read : pix_high_reg;
    end

    // RGB
    wire [PWM_BITS-1:0] low_R = pix_low[PWM_BITS-1:0];
    wire [PWM_BITS-1:0] low_G = pix_low[PWM_BITS*2-1:PWM_BITS];
    wire [PWM_BITS-1:0] low_B = pix_low[PWM_BITS*3-1:PWM_BITS*2];
    wire [PWM_BITS-1:0] high_R = pix_high[PWM_BITS-1:0];
    wire [PWM_BITS-1:0] high_G = pix_high[PWM_BITS*2-1:PWM_BITS];
    wire [PWM_BITS-1:0] high_B = pix_high[PWM_BITS*3-1:PWM_BITS*2];
    // PWMming (7-bit)
    assign R0 = low_R > pwm_step;
    assign G0 = low_G > pwm_step;
    assign B0 = low_B > pwm_step;
    assign R1 = high_R > pwm_step;
    assign G1 = high_G > pwm_step;
    assign B1 = high_B > pwm_step;


    assign CLK_HUB75 = (h_state == H_STATE_SHIFT);
    // Display the LAST WRITTEN row!
    // While rowsel is selected, pixels for the next row are clocked in
    // then they are latched and displayed while the next row is clocked in
    assign ROWSEL = row_2 - 1;
    // TODO: Global brightness control by PWMming OE?

    localparam LAST_COL = COLS - 1;
    localparam LAST_ROW = ROWS_2 - 1;

    // TODO: Pixel clock, etc.
    // TODO: Eliminate this FSM to allow pixel output at 1-1/2 pixels/clk
    // Store top/bottom on seperate memories...
    // Restructure buffer for adjacency, or do some other monkey business
    always @(posedge hub75_clock) begin
        unique case (h_state)
            H_STATE_RL: begin
                // pix_low <= pix_low_next;
                h_state <= H_STATE_RH;
            end
            H_STATE_RH: begin
                // pix_high <= pix_high_next;
                h_state <= H_STATE_SHIFT;
            end
            H_STATE_SHIFT: begin
                h_state <= H_STATE_RL;
            end
            default: h_state <= H_STATE_RL;
        endcase

        // Every Pixel
        if (h_state == H_STATE_SHIFT) begin
            if (col == LAST_COL[5:0]) begin
                // End of screen
                if (row_2 == (LAST_ROW[4:0])) begin
                    row_2 <= 0;

                    // PWM increase from 0->254, not 255 so color value of 255 is 100% duty
                    // TODO: make PWM less flickerey!!!
                    pwm_step <= (pwm_step == (128 - 1)) ? 0 : (pwm_step + 1);
                end else row_2 <= row_2 + 1;

                // End of column, reset and latch data
                col <= 0;
            end else begin
                col <= col + 1;
            end
        end
    end

    // Latch data at end of column (start of next)
    assign LATCH = (h_state == H_STATE_SHIFT) && (col == 0);
    assign OE = col == 0;  // Always display
endmodule
