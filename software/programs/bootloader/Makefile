OBJCOPY=../../simulator/asm2bin.py
LIBDIR=../../library
SIMULATOR=../../simulator/build/sim_emulator
LIB_SOURCES=$(LIBDIR)/crt0.S $(LIBDIR)/soc_core.c $(LIBDIR)/soc_io.c
COMPILE=riscv32-unknown-elf-gcc -I$(LIBDIR) -g -march=rv32im -mabi=ilp32  -Wall -nostartfiles  -ffunction-sections -fdata-sections -mstrict-align -Wl,--gc-sections -ffp-contract=off 
COMPILE_FULL=$(COMPILE) -lm -lc -lgcc $(LIB_SOURCES)

.PHONY: all
all: build/test_bootloaded.hex build/bootloader.hex

# .PHONY: sim
# sim: build/icefun_main.hex
# 	$(SIMULATOR) -l build/icefun_main.hex

build/test_bootloaded.hex: build test_bootloaded.c
	$(COMPILE_FULL) -Os  -T$(LIBDIR)/map_bootloaded.ld test_bootloaded.c -o build/test_bootloaded.elf
	$(OBJCOPY) build/test_bootloaded.elf --hex -o build/test_bootloaded.hex

build/bootloader.hex: build bootloader.S
	$(COMPILE) bootloader.S -o build/bootloader.elf
	riscv32-unknown-elf-size build/bootloader.elf
	$(OBJCOPY) build/bootloader.elf --hex -o build/bootloader.hex

build:
	mkdir -p build

.PHONY: clean
clean:
	rm -rf ./build