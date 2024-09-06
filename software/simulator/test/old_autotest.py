#!/usr/bin/env python3
import os
from pathlib import Path
import subprocess
import tempfile

ASMDIR = Path("asm")
BUILDDIR = Path("build")
LINKSCRIPT = Path("../../programs/test_baremetal/memory_map.ld")

if not os.path.isdir(BUILDDIR):
    os.mkdir(BUILDDIR)

asmfiles = os.listdir("asm")

outputs = []
for f in asmfiles:
    fullpath = ASMDIR / f
    OUTELF = BUILDDIR/(fullpath.stem + ".elf")
    OUTBIN = BUILDDIR/(fullpath.stem + ".bin")
    outputs.append((OUTELF, OUTBIN))
    print(fullpath, OUTELF, OUTBIN)
    ec = os.system(f"riscv32-unknown-elf-gcc -nostdlib -ffreestanding -T{LINKSCRIPT} {fullpath} -o {OUTELF}")
    ec |= os.system(f"riscv32-unknown-elf-objcopy -O binary -g {OUTELF} {OUTBIN}")
    if (ec):
        exit(1)

MEM_SIZE = 0x2000

def simulate_spike(elf: str):
    pass

def simulate_cli(binf: str):
    out_memory = tempfile.mktemp()
    out_registers = tempfile.mktemp()

    os.system(f"../build/sim_cli -m {MEM_SIZE} -o {out_memory} -r {out_registers} {binf}")
    
    mem_contents = bytes()
    with open(out_memory, 'rb') as f:
        mem_contents = f.read()

    print(mem_contents)

# Files have been assembled, now run them!
for f_elf, f_bin in outputs:
    # Run sim_cli and get memory+register content
    o1 = simulate_cli(f_bin)

    # o2 = simulate_spike(f_elf)