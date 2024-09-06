#!/usr/bin/env python3
import os
from pathlib import Path
import tempfile
import subprocess

import argparse
parser = argparse.ArgumentParser()
parser.add_argument("input", type=Path)
parser.add_argument("-o", "--output", type=Path, required=False)
args = parser.parse_args()

p = Path()
if (args.output is None):
    args.output = args.input.parent / Path(args.input.absolute().stem + ".expanded.S")

scriptdir = Path(__file__).resolve().parent
ldfile = scriptdir / ".." / "programs" / "test_baremetal" / "memory_map.ld"

td = Path(tempfile.mkdtemp("asm2asm"))
tf = td/'out.elf'

os.system(f"riscv32-unknown-elf-gcc -nostdlib -ffreestanding -T{ldfile} {args.input} -o {tf}")
out = subprocess.check_output([f"riscv32-unknown-elf-objdump", '-d','--no-show-raw-insn', '--no-addresses','-M', 'no-aliases', tf])

with open(args.output, 'wb') as f:
    f.write(out)