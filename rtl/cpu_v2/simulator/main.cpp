#include <stdlib.h>
#include <iostream>
#include <memory.h>
#include <stdio.h> 
#include <string.h>
#include <cstring>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include <getopt.h>
#include "obj_dir/Vcpu_pl_soc.h"
#include "obj_dir/Vcpu_pl_soc___024unit.h"
#include "obj_dir/Vcpu_pl_soc___024root.h"
#include <chrono>

extern "C" {
#include "../../../software/simulator/src/rv32i_simulator.h"
}

#define MAX_SIM_TIME 500
#define EXIT_ERROR 1
#define EXIT_FAIL 2
#define RESET_TIME 11
#define OPTS "t:vqdnl:r:eb:ism"
vluint64_t sim_time = 0;

vluint64_t instructions_executed;
vlsint64_t insn_limit = 0;
bool quiet;
bool verbose;
bool dump;
bool stats;
bool no_exit_on_fail;
bool independent;
bool spram = true;

// TODO: b+args
bool exit_on_bkpt;
bool regdump_on_bkpt;
bool memdump_on_bkpt;
bool wait_on_bkpt;

const char* tracefile = nullptr;
const char* memfile = nullptr;

int simulator_read_word(rv_simulator_t* sim, uint32_t i) {
    return rv_simulator_read_byte(sim, i + 0) | \
        (rv_simulator_read_byte(sim, i + 1) << 8) | \
        (rv_simulator_read_byte(sim, i + 2) << 16) | \
        (rv_simulator_read_byte(sim, i + 3) << 24);
}

bool simulator_equals_dut(Vcpu_pl_soc* dut, rv_simulator_t* sim) {
    if (sim->pc != dut->rootp->cpu_pl_soc__DOT__core0__DOT__WB_pc) {
        printf("Program counter mismatch sim=%u, dut=%u\n", sim->pc, dut->rootp->cpu_pl_soc__DOT__core0__DOT__WB_pc);
        return false;
    };
    for (int r = 0; r < 32; ++r) {
        if (sim->x[r] != dut->rootp->cpu_pl_soc__DOT__core0__DOT__registers[r]) {
            printf("Mismatch of register %d: sim=%u/%d(s), dut=%u/%d(s)\n", r, sim->x[r], sim->x[r], (uint32_t)dut->rootp->cpu_pl_soc__DOT__core0__DOT__registers[r], (int32_t)dut->rootp->cpu_pl_soc__DOT__core0__DOT__registers[r]);
            return false;
        }
    }

    // TODO: Move to segmented memory model
    // rv_simulator_segmented_memory_segment_t* main_memory = rv_simulator_segmented_memory_get_segment((rv_simulator_segmented_memory_t*)sim->memory_interface.memory, 0);

    // for (int wa = 0; wa < main_memory->size / 4; ++wa) {
    //     if (simulator_read_word(sim, wa * 4 + main_memory->start_address) != dut->rootp->cpu_pl_soc__DOT__spram__DOT__memory[wa]) {
    //         printf("Mismatch of Main Memory word @ %x: sim=%u, dut=%u\n", wa * 4, simulator_read_word(sim, wa * 4 + main_memory->start_address), dut->rootp->soc_sim__DOT__mem__DOT__memory[wa]);
    //         return false;
    //     }
    // }

    // if (spram) {
    //     rv_simulator_segmented_memory_segment_t* spram = rv_simulator_segmented_memory_get_segment((rv_simulator_segmented_memory_t*)sim->memory_interface.memory, 1);
    //     for (int wa = 0; wa < spram->size / 4; ++wa) {
    //         uint32_t spramword = simulator_read_word(sim, wa * 4 + spram->start_address);
    //         if (spramword != dut->rootp->cpu_pl_soc__DOT__spram__DOT__memory[wa]) {
    //             printf("Mismatch of SPRAM word @ %x: sim=%u, dut=%u\n", wa * 4, spramword, dut->rootp->cpu_pl_soc__DOT__spram__DOT__memory[wa]);
    //             return false;
    //         }
    //     }
    // }

    return true;
}

// TODO: Register and instruction type heatmaps for stats
void sim_tracefn(void* sim, const char* insname) {
    if (verbose) printf("SIMULATOR:INSN: %s\n", insname);
}

void dut_pprint_memory(Vcpu_pl_soc* dut) {
    int num_words = (sizeof(dut->rootp->cpu_pl_soc__DOT__spram__DOT__memory) / 32);
    uint32_t* membuffer = (uint32_t*)calloc(num_words, 4);
    for (int wi = 0; wi < num_words; ++wi)
        membuffer[wi] = (uint32_t)dut->rootp->cpu_pl_soc__DOT__spram__DOT__memory[wi];

    FILE* hd_proc = popen("hd", "w");
    fwrite(membuffer, 4, num_words, hd_proc);
    fflush(hd_proc);
    int status = pclose(hd_proc);
}

