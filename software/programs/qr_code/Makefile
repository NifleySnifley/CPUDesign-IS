OBJCOPY=../../simulator/asm2bin.py
LIBDIR=../../library
QRDIR=./lib
LIB_SOURCES=$(LIBDIR)/crt0.S $(LIBDIR)/soc_core.c $(LIBDIR)/soc_io.c
COMPILE=riscv32-unknown-elf-gcc -I$(LIBDIR) -I$(QRDIR) -g -march=rv32im -mabi=ilp32  -Wall -nostartfiles  -ffunction-sections -fdata-sections -mstrict-align -Wl,--gc-sections -ffp-contract=off 
LINK_ARGS=-lm -lc -lgcc -T$(LIBDIR)/map_bootloaded.ld
COMPILE_FULL=$(COMPILE) $(LINK_ARGS) $(LIB_SOURCES)

build/qr.hex: build/qr.elf
	$(OBJCOPY) $^ --hex -o $@

build/qr.elf: build/qrcodegen.o build/main.o
	$(COMPILE_FULL) -Os $^ -o $@

size: build/qr.elf
	riscv32-unknown-elf-size $<

build/qrcodegen.o: ./lib/qrcodegen.c build
	$(COMPILE) -O5 -c $(LINK_ARGS) $< -o $@

build/main.o: main.c build
	$(COMPILE) -O5 -c $(LINK_ARGS) $< -o $@

build:
	mkdir -p build

.PHONY: clean
clean:
	rm -rf ./build