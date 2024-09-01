.PHONY: test_main.bin test_main.elf

test_main.bin: test_main.elf
	riscv64-unknown-elf-objcopy -O binary -g  test_main.elf test_main.bin

test_main.elf: test_main.c
	riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 \
	-nostdlib -ffreestanding -Tmemory_map.ld \
	-o test_main.elf test_main.c

test_main_debug.elf: test_main.c
	riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 \
	-nostdlib -ffreestanding -Tmemory_map.ld -g \
	-o test_main_debug.elf test_main.c

dissasemble: test_main_debug.elf test_main.bin
	riscv64-unknown-elf-objdump -d -C -S -M no-aliases --disassembler-color=extended --visualize-jumps=extended-color test_main_debug.elf