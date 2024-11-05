module bus_hub_2_pl (
    input wire clk,

    // Host (controller) port
    input wire [32-1:0] host_address,
    input wire [32-1:0] host_data_write,
    input wire [4-1:0] host_write_mask,
    input wire host_ren,
    input wire host_wen,
    output reg [32-1:0] host_data_read,
    output wire host_ready,

    // Device ports * 2
    output wire [32*2-1:0] device_address,
    output wire [32*2-1:0] device_data_write,
    output wire [4*2-1:0] device_write_mask,
    output wire [2-1:0] device_ren,
    output wire [2-1:0] device_wen,
    input wire [2-1:0] device_ready,
    input wire [32*2-1:0] device_data_read,
    // Self-demultiplexing
    input wire [2-1:0] device_active
);
    // Host->Device
    generate
        genvar i;
        for (i = 0; i < 2; i = i + 1) begin
            // Always needed for self-selection
            wire selected = device_active[i];
            assign device_address[(i+1)*32-1:i*32] = host_address;
            assign device_data_write[(i+1)*32-1:i*32] = host_data_write;
            assign device_write_mask[(i+1)*4-1:i*4] = host_write_mask;
            assign device_wen[i] = selected ? host_wen : 0;
            assign device_ren[i] = selected ? host_ren : 0;
        end
    endgenerate

    reg [$clog2(2+1)-1:0] dev_n_selected = 0;

    assign host_ready = (dev_n_selected == 0) ? 1'b1 : |(device_ready);

    // Device->Host
    always @(posedge clk) begin
        casez (device_active)
            2'b01:   dev_n_selected <= 1;
            2'b1?:   dev_n_selected <= 2;
            default: dev_n_selected <= 0;
        endcase
    end

    always_comb begin
        case (dev_n_selected)
            1: host_data_read = device_data_read[31:0];
            2: host_data_read = device_data_read[63:32];
            default: host_data_read = 0;
        endcase
    end

endmodule
