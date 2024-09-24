OBJCOPY=../../simulator/asm2bin.py
LIBDIR=../../library
SIMULATOR=../../simulator/build/sim_emulator
COMPILE=riscv32-unknown-elf-gcc -I$(LIBDIR) -g -march=rv32i -mabi=ilp32  -Wall -nostartfiles  -ffunction-sections -fdata-sections -mstrict-align -Wl,--gc-sections -ffp-contract=off -lm -lc -lgcc -Tmap.ld crt0.S

.PHONY: all
all: build/main.hex build/main.bin build/graphics_test.bin

.PHONY: sim
sim: build/main.bin
	$(SIMULATOR) -l build/main.bin

build/main.hex: build/main.elf
	$(OBJCOPY) build/main.elf --hex -o build/main.hex

build/main.bin: build/main.elf
	$(OBJCOPY) build/main.elf --raw -o build/main.bin

.PHONY: dissasemble
dissasemble: build/main.elf
	riscv32-unknown-elf-objdump -d -S build/main.elf
	riscv32-unknown-elf-size build/main.elf

.PHONY: build/main.elf
build/main.elf: build main.c
	$(COMPILE) main.c -o build/main.elf
	riscv32-unknown-elf-size build/main.elf

build/graphics_test.bin: graphics_test.c
	$(COMPILE) graphics_test.c -o build/graphics_test.elf
	$(OBJCOPY) build/graphics_test.elf --raw -o build/graphics_test.bin

build:
	mkdir -p build

.PHONY: clean
clean:
	rm -rf ./build