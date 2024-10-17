#!/usr/bin/env python3

import os
from pathlib import Path

def build_tests():
    ASMDIR = Path("tests")
    BUILDDIR = Path("test_build")

    if not os.path.isdir(BUILDDIR):
        os.mkdir(BUILDDIR)

    asmfiles = os.listdir(ASMDIR)
    # print(asmfiles)

    for f in asmfiles:
        fullpath = ASMDIR / f
        if not f.endswith('.S'):
            continue
        # print(f)
        
        OUTELF = BUILDDIR/(fullpath.stem + ".elf")
        OUTBIN = BUILDDIR/(fullpath.stem + ".bin")
        # print(fullpath, OUTELF, OUTBIN)
        ec = os.system(f"riscv32-unknown-elf-gcc -march=rv32im -mabi=ilp32 -nostdlib -ffreestanding {fullpath} -o {OUTELF}")
        if not ec:
            ec |= os.system(f"riscv32-unknown-elf-objcopy -O binary -g {OUTELF} {OUTBIN}")
        if (ec):
            exit(1)
            
if __name__=="__main__":
    build_tests()