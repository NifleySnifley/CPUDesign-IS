OBJCOPY=../../simulator/asm2bin.py
LIBDIR=../../library
SIMULATOR=../../simulator/build/sim_emulator
LIB_SOURCES=$(LIBDIR)/crt0.S $(LIBDIR)/soc_core.c $(LIBDIR)/soc_io.c
COMPILE=riscv32-unknown-elf-gcc -I$(LIBDIR) -g -march=rv32im -mabi=ilp32  -Wall -nostartfiles  -ffunction-sections -fdata-sections -mstrict-align -Wl,--gc-sections -ffp-contract=off 
COMPILE_FULL=$(COMPILE) -lm -lc -lgcc $(LIB_SOURCES)

# .PHONY: all
all: build/test_bootloaded.hex build/bootloader.hex build/bootloader_v2.hex build/cgol_image.bin build/test_color_image.bin

# .PHONY: sim
# sim: build/icefun_main.hex
# 	$(SIMULATOR) -l build/icefun_main.hex

build/test_bootloaded.hex: build test_bootloaded.c
	$(COMPILE_FULL) -Os  -T$(LIBDIR)/map_bootloaded.ld test_bootloaded.c -o build/test_bootloaded.elf
	$(OBJCOPY) build/test_bootloaded.elf --hex -o build/test_bootloaded.hex

build/cgol_color.hex: build cgol_color.c
	$(COMPILE_FULL) -O5 -DCOLOR_SUPPORTED=1 -T$(LIBDIR)/map_bootloaded.ld cgol_color.c -o build/cgol_color.elf
	$(OBJCOPY) build/cgol_color.elf --hex -o build/cgol_color.hex

build/test_color.hex: ./test_color.c build
	$(COMPILE_FULL) -O5 -T$(LIBDIR)/map_bootloaded.ld $< -o build/.tmp.elf
	$(OBJCOPY) build/.tmp.elf --hex -o $@

build/bootloader.hex: build bootloader.S
	$(COMPILE) bootloader.S -o build/bootloader.elf
	riscv32-unknown-elf-size build/bootloader.elf
	$(OBJCOPY) build/bootloader.elf --hex -o build/bootloader.hex

build/bootloader_v2.hex: build bootloader_v2.c
	$(COMPILE) -nostdlib -Os -T$(LIBDIR)/map_minimal.ld $(LIBDIR)/crt0_minimal.S $(LIBDIR)/soc_core.c $(LIBDIR)/soc_io.c bootloader_v2.c -o build/bootloader_v2.elf
	riscv32-unknown-elf-size build/bootloader_v2.elf
	$(OBJCOPY) build/bootloader_v2.elf --hex -o build/bootloader_v2.hex

build/cgol_image.bin: build/cgol_color.hex
	python3 ./create_flash_image.py $< $@

build/test_color_image.bin: build/test_color.hex
	python3 ./create_flash_image.py $< $@

build:
	mkdir -p build

.PHONY: clean
clean:
	rm -rf ./build