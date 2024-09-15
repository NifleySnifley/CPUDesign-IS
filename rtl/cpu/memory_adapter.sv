module memory_adapter (
    input clk,
    input rst,

    // CPU-size interface
    input  [31:0] data_addr,
    input  [31:0] data_write,
    output [31:0] data_read,
    input  [ 1:0] size,

    input read_en,
    input write_en,

    output done,

    // Memory size interface
    output [29:0] mem_word_addr,
    output [31:0] mem_write,
    input [31:0] mem_read,
    output [3:0] mem_write_byte_mask,
    output mem_write_enable,
    input mem_ready
);
    // Addr mod 4
    wire [1:0] q = data_addr[1:0];

    wire [29:0] addr_A = data_addr[31:2];
    wire [29:0] addr_B = addr_A + 1;
    // Does the misaligned read/write overlap the next word?
    wire needs_B = (size_onehot[1] & (&q)) | (size_onehot[2] & (|q));

    wire [4:0] size_onehot = 3'b1 << size;
endmodule
