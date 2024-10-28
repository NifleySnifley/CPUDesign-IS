OBJCOPY=../../simulator/asm2bin.py
LIBDIR=../../library
SIMULATOR=../../simulator/build/sim_emulator
LIB_SOURCES=$(LIBDIR)/crt0.S $(LIBDIR)/soc_core.c $(LIBDIR)/soc_io.c
COMPILE=riscv32-unknown-elf-gcc -I$(LIBDIR) -g -march=rv32im -mabi=ilp32  -Wall -nostartfiles  -ffunction-sections -fdata-sections -mstrict-align -Wl,--gc-sections -ffp-contract=off -lm -lc -lgcc $(LIB_SOURCES)

#
.PHONY: all
all: build/icefun_main.hex build/upduino_main.hex build/graphics_test.hex build/dhrystones.hex build/pipelined_dhrystones.hex build/cgol.hex build/flash_test.hex build/ecp5_test.hex

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
	
.PHONY: build/ecp5_test.hex
build/ecp5_test.hex: ecp5_test.c build
	$(COMPILE) -Os -DF_CPU=50000000 -DCPU_PIPELINED -T$(LIBDIR)/map_ecp5.ld ecp5_test.c -o build/ecp5_test.elf
	$(OBJCOPY) build/ecp5_test.elf --hex -o build/ecp5_test.hex

.PHONY: build/cgol.hex
build/cgol.hex: cgol.c build
	$(COMPILE) -O5 -T$(LIBDIR)/map_spram.ld cgol.c -o build/cgol.elf
	$(OBJCOPY) build/cgol.elf --hex -o build/cgol.hex

.PHONY: build/flash_test.hex
build/flash_test.hex: flash_test.c build
	$(COMPILE) -T$(LIBDIR)/map_spram.ld flash_test.c -o build/flash_test.elf
	$(OBJCOPY) build/flash_test.elf --hex -o build/flash_test.hex

.PHONY: build/pipelined_dhrystones.hex
build/pipelined_dhrystones.hex: pipelined_dhrystones.c build
	$(COMPILE) -O5 -T$(LIBDIR)/map_ecp5.ld pipelined_dhrystones.c -o build/pipelined_dhrystones.elf
	$(OBJCOPY) build/pipelined_dhrystones.elf --hex -o build/pipelined_dhrystones.hex
# 	$(OBJCOPY) -D build/pipelined_dhrystones.elf --hex -o build/pipelined_dhrystones_ram.hex

.PHONY: build/dhrystones.hex
build/dhrystones.hex: pipelined_dhrystones.c build
	$(COMPILE) -O5 -T$(LIBDIR)/map_spram.ld pipelined_dhrystones.c -o build/dhrystones.elf
	$(OBJCOPY) build/dhrystones.elf --hex -o build/dhrystones.hex
# 	$(OBJCOPY) -D build/pipelined_dhrystones.elf --hex -o build/pipelined_dhrystones_ram.hex

build:
	mkdir -p build

.PHONY: clean
clean:
	rm -rf ./build