module ice40_spram #(
    parameter integer WORDS = 32768,
    parameter BASE_ADDR = 32'hf0000000
) (
    input clk,
    input [3:0] wmask,
    input wen,
    input ren,  // NOTE: Unused!
    input [31:0] addr,
    input [31:0] wdata,
    output [31:0] rdata,
    output done,
    output active
);
    localparam SIZE = WORDS * 4;
    wire cs_0, cs_1;
    wire [31:0] rdata_0, rdata_1;

    assign active = ((addr >= BASE_ADDR) & (addr < (BASE_ADDR + SIZE)));
    // assign active = addr >= BASE_ADDR;

    wire [31:0] addr_local = addr - BASE_ADDR;
    wire [14:0] addr_internal = addr_local[16:2];
    wire [ 3:0] wen_internal = wmask & {4{wen}};

    assign cs_0  = !addr_internal[14];
    assign cs_1  = addr_internal[14];
    assign rdata = addr_internal[14] ? rdata_1 : rdata_0;

    SB_SPRAM256KA ram00 (
        .ADDRESS(addr_internal[13:0]),
        .DATAIN(wdata[15:0]),
        .MASKWREN({wen_internal[1], wen_internal[1], wen_internal[0], wen_internal[0]}),
        .WREN(wen_internal[1] | wen_internal[0]),
        .CHIPSELECT(cs_0),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(rdata_0[15:0])
    );

    SB_SPRAM256KA ram01 (
        .ADDRESS(addr_internal[13:0]),
        .DATAIN(wdata[31:16]),
        .MASKWREN({wen_internal[3], wen_internal[3], wen_internal[2], wen_internal[2]}),
        .WREN(wen_internal[3] | wen_internal[2]),
        .CHIPSELECT(cs_0),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(rdata_0[31:16])
    );

    SB_SPRAM256KA ram10 (
        .ADDRESS(addr_internal[13:0]),
        .DATAIN(wdata[15:0]),
        .MASKWREN({wen_internal[1], wen_internal[1], wen_internal[0], wen_internal[0]}),
        .WREN(wen_internal[1] | wen_internal[0]),
        .CHIPSELECT(cs_1),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(rdata_1[15:0])
    );

    SB_SPRAM256KA ram11 (
        .ADDRESS(addr_internal[13:0]),
        .DATAIN(wdata[31:16]),
        .MASKWREN({wen_internal[3], wen_internal[3], wen_internal[2], wen_internal[2]}),
        .WREN(wen_internal[3] | wen_internal[2]),
        .CHIPSELECT(cs_1),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(rdata_1[31:16])
    );

    reg [31:0] xact_addr;
    assign done = active & (xact_addr == addr);
    always @(posedge clk) begin
        if (ren | wen) xact_addr <= addr;
    end
endmodule




module sim_spram #(
    parameter integer WORDS = 32768,
    parameter BASE_ADDR = 32'hf0000000
) (
    input clk,
    input [3:0] wmask,
    input wen,
    input ren,  // NOTE: Unused!
    input [31:0] addr,
    input [31:0] wdata,
    output reg [31:0] rdata,
    output done,
    output active
);
    localparam SIZE = WORDS * 4;

    reg [31:0] memory[WORDS-1:0];

    assign active = ((addr >= BASE_ADDR) & (addr < (BASE_ADDR + SIZE)));
    // assign active = addr >= BASE_ADDR;

    wire [31:0] addr_local = addr - BASE_ADDR;
    wire [14:0] addr_internal = addr_local[16:2];

    always @(posedge clk) begin
        if (ren) rdata <= memory[addr_internal];
        if (wen) begin
            if (wmask[0]) memory[addr_internal][7:0] <= wdata[7:0];
            if (wmask[1]) memory[addr_internal][15:8] <= wdata[15:8];
            if (wmask[2]) memory[addr_internal][23:16] <= wdata[23:16];
            if (wmask[3]) memory[addr_internal][31:24] <= wdata[31:24];
        end
    end

    reg [31:0] xact_addr;
    assign done = active & (xact_addr == addr);
    always @(posedge clk) begin
        if (ren | wen) xact_addr <= addr;
    end
endmodule
