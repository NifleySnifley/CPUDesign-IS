#include <stdlib.h>
#include <iostream>
#include <memory.h>
#include <stdio.h> 
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "obj_dir/Vsoc_sim.h"
#include "obj_dir/Vsoc_sim___024unit.h"
#include "obj_dir/Vsoc_sim___024root.h"

extern "C" {
#include "../../../software/simulator/src/rv32i_simulator.h"
}

#define MAX_SIM_TIME 500
#define RESET_TIME 11
#define PROGRAM_FILE "obj_dir/memory.bin"
vluint64_t sim_time = 0;

int simulator_read_word(rv_simulator_t* sim, uint32_t i) {
    return sim->memory[i + 0] | (sim->memory[i + 1] << 8) | (sim->memory[i + 2] << 16) | (sim->memory[i + 3] << 24);
}

// TODO: make sim read word fn
bool simulator_equals_dut(Vsoc_sim* dut, uint32_t dut_p_pc, rv_simulator_t* sim) {
    if (sim->pc != dut_p_pc) return false;
    for (int r = 0; r < 32; ++r) {
        if (sim->x[r] != dut->rootp->soc_sim__DOT__core0__DOT__registers[r]) {
            printf("Mismatch of register %d: sim=%u, dut=%u\n", r, sim->x[r], (uint32_t)dut->rootp->soc_sim__DOT__core0__DOT__registers[r]);
            return false;
        }
    }

    for (int wa = 0; wa < sim->mem_size / 4; ++wa) {
        if (simulator_read_word(sim, wa * 4) != dut->rootp->soc_sim__DOT__mem__DOT__memory[wa]) {
            printf("Mismatch of memory word @ %x: sim=%u, dut=%u\n", wa * 4, simulator_read_word(sim, wa * 4), dut->rootp->soc_sim__DOT__mem__DOT__memory[wa]);
            return false;
        }
    }

    return true;
}

void dut_pprint_memory(Vsoc_sim* dut) {
    int num_words = (sizeof(dut->rootp->soc_sim__DOT__mem__DOT__memory) / 32) / 4;
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

int main(int argc, char** argv, char** env) {
    Vsoc_sim* dut = new Vsoc_sim;
    Verilated::traceEverOn(true);
    VerilatedVcdC* m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("soc_sim.vcd");

    rv_simulator_t simulator;
    constexpr uint32_t memsize_b = sizeof(dut->rootp->soc_sim__DOT__mem__DOT__memory.m_storage) / 32;

    rv_simulator_init(&simulator, memsize_b);
    int binsize = rv_simulator_load_memory_from_file(&simulator, PROGRAM_FILE);
    printf("Loading binary, size = %d\n", binsize);

    for (int i = 0; i < memsize_b / 4; ++i) {
        // We're setting WORDS here!
        uint32_t value = 0;
        if (i < binsize / 4) {
            value = simulator_read_word(&simulator, i * 4);
        }
        // for (int b = 0; b < 32; ++b) {
        dut->rootp->soc_sim__DOT__mem__DOT__memory[i] = value;
    }

    while (sim_time < RESET_TIME) {
        dut->rst = (sim_time < (RESET_TIME / 2));
        dut->clk ^= 1;
        dut->eval();
        m_trace->dump(sim_time);
        sim_time++;
    }

    bool fail = false;
    vluint64_t run_start = sim_time;
    while (sim_time < MAX_SIM_TIME) {
        // uint32_t pc_execing = dut->rootp->soc_sim__DOT__core0__DOT__pc;

        dut->clk = 0;
        dut->eval();
        m_trace->dump(sim_time);
        sim_time++;
        dut->clk = 1;
        dut->eval();
        m_trace->dump(sim_time);
        sim_time++;

        vluint64_t run_time = (sim_time - run_start) / 2;

        if (dut->rootp->instruction_sync) {
            rv_simulator_step(&simulator);
            printf("Instruction completed @ cycle %ld (pc=%u, sim_pc=%u)\n", run_time, dut->rootp->soc_sim__DOT__core0__DOT__pc, simulator.pc);
            // Now, both should be in sync!
            bool equals = simulator_equals_dut(dut, dut->rootp->soc_sim__DOT__core0__DOT__pc, &simulator);
            if (!equals) {
                printf("Simulator does not match DUT!\n");
                fail = true;
                break;
            }
        }
    }

    const char* resultstr = fail ? "\x1b[31mxFAIL\x1b[0m/" : "\x1b[32mSUCCESS\x1b[0m";
    printf("\n================================ %s ================================\n\n", resultstr);

    printf("Simulator registers:\n");
    rv_simulator_pprint_registers(&simulator);
    printf("Simulator memory:\n");
    rv_simulator_pprint_memory(&simulator);

    printf("\n\n");

    printf("DUT registers:\n");
    dut_pprint_registers(dut);
    printf("DUT memory dump:\n");
    dut_pprint_memory(dut);

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}