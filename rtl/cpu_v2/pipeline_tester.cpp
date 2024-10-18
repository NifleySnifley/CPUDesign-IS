#include <stdlib.h>
#include <iostream>
#include <memory.h>
#include <stdio.h> 
#include <string.h>
#include <cstring>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include <getopt.h>
#include "obj_dir/Vcpu_pipelined.h"
#include "obj_dir/Vcpu_pipelined___024root.h"
#include "obj_dir/Vcpu_pipelined___024unit.h"
#include <chrono>

extern "C" {
#include "../../software/simulator/src/rv32i_simulator.h"
}

int simulator_read_word(rv_simulator_t* sim, uint32_t i) {
    return rv_simulator_read_byte(sim, i + 0) | \
        (rv_simulator_read_byte(sim, i + 1) << 8) | \
        (rv_simulator_read_byte(sim, i + 2) << 16) | \
        (rv_simulator_read_byte(sim, i + 3) << 24);
}

// void dut_pprint_memory(Vcpu_pipelined* dut) {
//     int num_words = (sizeof(dut->rootp->soc_sim__DOT__mem__DOT__memory) / 32);
//     uint32_t* membuffer = (uint32_t*)calloc(num_words, 4);
//     for (int wi = 0; wi < num_words; ++wi)
//         membuffer[wi] = (uint32_t)dut->rootp->soc_sim__DOT__mem__DOT__memory[wi];

//     FILE* hd_proc = popen("hd", "w");
//     fwrite(membuffer, 4, num_words, hd_proc);
//     fflush(hd_proc);
//     int status = pclose(hd_proc);
// }

void dut_pprint_registers(Vcpu_pipelined* dut) {
    printf("Registers:\n");
    for (int r = 0; r < 32; ++r) {
        printf(
            "\t\x1b[31mx%d\x1b[0m/%s = \x1b[32m%d\x1b[0m (0x%x)\n", r,
            REG_ABI_NAMES[r],
            (int32_t)dut->rootp->cpu_pipelined__DOT__registers[r],
            dut->rootp->cpu_pipelined__DOT__registers[r]
        );
    }
}

// void regset(Vsoc_sim* dut, rv_simulator_t* sim, int reg, uint32_t value) {
//     sim->x[reg] = value;
//     dut->rootp->soc_sim__DOT__core0__DOT__registers[reg] = value;
// }

int main(int argc, char** argv, char** env) {
    if (argc < 2) {
        fprintf(stderr, "Error, input memory file is required!\n");
        exit(1);
    }

    char* memfile = argv[1];
    char* tracefile = "cpu_pipelined.vcd";

    Vcpu_pipelined* dut = new Vcpu_pipelined;
    if (tracefile != nullptr) Verilated::traceEverOn(true);

    VerilatedVcdC* m_trace = new VerilatedVcdC;
    if (tracefile != nullptr) {
        dut->trace(m_trace, 5);
        m_trace->open(tracefile);
    }

    rv_simulator_t simulator;
    constexpr uint32_t memsize_words = 2048;
    rv_simulator_init(&simulator);
    rv_simulator_segmented_memory_t* sim_mem = rv_simulator_init_segmented_memory(&simulator);
    rv_simulator_segmented_memory_add_segment(sim_mem, 0, memsize_words * 4, "progROM", false);

    // TODO: Ceiling divide here!
    int binsize_words = rv_simulator_load_memory_from_file(&simulator, memfile, FILETYPE_AUTO, 0) / 4;
    printf("Loading binary, size = %d words\n", binsize_words);
    if (binsize_words < 0) {
        printf("Error opening memory file!\n");
        exit(2);
    }

    // Copy initialization memory from sim to DUT
    for (int i = 0; i < memsize_words; ++i) {
        uint32_t word = simulator_read_word(&simulator, i * 4);
        dut->rootp->cpu_pipelined__DOT__progMEM[i] = word;
    }

    vluint64_t sim_time = 0;

    // Reset DUT
    while (sim_time < 6) {
        dut->rst = 1;
        dut->clk ^= 1;
        dut->eval();
        if (tracefile != nullptr)m_trace->dump(sim_time);
        sim_time++;
    }
    dut->rst = 0;

    // Run DUT

    for (int i = 0; i < 256; ++i) {
        dut->clk = 0;
        dut->eval();
        if (tracefile != nullptr)m_trace->dump(sim_time);
        sim_time++;
        dut->clk = 1;
        dut->eval();
        if (tracefile != nullptr)m_trace->dump(sim_time);
        sim_time++;

        if (dut->rootp->cpu_pipelined__DOT__WB_valid) {
            int sp_pc = simulator.pc;
            rv_simulator_step(&simulator);
            printf("Valid WB instruction @ pc=%x\n", dut->rootp->cpu_pipelined__DOT__WB_pc);
            printf("Simulator completed pc=%x\n", sp_pc);
        }
    }


    // if (dump) {
    //     printf("SIM registers:\n");
    //     rv_simulator_pprint_registers(&simulator);
    //     printf("SIM memory:\n");
    //     rv_simulator_pprint_memory(&simulator);

    //     printf("\n\n");

    //     printf("DUT registers:\n");
    //     dut_pprint_registers(dut);
    //     printf("DUT memory:\n");
    //     dut_pprint_memory(dut);
    // }

    dut_pprint_registers(dut);

    if (tracefile != nullptr)m_trace->close();
    // rv_simulator_deinit(&simulator);
    delete dut;
    exit(0);
}
