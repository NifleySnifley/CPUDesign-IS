OBJCOPY=../../simulator/asm2bin.py
LIBDIR=../../library

build/main.hex: build/main.elf
	riscv32-unknown-elf-size build/main.elf
	$(OBJCOPY) build/main.elf --hex -o build/main.hex

.PHONY: dissasemble
dissasemble: build/main.elf
	riscv32-unknown-elf-objdump -d -S build/main.elf
	riscv32-unknown-elf-size build/main.elf

build/main.elf: build main.c
	riscv32-unknown-elf-gcc -I$(LIBDIR) -g -march=rv32i -mabi=ilp32  -Wall -nostartfiles  -ffunction-sections -fdata-sections -mstrict-align -Wl,--gc-sections -ffp-contract=off -lm -lc -lgcc -Tmap.ld main.c -o build/main.elf

build:
	mkdir -p build

.PHONY: clean
clean:
	rm -rf ./build