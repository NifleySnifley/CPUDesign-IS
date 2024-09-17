#include <stdlib.h>
#include <iostream>
#include <memory.h>
#include <stdio.h> 
#include <string.h>
#include <cstring>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include <getopt.h>
#include "obj_dir/Vsoc_sim.h"
#include "obj_dir/Vsoc_sim___024unit.h"
#include "obj_dir/Vsoc_sim___024root.h"

extern "C" {
#include "../../../software/simulator/src/rv32i_simulator.h"
}

#define MAX_SIM_TIME 500
#define EXIT_ERROR 1
#define EXIT_FAIL 2
#define RESET_TIME 11
#define OPTS "t:vqdnl:r:eb:i"
vluint64_t sim_time = 0;

vluint64_t instructions_executed;
vlsint64_t insn_limit = 0;
bool quiet;
bool verbose;
bool dump;
bool no_exit_on_fail;
bool independent;

// TODO: b+args
bool exit_on_bkpt;
bool regdump_on_bkpt;
bool memdump_on_bkpt;
bool wait_on_bkpt;

const char* tracefile = nullptr;
const char* memfile = nullptr;

int simulator_read_word(rv_simulator_t* sim, uint32_t i) {
    return sim->memory[i + 0] | (sim->memory[i + 1] << 8) | (sim->memory[i + 2] << 16) | (sim->memory[i + 3] << 24);
}

bool simulator_equals_dut(Vsoc_sim* dut, rv_simulator_t* sim) {
    if (sim->pc != dut->rootp->soc_sim__DOT__core0__DOT__pc) {
        printf("Program counter mismatch sim=%u, dut=%u\n", sim->pc, dut->rootp->soc_sim__DOT__core0__DOT__pc);
        return false;
    };
    for (int r = 0; r < 32; ++r) {
        if (sim->x[r] != dut->rootp->soc_sim__DOT__core0__DOT__registers[r]) {
            printf("Mismatch of register %d: sim=%u, dut=%u\n", r, sim->x[r], (uint32_t)dut->rootp->soc_sim__DOT__core0__DOT__registers[r]);
            return false;
        }
    }

    // for (int wa = 0; wa < sim->mem_size / 4; ++wa) {
    //     if (simulator_read_word(sim, wa * 4) != dut->rootp->soc_sim__DOT__mem__DOT__memory[wa]) {
    //         printf("Mismatch of memory word @ %x: sim=%u, dut=%u\n", wa * 4, simulator_read_word(sim, wa * 4), dut->rootp->soc_sim__DOT__mem__DOT__memory[wa]);
    //         return false;
    //     }
    // }

    return true;
}

void sim_tracefn(void* sim, const char* insname) {
    if (verbose) printf("SIMULATOR:INSN: %s\n", insname);
}

void dut_pprint_memory(Vsoc_sim* dut) {
    int num_words = (sizeof(dut->rootp->soc_sim__DOT__mem__DOT__memory) / 32);
    uint32_t* membuffer = (uint32_t*)calloc(num_words, 4);
    for (int wi = 0; wi < num_words; ++wi)
        membuffer[wi] = (uint32_t)dut->rootp->soc_sim__DOT__mem__DOT__memory[wi];

    FILE* hd_proc = popen("hd", "w");
    fwrite(membuffer, 4, num_words, hd_proc);
    fflush(hd_proc);
    int status = pclose(hd_proc);
}

void dut_pprint_registers(Vsoc_sim* dut) {
    printf("Registers:\n");
    for (int r = 0; r < 32; ++r) {
        printf("\t\x1b[31mx%d\x1b[0m/%s = \x1b[32m%d\x1b[0m (0x%x)\n", r, REG_ABI_NAMES[r], (int32_t)dut->rootp->soc_sim__DOT__core0__DOT__registers[r], dut->rootp->soc_sim__DOT__core0__DOT__registers[r]);
    }
}

void regset(Vsoc_sim* dut, rv_simulator_t* sim, int reg, uint32_t value) {
    sim->x[reg] = value;
    dut->rootp->soc_sim__DOT__core0__DOT__registers[reg] = value;
}

