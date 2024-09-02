.PHONY: build/main.elf

DIS_CMD:=riscv64-unknown-elf-objdump -d -C -S --disassembler-color=extended --visualize-jumps=extended-color
CC_CMD:=riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32

dissasemble: build/main.elf
	$(DIS_CMD) build/main.elf

build/main.elf: build main.c
	$(CC_CMD) main.c -o build/main.elf

build: 
	mkdir -p build