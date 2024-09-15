module memory_adapter (
    input clk,
    input rst,

    // CPU-size interface
    input [31:0] data_addr,
    input [31:0] data_write,
    output reg [31:0] data_read,
    input [1:0] size,  // 00 = byte, 01 = half, 10 = word
    input signext,  // For loading bytes and halfs

    input read_en,
    input write_en,

    output done,

    // Memory size interface
    output [29:0] mem_word_addr,
    output [31:0] mem_write,
    input [31:0] mem_read,
    output [3:0] mem_write_byte_mask,
    output mem_write_enable,
    output mem_read_enable,
    input mem_ready
);
    // Addr mod 4
    wire [1:0] q = data_addr[1:0];

    wire [29:0] addr_A = data_addr[31:2];
    wire [29:0] addr_B = addr_A + 1;
    // Does the misaligned read/write overlap the next word?
    wire needs_B = (size_onehot[1] & (&q)) | (size_onehot[2] & (|q));
    // HACK: This is NOT currently implementing unaligned accesses!

    reg [31:0] data_A;
    reg [31:0] data_B;

    wire [4:0] size_onehot = 3'b1 << size;

    assign mem_addr = addr_A;
    assign mem_read_enable = read_en;
    assign done = mem_ready;  // has B aswell for misaligned!

    always @(posedge clk) begin
        if (rst) begin
            // DO SOMETHING!!!
        end else begin
            if (read_en & mem_ready) begin
                data_A <= mem_read;
            end
        end
    end

    reg [31:0] selected_data;
    always_comb begin
        // Output logic
        unique case (1'b1)
            size[0]: begin
                // Byte read
                case (q)
                    0: selected_data = {24'b0, data_A[7:0]};
                    1: selected_data = {24'b0, data_A[15:8]};
                    2: selected_data = {24'b0, data_A[23:16]};
                    3: selected_data = {24'b0, data_A[31:24]};
                    // 3: data_read = {16'b0, data_A[15:0]}; // FIXME: Unaligned!
                    default: selected_data = 32'b0;
                endcase
                data_read = signext ? {{24{selected_data[7]}}, selected_data[7:0]} : selected_data;
            end
            size[1]: begin
                // Half read
                case (q)
                    0: selected_data = {16'b0, data_A[15:0]};
                    1: selected_data = {16'b0, data_A[23:8]};
                    2: selected_data = {16'b0, data_A[31:16]};
                    // 3: data_read = {16'b0, data_A[15:0]}; // FIXME: Unaligned!
                    default: selected_data = 32'b0;
                endcase
                data_read = signext ? {{16{selected_data[15]}}, selected_data[15:0]} : selected_data;
            end
            size[2]: begin
                // Word read
                selected_data = data_A;
            end
            default: selected_data = 32'b0;
        endcase

    end
endmodule
