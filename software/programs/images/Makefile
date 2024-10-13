OBJCOPY=../../simulator/asm2bin.py
FLASH_IMAGE_TOOL=../bootloader/create_flash_image.py
LIBDIR=../../library
LIB_SOURCES=$(LIBDIR)/crt0.S $(LIBDIR)/soc_core.c $(LIBDIR)/soc_io.c
COMPILE=riscv32-unknown-elf-gcc -I$(LIBDIR) -DF_CPU=25100000 -g -march=rv32im -mabi=ilp32  -Wall -nostartfiles  -ffunction-sections -fdata-sections -mstrict-align -Wl,--gc-sections -ffp-contract=off 
LINK_ARGS=-lm -lc -lgcc -T$(LIBDIR)/map_bootloaded.ld
COMPILE_FULL=$(COMPILE) $(LINK_ARGS) $(LIB_SOURCES)


build/image_show_image.bin: build/image_show.hex
	python3 $(FLASH_IMAGE_TOOL) $< $@

build/image_show.hex: build build/image_show.elf
	$(OBJCOPY) build/image_show.elf --hex -o $@

build/image_show.elf: image_show.c
	$(COMPILE_FULL) -O5 -I./build $< -o $@

size: build/image_show.elf
	riscv32-unknown-elf-size $<
	
build:
	mkdir -p build

.PHONY: clean
clean:
	rm -rf ./build