void dut_pprint_registers(Vcpu_pl_soc* dut) {
    printf("Registers:\n");
    for (int r = 0; r < 32; ++r) {
        printf("\t\x1b[31mx%d\x1b[0m/%s = \x1b[32m%d\x1b[0m (0x%x)\n", r, REG_ABI_NAMES[r], (int32_t)dut->rootp->cpu_pl_soc__DOT__core0__DOT__registers[r], dut->rootp->cpu_pl_soc__DOT__core0__DOT__registers[r]);
    }
}

void regset(Vcpu_pl_soc* dut, rv_simulator_t* sim, int reg, uint32_t value) {
    sim->x[reg] = value;
    dut->rootp->cpu_pl_soc__DOT__core0__DOT__registers[reg] = value;
}

int main(int argc, char** argv, char** env) {
    int excode = EXIT_SUCCESS;

    int opt;
    while ((opt = getopt(argc, argv, OPTS)) != -1) {
        switch (opt) {
            case 't':
                tracefile = optarg;
                break;
            case 'm':
                spram = true;
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
            case 's':
                stats = true;
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

    Vcpu_pl_soc* dut = new Vcpu_pl_soc;
    if (tracefile != nullptr) Verilated::traceEverOn(true);

    VerilatedVcdC* m_trace = new VerilatedVcdC;
    if (tracefile != nullptr) {
        dut->trace(m_trace, 5);
        m_trace->open(tracefile);
    }

    rv_simulator_t simulator;
    constexpr uint32_t memsize_words = (sizeof(dut->rootp->cpu_pl_soc__DOT__core0__DOT__progMEM.m_storage)) / 4;

    constexpr uint32_t spram_baseaddr = 0x00000000;
    constexpr uint32_t spram_words = 32768;

    rv_simulator_init(&simulator);
    rv_simulator_segmented_memory_t* sim_mem = rv_simulator_init_segmented_memory(&simulator);
    // rv_simulator_segmented_memory_add_segment(sim_mem, 0, memsize_words * 4, "progROM", false);
    if (spram) rv_simulator_segmented_memory_add_segment(sim_mem, spram_baseaddr, spram_words * 4, "SPRAM", false);

    // simulator.instr_trace = sim_tracefn;
    // TODO: Ceiling divide here!
    int binsize_words = rv_simulator_load_memory_from_file(&simulator, memfile, FILETYPE_AUTO, 0) / 4;
    if (verbose) printf("Loading binary, size = %d words\n", binsize_words);
    if (binsize_words < 0) {
        printf("Error opening memory file!\n");
        exit(EXIT_ERROR);
    }

    // Copy initialization memory from sim to DUT
    for (int i = 0; i < memsize_words; ++i) {
        uint32_t word = simulator_read_word(&simulator, i * 4);
        dut->rootp->cpu_pl_soc__DOT__core0__DOT__progMEM[i] = word;
        dut->rootp->cpu_pl_soc__DOT__spram__DOT__memory[i] = word;
    }

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
    std::chrono::time_point start_time = std::chrono::high_resolution_clock::now();
    uint32_t dut_prevpc = 0;

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

        if (dut->rootp->cpu_pl_soc__DOT__core0__DOT__WB_valid) {
            // uint32_t dut_done_pc = dut->rootp->cpu_pl_soc__DOT__core0__DOT__WB_pc;

            instructions_executed += 1;

            // Step the simulator ahead but save PC of currently executing instruction

            bool equals = simulator_equals_dut(dut, &simulator) | independent;
            if (!equals) {
                // if (!quiet) {
                // printf("ERROR: Simulator does not match DUT!\n");
                printf("Instruction failed (pc=%u): %x\n", dut_prevpc, dut->rootp->cpu_pl_soc__DOT__spram__DOT__memory[dut_prevpc / 4]);
                // }
                fail = true;
                if (!no_exit_on_fail) break;
            }

            if ((insn_limit > 0) && instructions_executed >= insn_limit) {
                if (!quiet) printf("Reached instruction limit, finishing.\n");
                break;
            }
            dut_prevpc = dut->rootp->cpu_pl_soc__DOT__core0__DOT__WB_pc;

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
        }
    }

    std::chrono::time_point end_time = std::chrono::high_resolution_clock::now();
    int64_t ms = std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time).count();

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

    if (stats) {
        vluint64_t cycles_total = (sim_time - run_start) / 2;
        float cpi = ((float)cycles_total) / instructions_executed;
        printf("Stats:\n");
        printf("\tInstructions executed: %lu\n", instructions_executed);
        printf("\tProcessor cycles: %lu\n", cycles_total);
        printf("\tAvg. cycles per instruction: %.4f\n", cpi);
        double insps = ((double)instructions_executed / (double)ms) * 1000;
        double cycps = ((double)cycles_total / (double)ms) * 1000;
        printf("\tSimulation time (ms): %ld\n", ms);
        printf("\tAvg. instructions per sim-second: %f\n", insps);
        printf("\tAvg. cycles per sim-second: %f\n", cycps);
    }

    if (tracefile != nullptr)m_trace->close();
    rv_simulator_deinit(&simulator);
    delete dut;
    exit(fail ? EXIT_FAIL : EXIT_SUCCESS);
}
