# rv32i Simulator

Designed to be an easy-to-use debugging tool for inspecting the execution of rv32i instructions. The simulator is a standalone C library consisting of `src/rv32i_simulator.c` and `src/rv32i_simulator.h`. Please see `Doxygen` documentation for usage of the library.

## CLI tool

A CLI version of the rv32i simulator is provided. To build, run `make build/sim_cli`. `sim_cli` is a basic CLI interface to the simulation library. 

`sim_cli [-p pc = 0x0 ] [-m memory-size = 0x2000 ] [-o memory-dumpfile = memory.bin ] [-r register-dumpfile = registers.csv ] [-v (verbose) ] input_memory.bin`