#ifndef RV32I_SIMULATOR_H
#define RV32I_SIMULATOR_H

#include <stdint.h>
#include <stdbool.h>

#define BITS(x,lo,hi) ((x >> lo) & ((2<<(hi-lo))-1))
#define NONES(n) ((1<<n)-1)

#define OC_LOAD 0b00000
#define OC_LOAD_FP 0b00001
#define OC_CUSTOM0 0b00010
#define OC_MISC_MEM 0b00011
#define OC_OP_IMM 0b00100
#define OC_AUIPC 0b00101
#define OC_IMM_32 0b00110
#define OC_48B_0 0b00111  

#define OC_STORE 0b01000
#define OC_STORE_FP 0b01001
#define OC_CUSTOM1 0b01010
#define OC_AMO 0b01011
#define OC_OP 0b01100
#define OC_LUI 0b01101
#define OC_OP_32 0b01110
#define OC_64B_0 0b01111

#define OC_MADD 0b10000
#define OC_MSUB 0b10001
#define OC_NMSUB 0b10010
#define OC_NMADD 0b10011
#define OC_OP_FP 0b10100
#define OC_CUSTOM2_RV128 0b10110
#define OC_48B_1 0b10111

#define OC_BRANCH 0b11000
#define OC_JALR 0b11001
#define OC_JAL 0b11011
#define OC_SYSTEM 0b11100
#define OC_CUSTOM3_RV128 0b11110
#define OC_80BP_0 0b11111

#define BITS_32 0b11111111111111111111111111111111

#define TRACE_INSTR(pc, name) printf("Instruction @ pc=%x: %s\n", pc, name);

#ifndef TRACE_INSTR
#define TRACE_INSTR(pc, name)
#endif

// #define TRACE_MEM_WRITE(addr, v) printf("W %x @ %x\n", v, addr);

#ifndef TRACE_MEM_WRITE
#define TRACE_MEM_WRITE(addr, v)
#endif

#define TRACE_COND(bval)

#define TRACE_ERROR(simptr) rv_simulator_print_regs(simptr);

#ifndef TRACE_ERROR
#define TRACE_ERROR(simptr)
#endif

// #define TRACE_ARGUMENTS(src1, src2, dest, imm) printf("Arguments: rs1:%d, rs2:%d, rd:%d, imm:%d\n", src1, src2, dest, imm);

#ifndef TRACE_ARGUMENTS
#define TRACE_ARGUMENTS(src1, src2, dest, imm)
#endif

typedef struct rv_simulator_t {
    uint32_t x[32];
    uint32_t pc;

    // Do bounds check
    uint32_t mem_size;
    uint8_t* memory;
} rv_simulator_t;

// Returns -1 on breakpoint, -2 on syscall, >0 on error
int rv_simulator_step(rv_simulator_t* sim);

bool rv_simulator_load_memory(rv_simulator_t* sim, uint8_t* data, uint32_t offset, uint32_t count);

void rv_simulator_init(rv_simulator_t* sim, uint32_t mem_size);
void rv_simulator_deinit(rv_simulator_t* sim);

void rv_simulator_print_regs(rv_simulator_t* sim);

void rv_simulator_dump_regs(rv_simulator_t* sim, const char* reg_filename);
void rv_simulator_dump_memory(rv_simulator_t* sim, const char* mem_filename);


#endif