OBJCOPY=../../simulator/asm2bin.py
LIBDIR=../../library
SIMULATOR=../../simulator/build/sim_emulator
COMPILE=riscv32-unknown-elf-gcc -I$(LIBDIR) -g -march=rv32im -mabi=ilp32  -Wall -nostartfiles  -ffunction-sections -fdata-sections -mstrict-align -Wl,--gc-sections -ffp-contract=off -lm -lc -lgcc $(LIBDIR)/crt0.S $(LIBDIR)/soc_core.c

.PHONY: all
all: build/icefun_main.hex build/upduino_main.hex build/graphics_test.hex build/cgol.hex

.PHONY: sim
sim: build/icefun_main.hex
	$(SIMULATOR) -l build/icefun_main.hex

.PHONY: build/graphics_test.hex
build/graphics_test.hex: graphics_test.c
	$(COMPILE) -Os  -T$(LIBDIR)/map_spram.ld graphics_test.c -o build/graphics_test.elf
	$(OBJCOPY) build/graphics_test.elf --hex -o build/graphics_test.hex

.PHONY: build/icefun_main.hex
build/icefun_main.hex: icefun_main.c build
	$(COMPILE) -Os  -T$(LIBDIR)/map.ld icefun_main.c -o build/icefun_main.elf
	$(OBJCOPY) build/icefun_main.elf --hex -o build/icefun_main.hex
	
.PHONY: build/upduino_main.hex
build/upduino_main.hex: upduino_main.c build
	$(COMPILE) -Os  -T$(LIBDIR)/map_spram.ld upduino_main.c -o build/upduino_main.elf
	$(OBJCOPY) build/upduino_main.elf --hex -o build/upduino_main.hex

.PHONY: build/cgol.hex
build/cgol.hex: cgol.c build
	$(COMPILE) -T$(LIBDIR)/map_spram.ld cgol.c -o build/cgol.elf
	$(OBJCOPY) build/cgol.elf --hex -o build/cgol.hex

build:
	mkdir -p build

.PHONY: clean
clean:
	rm -rf ./build