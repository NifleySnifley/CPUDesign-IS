module bus_hub_1 (
    input wire clk,

    // Host (controller) port
    input wire [32-1:0] host_address,
    input wire [32-1:0] host_data_write,
    input wire [4-1:0] host_write_mask,
    input wire host_ren,
    input wire host_wen,
    output reg [32-1:0] host_data_read,
    output reg host_ready,

    // Device ports * 1
    output wire [32*1-1:0] device_address,
    output wire [32*1-1:0] device_data_write,
    output wire [4*1-1:0] device_write_mask,
    output wire [1-1:0] device_ren,
    output wire [1-1:0] device_wen,
    input wire [1-1:0] device_ready,
    input wire [32*1-1:0] device_data_read,
    // Self-demultiplexing
    input wire [1-1:0] device_active
);
    // Host->Device
    generate
        genvar i;
        for (i = 0; i < 1; i = i + 1) begin
            // Always needed for self-selection
            wire selected = device_active[i];
            assign device_address[(i+1)*32-1:i*32] = host_address;
            assign device_data_write[(i+1)*32-1:i*32] = host_data_write;
            assign device_write_mask[(i+1)*4-1:i*4] = host_write_mask;
			assign device_wen[i] = selected ? host_wen : 0;
			assign device_ren[i] = selected ? host_ren : 0;
        end
    endgenerate
    
    // Device->Host
    always_comb begin
		casez(device_active)                                
			1'b1: begin
				host_data_read = device_data_read[31:0];
				host_ready = device_ready[0];
			end  
			default: begin
				host_data_read = 0;
				host_ready = 1;
			end
		endcase
	end
endmodule