int main(int argc, char** argv, char** env) {
    int excode = EXIT_SUCCESS;

    int opt;
    while ((opt = getopt(argc, argv, OPTS)) != -1) {
        switch (opt) {
            case 't':
                tracefile = optarg;
                break;
            case 'v':
                verbose = true;
                break;
            case 'q':
                quiet = true;
                break;
            case 'd':
                dump = true;
                break;
            case 'i':
                independent = true;
                break;
            case 'b':
            {
                int len = strlen(optarg);
                if (len == 0) {
                    printf("Error, at least one breakpoint action specifier is required");
                    exit(EXIT_ERROR);
                }
                for (int i = 0; i < len; ++i) {
                    char c = optarg[i];
                    exit_on_bkpt |= c == 'e';
                    regdump_on_bkpt |= c == 'r';
                    memdump_on_bkpt |= c == 'm';
                    wait_on_bkpt |= c == 'w';
                }
            }
            break;
            case 'n':
                no_exit_on_fail = true;
                break;
            case 'l':
                insn_limit = atol(optarg);
                break;
            case 'r':
            case 'e':
                break; // Post-initialization
            default:
                fprintf(stderr, "Usage: %s [-p pc = 0x0 ] [-m memory-size = 0x2000 ] [-o memory-dumpfile = memory.bin ] [-r register-dumpfile = registers.csv ] [-v (verbose) ] input_memory.bin \n",
                    argv[0]);
                exit(EXIT_ERROR);
        }
    }

    if (optind >= argc) {
        fprintf(stderr, "Error, input memory file is required!\n");
        exit(EXIT_ERROR);
    }

    memfile = argv[optind];

    Vsoc_sim* dut = new Vsoc_sim;
    if (tracefile != nullptr) Verilated::traceEverOn(true);

    VerilatedVcdC* m_trace = new VerilatedVcdC;
    if (tracefile != nullptr) {
        dut->trace(m_trace, 5);
        m_trace->open(tracefile);
    }

    rv_simulator_t simulator;
    constexpr uint32_t memsize_words = (sizeof(dut->rootp->soc_sim__DOT__mem__DOT__memory.m_storage)) / 4;

    rv_simulator_init(&simulator, memsize_words * 4);
    // simulator.instr_trace = sim_tracefn;
    // TODO: Ceiling divide here!
    int binsize_words = rv_simulator_load_memory_from_file(&simulator, memfile) / 4;
    if (verbose) printf("Loading binary, size = %d words\n", binsize_words);
    if (binsize_words < 0) {
        printf("Error opening memory file!\n");
        exit(EXIT_ERROR);
    }

    // Copy initialization memory from sim to DUT
    for (int i = 0; i < memsize_words; ++i) {
        uint32_t word = (i < binsize_words) ? simulator_read_word(&simulator, i * 4) : 0;
        dut->rootp->soc_sim__DOT__mem__DOT__memory[i] = word;
    }

    // printf("SIM memory initial:\n");
    // rv_simulator_pprint_memory(&simulator);

    // Reset DUT
    while (sim_time < RESET_TIME) {
        dut->rst = 1;
        dut->clk ^= 1;
        dut->eval();
        if (tracefile != nullptr)m_trace->dump(sim_time);
        sim_time++;
    }
    dut->rst = 0;

    // Post-initialization setup
    opt = 0; optind = 0;
    while ((opt = getopt(argc, argv, OPTS)) != -1) {
        switch (opt) {
            case 'r':
                // Set register
                uint32_t regid;
                uint32_t regvalue;
                sscanf(optarg, "%d=%d", &regid, &regvalue);
                if (regid == 0 || regid >= 32) {
                    printf("Error, invalid register index %d.", regid);
                    exit(EXIT_ERROR);
                }
                regset(dut, &simulator, regid, regvalue);
                break;
            case 'e':
                // Setup standard execution environment
                regset(dut, &simulator, 1, (uint32_t)-1);
                regset(dut, &simulator, 2, 0x1800);
                break;
            default:
                break; // Gonna be others so don't worry about it
        }
    }

    // Run DUT
    bool fail = false;
    vluint64_t run_start = sim_time;
    uint32_t dut_prevpc = dut->rootp->soc_sim__DOT__core0__DOT__pc;

    while (true) {
        dut->clk = 0;
        dut->eval();
        if (tracefile != nullptr)m_trace->dump(sim_time);
        sim_time++;
        dut->clk = 1;
        dut->eval();
        if (tracefile != nullptr)m_trace->dump(sim_time);
        sim_time++;

        vluint64_t cycles = (sim_time - run_start) / 2;

        if (dut->rootp->instruction_sync) {
            instructions_executed += 1;

            // Step the simulator ahead but save PC of currently executing instruction
            uint32_t sim_prevpc = simulator.pc;
            bool bkpt = rv_simulator_step(&simulator);

            if (verbose) printf("Instruction completed @ cycle %ld (pc=%u, sim_pc=%u)\n", cycles, dut_prevpc, sim_prevpc);
            // Now, both should be in sync!

            if (bkpt) {
                if (!quiet) printf("Simulator breakpoint @ pc=%d - %s\n", simulator.pc, exit_on_bkpt ? "exiting" : "continuing");
                if (wait_on_bkpt) {
                    printf("Press enter to continue");
                    getchar();
                }
                if (memdump_on_bkpt)
                    rv_simulator_pprint_memory(&simulator);
                if (regdump_on_bkpt)
                    rv_simulator_pprint_registers(&simulator);
                if (exit_on_bkpt) break;
            };

            bool equals = simulator_equals_dut(dut, &simulator) | independent;
            if (!equals) {
                // if (!quiet) {
                // printf("ERROR: Simulator does not match DUT!\n");
                printf("Instruction failed (pc=%u): %x\n", dut_prevpc, dut->rootp->soc_sim__DOT__mem__DOT__memory[dut_prevpc / 4]);
                // }
                fail = true;
                if (!no_exit_on_fail) break;
            }

            if ((insn_limit > 0) && instructions_executed >= insn_limit) {
                if (!quiet) printf("Reached instruction limit, finishing.\n");
                break;
            }
            dut_prevpc = dut->rootp->soc_sim__DOT__core0__DOT__pc;
        }
    }

    const char* resultstr = fail ? "\x1b[31mxFAIL\x1b[0m/" : "\x1b[32mSUCCESS\x1b[0m";
    if (!quiet) printf("\n================================ %s ================================\n\n", resultstr);

    if (dump) {
        printf("SIM registers:\n");
        rv_simulator_pprint_registers(&simulator);
        printf("SIM memory:\n");
        rv_simulator_pprint_memory(&simulator);

        printf("\n\n");

        printf("DUT registers:\n");
        dut_pprint_registers(dut);
        printf("DUT memory:\n");
        dut_pprint_memory(dut);
    }

    if (tracefile != nullptr)m_trace->close();
    delete dut;
    exit(fail ? EXIT_FAIL : EXIT_SUCCESS);
}