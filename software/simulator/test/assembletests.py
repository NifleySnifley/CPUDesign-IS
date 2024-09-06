import os
from pathlib import Path

ASMDIR = Path("riscv")
BUILDDIR = Path("build")
LINKSCRIPT = Path("./map.ld")


if not os.path.isdir(BUILDDIR):
    os.mkdir(BUILDDIR)

asmfiles = os.listdir(ASMDIR)

for f in asmfiles:
    fullpath = ASMDIR / f
    if not f.endswith('.S'):
        continue
    OUTELF = BUILDDIR/(fullpath.stem + ".elf")
    OUTBIN = BUILDDIR/(fullpath.stem + ".bin")
    print(fullpath, OUTELF, OUTBIN)
    ec = os.system(f"riscv32-unknown-elf-gcc -nostdlib -ffreestanding -T{LINKSCRIPT} {fullpath} -o {OUTELF}")
    if not ec:
        ec |= os.system(f"riscv32-unknown-elf-objcopy -O binary -g {OUTELF} {OUTBIN}")
    if (ec):
        exit(1)