#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <signal.h>

#define INST_TRACE
#include "rv32i_simulator.h"

static rv_simulator_t sim;

int signal_handler(int signum) {
    printf("\nReceived SIGINT, dumping memory and registers.\n");
    rv_simulator_dump_memory(&sim, "memory.bin");
    rv_simulator_dump_regs(&sim, "registers.csv");
    exit(0);
}

int main(int argc, char** argv) {
    // TODO: Add a proper CLI for specifying memory size, etc.
    if (argc < 2) {
        fprintf(stderr, "Error, binary memory file must be specified");
        return 1;
    }

    signal(SIGINT, signal_handler);

    char* memory_file = argv[1];

    rv_simulator_init(&sim, 0x2000);
    sim.x[2] = 0x1800; // FIXME: setting stack pointer somewhere in RAM


    // Read initial memory contents from binary file (from assembler/compiler converted with objdump from elf)
    FILE* binfile = fopen(memory_file, "r+");
    if (binfile == NULL) {
        fprintf(stderr, "Error opening file\n");
        return 2;
    }

    fseek(binfile, 0, SEEK_END);
    int binsize = ftell(binfile);
    rewind(binfile);

    if (binsize > sim.mem_size) {
        fprintf(stderr, "Error, binary file is larger than simulator memory size!\n");
        return 3;
    }

    int idx = 0;
    do {
        int n = fread(&sim.memory[idx], 1, binsize - idx, binfile);
        if (n == -1) {
            fprintf(stderr, "Error reading file!\n");
            return 4;
        }
        idx += n;
    } while (idx != binsize);
    fclose(binfile);


    while (1) {
        int ret = rv_simulator_step(&sim);

        if (ret > 0) {
            printf("Error!\n");
            // rv_simulator_print_regs(&sim);
            break;
        } else if (ret < 0) {
            // rv_simulator_print_regs(&sim);
            printf("Breakpoint! press any key to continue\n");
            getchar();
        }
    }

    rv_simulator_dump_memory(&sim, "memory.bin");
    rv_simulator_dump_regs(&sim, "registers.csv");

    return 0;
}