.PHONY: test_main.bin test_main.elf

COMPILE_COMMAND:=riscv32-unknown-elf-gcc -march=rv32i -mabi=ilp32 \
	-nostdlib -ffreestanding -Tmemory_map.ld

test_main.bin: test_main.elf
	riscv32-unknown-elf-objcopy -O binary -g  test_main.elf test_main.bin

test_main.elf: test_main.c
	$(COMPILE_COMMAND) -o test_main.elf test_main.c

test_main_debug.elf: test_main.c
	$(COMPILE_COMMAND) -g -o test_main_debug.elf test_main.c


dissasemble: test_main_debug.elf test_main.bin
	riscv32-unknown-elf-objdump -d -C -S -M no-aliases --disassembler-color=extended --visualize-jumps=extended-color test_main_debug.elf