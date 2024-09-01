run: build/sim_cli
	build/sim_cli ../programs/test_main.bin

build/sim_cli: build build/sim_cli.o build/rv32i_simulator.o
	gcc build/sim_cli.o build/rv32i_simulator.o -o ./build/sim_cli

build/sim_cli.o: build src/sim_cli.c
	gcc -Isrc -c src/sim_cli.c -o build/sim_cli.o

build/rv32i_simulator.o: build src/rv32i_simulator.c src/rv32i_simulator.h
	gcc -Isrc -c src/rv32i_simulator.c -o build/rv32i_simulator.o

build:
	mkdir -p build