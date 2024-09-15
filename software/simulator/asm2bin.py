#!/usr/bin/env python3
import os
from pathlib import Path
import tempfile
import subprocess

import argparse
parser = argparse.ArgumentParser()
parser.add_argument("input", type=Path)
parser.add_argument("-o", "--output", type=Path, required=False)
parser.add_argument("-b", "--bin", action="store_true")
args = parser.parse_args()

p = Path()
if (args.output is None):
    args.output = args.input.parent / Path(args.input.absolute().stem + (".txt" if not args.bin else ".bin"))

scriptdir = Path(__file__).resolve().parent
ldfile = scriptdir / ".." / "programs" / "test_baremetal" / "memory_map.ld"

td = Path(tempfile.mkdtemp("asm2bin"))
tf = td/'out.elf'
tfbin = td/'out.bin'

os.system(f"riscv32-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -ffreestanding -T{ldfile} {args.input} -o {tf}")
out1 = subprocess.check_output([f"riscv32-unknown-elf-objdump",'-d','-M', 'no-aliases', tf])
print(out1.decode('ascii'))
out = subprocess.check_output(["riscv32-unknown-elf-objcopy", "-O", "binary", "-g", tf, tfbin])

with open(tfbin, 'rb') as bf:
    bs = bf.read()
    assert(len(bs) % 4 == 0)

    ints = [int.from_bytes(bs[i*4:i*4+4], byteorder='little') for i in range(0, len(bs)//4)]
    # print([hex(i) for i in ints])
    
    if (args.bin):
        with open(args.output, 'wb') as f:
            print(len(bs))
            f.write(bs)
            f.flush()
    else:
        with open(args.output, 'w') as f:
            for i in ints:
                print(hex(i))
                bstr = bin(i)[2:].rjust(32, '0')
                f.write(f"{bstr[::1]}\n")
            f.flush()
            

# with open(args.output, 'wb') as f:
    # f.write(out)