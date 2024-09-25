FONTFILE=../../rtl/graphics/spleen-8x16.bdf
FONTCONVERTER=python3 ../../rtl/graphics/font_packer.py

.PHONY: test

run: build/sim_cli
	build/sim_cli -o memory.bin -r registers.csv ../programs/test_baremetal/test_main.bin

build/sim_emulator: build src/sim_emulator.c build/rv32i_simulator.o build/font.bin
	gcc -O5 -Isrc src/sim_emulator.c build/rv32i_simulator.o -lSDL2 -o build/sim_emulator
#	gcc -O5 build/sim_cli.o build/rv32i_simulator.o -o ./build/sim_cli

build/font.bin: build 
#	$(FONTCONVERTER) -f raw $(FONTFILE) build/font.bin
	echo "eee"

build/sim_cli: build build/sim_cli.o build/rv32i_simulator.o
	gcc -O5 build/sim_cli.o build/rv32i_simulator.o -o ./build/sim_cli

build/sim_cli.o: build src/sim_cli.c
	gcc -O5 -Isrc -c src/sim_cli.c -o build/sim_cli.o

build/rv32i_simulator.o: build src/rv32i_simulator.c src/rv32i_simulator.h
	gcc -O5 -Isrc -c src/rv32i_simulator.c -o build/rv32i_simulator.o

test: build/rv32i_simulator.o
	$(MAKE) -C test

build:
	mkdir -p build

clean:
	rm -rf ./build
	$(MAKE) -C test clean