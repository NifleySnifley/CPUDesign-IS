#!/usr/bin/env python3
import argparse
from pathlib import Path
import itertools as it

P = argparse.ArgumentParser()
P.add_argument("-m", "--modname", default="rom")
P.add_argument("-s", "--sync", action="store_true")
P.add_argument("infile")
P.add_argument("outfile")

A = P.parse_args()

def load_file(name):
    ftype = Path(name).suffix
    input_data = bytes()
    if ftype == ".bin":
        with open(name, "rb") as f:
            input_data = f.read()
    elif ftype == ".hex":
        with open(name, "r") as f:
            words = [
                int(line.strip(), 16).to_bytes(4, "little") for line in f.readlines()
            ]
            for w in words:
                input_data += w
    elif ftype == ".txt":
        with open(name, "r") as f:
            words = [
                int(line.strip(), 2).to_bytes(4, "little") for line in f.readlines()
            ]
            for w in words:
                input_data += w
    return input_data

data = load_file(A.infile)

# print(data)
inwords = [list([i[1] for i in d[1]]) for d in it.groupby(enumerate(data), lambda x: x[0]//4)]
inwords = [sum([d << (8*i) for i,d in enumerate(g)]) for g in inwords]
# print([hex(w) for w in inwords])
# exit()

cases = '\n'.join([f"\t\t\t\t32'h{i*4:x}:   data {'<=' if A.sync else '='} 32'h{w:08x};" for i, w in enumerate(inwords)])

rom_code_sync = \
f"""\
module {A.modname} (
    input wire clk,
    input wire ren,
    input wire [31:0] addr,
    output reg [31:0] data
);
    always @(posedge clk) begin
        if (ren) begin
            case (addr)
{cases}
                default: data <= 32'h00000000;
            endcase
        end
    end
endmodule
"""

rom_code_async = \
f"""\
module {A.modname} (
    input wire [31:0] addr,
    output reg [31:0] data
);
    always_comb begin
        case (addr)
{cases}
            default: data = 32'h00000000;
        endcase
    end
endmodule
"""

with open(A.outfile, 'w') as f:
    f.write(rom_code_sync if A.sync else rom_code_async)