import argparse
parser = argparse.ArgumentParser()
parser.add_argument("-w", "--width", type=int, default=32)
parser.add_argument("-n", "--num-devices", type=int, default=2)
parser.add_argument("-m", "--mask-bits", type=int, default=4)
args = parser.parse_args()

base = """module bus_hub_N_DEVICES (
    input wire clk,

    // Host (controller) port
    input wire [WIDTH-1:0] host_address,
    input wire [WIDTH-1:0] host_data_write,
    input wire [MASK_BITS-1:0] host_write_mask,
    input wire host_ren,
    input wire host_wen,
    output reg [WIDTH-1:0] host_data_read,
    output reg host_ready,

    // Device ports * N_DEVICES
    output wire [WIDTH*N_DEVICES-1:0] device_address,
    output wire [WIDTH*N_DEVICES-1:0] device_data_write,
    output wire [MASK_BITS*N_DEVICES-1:0] device_write_mask,
    output wire [N_DEVICES-1:0] device_ren,
    output wire [N_DEVICES-1:0] device_wen,
    input wire [N_DEVICES-1:0] device_ready,
    input wire [WIDTH*N_DEVICES-1:0] device_data_read,
    // Self-demultiplexing
    input wire [N_DEVICES-1:0] device_active
);
    // Host->Device
    generate
        genvar i;
        for (i = 0; i < N_DEVICES; i = i + 1) begin
            // Always needed for self-selection
            wire selected = device_active[i];
            assign device_address[(i+1)*WIDTH-1:i*WIDTH] = host_address;
            assign device_data_write[(i+1)*WIDTH-1:i*WIDTH] = host_data_write;
            assign device_write_mask[(i+1)*MASK_BITS-1:i*MASK_BITS] = host_write_mask;
			assign device_wen[i] = selected ? host_wen : 0;
			assign device_ren[i] = selected ? host_ren : 0;
        end
    endgenerate
    
    // Device->Host
    always_comb begin
		casez(device_active)                                
MUXCONTENTS  
			default: begin
				host_data_read = 0;
				host_ready = 1;
			end
		endcase
	end
endmodule"""

WIDTH=args.width
N_DEVICES = args.num_devices
MASK_BITS = args.mask_bits
base = base.replace("WIDTH", str(WIDTH)).replace("N_DEVICES", str(N_DEVICES)).replace("MASK_BITS", str(MASK_BITS))

def case(n):
    return f"""\t\t\t{N_DEVICES}'b{'0'*(N_DEVICES-1-n)}1{'?'*n}: begin
				host_data_read = device_data_read[{(n+1)*WIDTH-1}:{n*WIDTH}];
				host_ready = device_ready[{n}];
			end"""

MUX_CONTENTS = '\n'.join([''+case(n) for n in range(N_DEVICES)])
base = base.replace("MUXCONTENTS", MUX_CONTENTS)

print(base)