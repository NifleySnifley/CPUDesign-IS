# rv32i Simulator

Designed to be an easy-to-use debugging tool for inspecting the execution of rv32i instructions. The simulator is a standalone C library consisting of `src/rv32i_simulator.c` and `src/rv32i_simulator.h`. Please see `Doxygen` documentation for usage of the library.

## CLI Tool

A CLI version of the rv32i simulator is provided. To build, run `make build/sim_cli`. `sim_cli` is a basic CLI interface to the simulation library. 

`sim_cli [-p pc = 0x0 ] [-m memory-size = 0x2000 ] [-o memory-dumpfile = memory.bin ] [-r register-dumpfile = registers.csv ] [-v (verbose) ] input_memory.bin`

## System Emulator

A full-system emulator with graphics support, debugging, and LED output can be found in `build/sim_emulator` (after running `make`).

Usage: `build/sim_emulator [options] program.[hex|bin|txt]`
- `-l` - opens SDL window simulating 8-bit LED bargraph
- `-v` - opens SDL window simulating text-mode graphics with 2-bit color (optional)
- `-b` - emulates the bootloader, allows bootloadable programs to be tested
- `-f [fontfile]` specify font ROM contents.

## Program Converter (`asm2bin.py`)

Although the name is deceptive, `asm2bin` is not an assembler, although it can provide such functionality. `asm2bin` is used all over this project to convert `.elf` executables and RISC-V assembly to raw binaries containing RAM initialization contents.

Usage: `asm2bin.py input.[S|s|elf]`

Options:
- `-o FILE`/`--output FILE` specify output file. If not provided, processed output will have the same name as the input with a new file extension
- `-r`/`--raw` output processed data as raw file contents (`.bin`)
- `-x`/`--hex` output processed data as ASCII text containing one 32-bit hexadecimal word per line (easily loaded in verilog with `$readmemh`)
- `-p BYTES`/`--pad BYTES` pads output data to specified number of bytes (note: when using hex output, data is automatically padded to the next multiple of 4 bytes)
- `-a`/`--assemble` treat the input file as RISC-V assembly. Input will be assembled before further processing and linked using `software/library/map.ld`.
- `-d`/`--dissasemble` Show dissasembled output during processing (uses `riscv32-unknown-elf-objdump -d`)
- `-D`/`--dataonly` exlude the `.text*` section(s) from the output binary (Harvard arch)
- `-T`/`--textonly` only output contents of the `.text*` section(s) (Harvard arch)