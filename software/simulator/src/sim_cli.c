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

static char* memory_tracefile = NULL;
static FILE* memory_tracefile_ptr = NULL;

void dump_sim() {
    if (memory_output_file != NULL) {
        printf("Dumping memory to '%s'\n", memory_output_file);
        FILE* memfile = fopen(memory_output_file, "w");
        rv_simulator_dump_memory(&sim, memfile);
        fflush(memfile);
        fclose(memfile);
    }
    if (register_dump_file != NULL) {
        printf("Dumping registers to '%s'\n", register_dump_file);
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

rv_sim_read_fn_t original_read_byte_fn;
rv_sim_write_fn_t original_write_byte_fn;

uint8_t read_byte_fn(void* arg, uint32_t addr) {
    uint8_t value = original_read_byte_fn(arg, addr);
    fprintf(memory_tracefile_ptr, "r,%x,%x\n", addr, value);
    return value;
}

void write_byte_fn(void* arg, uint32_t addr, uint8_t value) {
    original_write_byte_fn(arg, addr, value);
    fprintf(memory_tracefile_ptr, "w,%x,%x\n", addr, value);
}

int main(int argc, char** argv) {
    RV_SIM_VERBOSE = true;

    int opt;
    while ((opt = getopt(argc, argv, "p:m:o:r:vl:")) != -1) {
        switch (opt) {
            case 'p':
                // Parse PC
                pc_start = (uint32_t)atol(optarg);
                break;
            case 'm':
                memory_size = (uint32_t)atol(optarg);
                break;
            case 'l':
                memory_tracefile = optarg;
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
            default:
                fprintf(stderr, "Usage: %s [-p pc = 0x0 ] [-m memory-size = 0x2000 ] [-o memory-dumpfile = memory.bin ] [-r register-dumpfile = registers.csv ] [-v (verbose) ] [-l memory_tracefile ] input_memory.bin \n",
                    argv[0]);
                exit(EXIT_FAILURE);
        }
    }

    if (optind >= argc) {
        fprintf(stderr, "Error, input memory file is required!\n");
        exit(EXIT_FAILURE);
    }

    const char* memory_input_file = argv[optind];
    if (memory_tracefile != NULL) memory_tracefile_ptr = fopen(memory_tracefile, "w");

    signal(SIGINT, signal_handler);

    rv_simulator_init(&sim);
    rv_simulator_init_monolithic_memory(&sim, memory_size);
    if (tracing)
        sim.instr_trace = instr_trace;
    sim.x[1] = (uint32_t)-1; // Set return address for the program to a known location!
    sim.x[2] = 0x1800; // FIXME: setting stack pointer somewhere in RAM
    sim.pc = pc_start;

    if (memory_tracefile_ptr != NULL) {
        original_read_byte_fn = sim.memory_interface.read_byte_fn;
        original_write_byte_fn = sim.memory_interface.write_byte_fn;
        sim.memory_interface.read_byte_fn = read_byte_fn;
        sim.memory_interface.write_byte_fn = write_byte_fn;
        fprintf(memory_tracefile_ptr, "mode,addr,value\n");
    }

    // Read initial memory contents from binary file (from assembler/compiler converted with objdump from elf)
    int numloaded = rv_simulator_load_memory_from_file(&sim, memory_input_file, FILETYPE_AUTO, 0);

    while (1) {
        if (sim.pc == (uint32_t)-1) {
            printf("Program returned\n");
            break;
        }

        int ret = rv_simulator_step(&sim);

        if (ret > 0) {
            printf("Error!\n");
            break;
        } else if (ret < 0) {
            printf("Breakpoint @ PC=%x\n", sim.pc);

            printf("Press 'c' key to continue, 'r' to print registers, 'm' to print memory, 'd' to dump, ctrl-C to exit.\n");
            while (1) {
                char c = getchar();
                if (c == 'c') { break; }
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
            }
        }
    }

    if (memory_tracefile_ptr != NULL) fclose(memory_tracefile_ptr);

    dump_sim();

    return 0;
}