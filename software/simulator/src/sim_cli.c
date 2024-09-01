#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <signal.h>
#include <getopt.h>

#define INST_TRACE
#include "rv32i_simulator.h"

static rv_simulator_t sim;
// static char* memory_input_file = "program.bin";
static char* memory_output_file = NULL;
static char* register_dump_file = NULL;
uint32_t pc_start = 0;
uint32_t memory_size = 0x2000;
bool tracing = false;

void dump_sim() {
    if (memory_output_file != NULL) {
        FILE* memfile = fopen(memory_output_file, "w");
        rv_simulator_dump_memory(&sim, memfile);
        fflush(memfile);
        fclose(memfile);
    }
    if (register_dump_file != NULL) {
        FILE* regfile = fopen(register_dump_file, "w");
        rv_simulator_dump_regs(&sim, regfile);
        fflush(regfile);
        fclose(regfile);
    }
}

void signal_handler(int signum) {
    printf("\nReceived SIGINT, dumping memory and registers.\n");
    dump_sim();
    exit(0);
}

void instr_trace(void* _sim, const char* inst_str) {
    rv_simulator_t* simptr = _sim;
    printf("%s @ %x\n", inst_str, simptr->pc);
}

int main(int argc, char** argv) {
    // TODO: Add a proper CLI for specifying memory size, etc.
    // if (argc < 2) {
    //     fprintf(stderr, "Error, binary memory file must be specified");
    //     return 1;
    // }

    // TODO: Add more opts for verbosity, tracing, logging, etc.
    int opt;
    while ((opt = getopt(argc, argv, "p:m:o:r:v")) != -1) {
        switch (opt) {
            case 'p':
                // Parse PC
                pc_start = (uint32_t)atol(optarg);
                break;
            case 'm':
                memory_size = (uint32_t)atol(optarg);
                break;
            case 'o':
                memory_output_file = optarg;
                break;
            case 'r':
                register_dump_file = optarg;
                break;
            case 'v':
                tracing = true;
                break;
            default: /* '?' */
                fprintf(stderr, "Usage: %s [-p pc = 0x0 ] [-m memory-size = 0x2000 ] [-o memory-dumpfile = memory.bin ] [-r register-dumpfile = registers.csv ] input_memory.bin \n",
                    argv[0]);
                exit(EXIT_FAILURE);
        }
    }

    if (optind >= argc) {
        fprintf(stderr, "Error, input memory file is required!\n");
        exit(EXIT_FAILURE);
    }

    const char* memory_input_file = argv[optind];

    signal(SIGINT, signal_handler);

    rv_simulator_init(&sim, memory_size);
    if (tracing)
        sim.instr_trace = instr_trace;
    sim.x[2] = 0x1800; // FIXME: setting stack pointer somewhere in RAM
    sim.pc = pc_start;


    // Read initial memory contents from binary file (from assembler/compiler converted with objdump from elf)
    FILE* binfile = fopen(memory_input_file, "r+");
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
            break;
        } else if (ret < 0) {
            printf("Breakpoint @ PC=%x press 'c' key to continue, 'r' to print registers, 'm' to print memory, 'd' to dump, ctrl-C to exit.\n", sim.pc);
            char c = getchar();
            while (c != 'c') {
                switch (c) {
                    case 'm':
                        rv_simulator_pprint_memory(&sim);
                        break;
                    case 'r':
                        rv_simulator_pprint_registers(&sim);
                        break;
                    case 'd':
                        dump_sim();
                        break;
                    default:
                        break;
                }
                c = getchar();
            }

        }
    }

    dump_sim();

    return 0;
}