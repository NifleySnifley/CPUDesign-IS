#!/usr/bin/env python3
import os
from pathlib import Path
import tempfile
import subprocess

import argparse
parser = argparse.ArgumentParser()
parser.add_argument("input", type=Path)
parser.add_argument("-o", "--output", type=Path, required=False)
parser.add_argument("-r", "--raw", action="store_true", help="Writes program data as raw binary format")
parser.add_argument("-x", "--hex", action="store_true", help="Writes program data hex-formatted in 32-bit words")
parser.add_argument("-p", "--pad", type=int)
parser.add_argument("-a", "--assemble", action="store_true", help="Treat the input as assembly and assemble it")
parser.add_argument("-d", "--dissasemble", action="store_true",help="Show dissasembly of input")
args = parser.parse_args()

p = Path()
if (args.output is None):
    args.output = args.input.parent / Path(args.input.absolute().stem + ((".txt" if not args.hex else ".hex") if not args.raw else ".bin"))

scriptdir = Path(__file__).resolve().parent
ldfile = scriptdir / ".." / "programs" / "test_baremetal" / "memory_map.ld"

td = Path(tempfile.mkdtemp("asm2bin"))
tf = td/'out.elf'
tfbin = td/'out.bin'

if (args.assemble):
    if(os.system(f"riscv32-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -ffreestanding -T{ldfile} {args.input} -o {tf}")):
        exit(1)
else:
    tf = args.input

if(args.dissasemble and subprocess.call([f"riscv32-unknown-elf-objdump",'-d','-M', 'no-aliases', tf])):
    exit(1)
    # print(out1.decode('ascii'))

if(subprocess.call(["riscv32-unknown-elf-objcopy", "-O", "binary", "-g", tf, tfbin])):
    exit(1)

with open(tfbin, 'rb') as bf:
    bs = bf.read()
    assert(len(bs) % 4 == 0)
    if (args.pad is not None):
        if (len(bs) > args.pad):
            print("Error, binary file is larger than requested padding size! Aborting")
            exit(1)
        bs += bytes([0 for i in range(args.pad - len(bs))])

    ints = [int.from_bytes(bs[i*4:i*4+4], byteorder='little') for i in range(0, len(bs)//4)]
    # print([hex(i) for i in ints])
    
    if (args.raw):
        with open(args.output, 'wb') as f:
            # print(len(bs))
            f.write(bs)
            f.flush()
    elif (args.hex):
        with open(args.output, 'w') as f:
            for i in ints:
                bstr = hex(i)[2:].rjust(8, '0')
                f.write(f"{bstr[::1]}\n")
            f.flush()
    else:
        with open(args.output, 'w') as f:
            for i in ints:
                # print(hex(i))
                bstr = bin(i)[2:].rjust(32, '0')
                f.write(f"{bstr[::1]}\n")
            f.flush()
            

# with open(args.output, 'wb') as f:
    # f.write(out)