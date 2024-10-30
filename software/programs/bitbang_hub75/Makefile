OBJCOPY=../../simulator/asm2bin.py
LIBDIR=../../library
SIMULATOR=../../simulator/build/sim_emulator
LIB_SOURCES=$(LIBDIR)/crt0.S $(LIBDIR)/soc_core.c $(LIBDIR)/soc_io.c
COMPILE=riscv32-unknown-elf-gcc -I$(LIBDIR) -g -march=rv32im -mabi=ilp32  -Wall -nostartfiles  -ffunction-sections -fdata-sections -mstrict-align -Wl,--gc-sections -ffp-contract=off -lm -lc -lgcc $(LIB_SOURCES)
PROGRAMMER=../../../rtl/soc_ecp5/ecp5progtool.py

.PHONY:
flash: build/hub75.hex
	$(PROGRAMMER) build/hub75.hex

build/hub75.hex: build/hub75.elf build
	$(OBJCOPY) build/hub75.elf --hex -o build/hub75.hex

build/hub75.elf: main.c build
	$(COMPILE) -DF_CPU=50000000 -DCPU_PIPELINED -T$(LIBDIR)/map_ecp5.ld main.c -o build/hub75.elf

build:
	mkdir -p build

.PHONY: clean
clean:
	rm -rf ./build