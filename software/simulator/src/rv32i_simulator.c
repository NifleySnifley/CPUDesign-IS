#include <stdio.h>
#include <stdint.h>
#include "rv32i_simulator.h"
#include <memory.h>
#include <stdlib.h>

uint32_t signext(uint32_t num, int n_bits) {
    return num | (num & (1 << (n_bits - 1)) ? (BITS_32 << n_bits) : 0);
}

int rv_simulator_step(rv_simulator_t* sim) {
    uint32_t inst = (sim->memory[sim->pc + 0] << 0) | \
        (sim->memory[sim->pc + 1] << 8) | \
        (sim->memory[sim->pc + 2] << 16) | \
        (sim->memory[sim->pc + 3] << 24);

    // printf("Inst: %x\n", inst);

    uint32_t imm_i = BITS(inst, 20, 31);
    uint32_t imm_s = (BITS(inst, 25, 31) << 5) | BITS(inst, 7, 11);
    uint32_t imm_b = (BITS(inst, 8, 11) << 1) | (BITS(inst, 25, 30) << (1 + 4)) | (BITS(inst, 7, 7) << 11) | (BITS(inst, 31, 31) << 12);
    uint32_t imm_u = inst & (BITS_32 << 12);
    uint32_t imm_j = (BITS(inst, 21, 30) << 1) | (BITS(inst, 20, 20) << 11) | (BITS(inst, 12, 19) << 12) | (BITS(inst, 31, 31) << 20);

    uint32_t s_imm_i = signext(imm_i, 12);
    uint32_t s_imm_s = signext(imm_s, 12);
    uint32_t s_imm_b = signext(imm_b, 13); // Double check all of B format!
    uint32_t s_imm_u = imm_u;
    uint32_t s_imm_j = signext(imm_j, 21);

    uint32_t opcode = inst & 0b1111111;
    uint32_t funct3 = BITS(inst, 12, 14);
    uint32_t funct7 = BITS(inst, 25, 31);

    uint32_t rd = BITS(inst, 7, 11);
    uint32_t rs1 = BITS(inst, 15, 19);
    uint32_t rs2 = BITS(inst, 20, 24);

    if (BITS(opcode, 0, 1) != 0b11) {
        printf("Invalid instruction @ pc=%d (%b/%x)\n", sim->pc, inst, inst);
        TRACE_ERROR(sim);
        return 1;
    }

    // Remove the len bits
    opcode >>= 2;

    // To allow for future tracing of memory/register interactions
#define R(r) (sim->x[r])
#define M(a) (sim->memory[a])
#define RSET(r, v) if(r!=0) {sim->x[r]=(v);}
#define MSET(a, v) TRACE_MEM_WRITE(a, v); if (a < sim->mem_size) { (sim->memory[a] = v); } else {fprintf(stderr, "Error: write address %x exceeds memory size of %x\n", a, sim->mem_size);}; 

    // TODO: Fix PC with returns

    if (opcode == OC_OP) {
        TRACE_ARGUMENTS(rs1, rs2, rd, 0);

        switch (funct7) {
            case 0x00:
                switch (funct3) {
                    // ADD
                    case 0x0:
                        TRACE_INSTR(sim->pc, "ADD");
                        RSET(rd, R(rs1) + R(rs2));
                        break;
                        // XOR
                    case 0x4:
                        TRACE_INSTR(sim->pc, "XOR");
                        RSET(rd, R(rs1) ^ R(rs2));
                        break;
                        // OR
                    case 0x6:
                        TRACE_INSTR(sim->pc, "OR");
                        RSET(rd, R(rs1) | R(rs2));
                        break;
                        // AND
                    case 0x7:
                        TRACE_INSTR(sim->pc, "AND");
                        RSET(rd, R(rs1) & R(rs2));
                        break;
                        // SLL
                    case 0x1:
                        TRACE_INSTR(sim->pc, "SLL");
                        RSET(rd, R(rs1) << (R(rs2) & NONES(5)));
                        break;
                        // SRL
                    case 0x5:
                        TRACE_INSTR(sim->pc, "SRL");
                        RSET(rd, R(rs1) >> (R(rs2) & NONES(5)));
                        break;
                        // SLT
                    case 0x2:
                        TRACE_INSTR(sim->pc, "SLT");
                        RSET(rd, ((int32_t)(rs1) < (int32_t)(rs2)) ? 1 : 0);
                        break;
                        // SLTU
                    case 0x3:
                        TRACE_INSTR(sim->pc, "SLTU");
                        RSET(rd, (R(rs1) < R(rs2)) ? 1 : 0);
                        break;
                    default:
                        TRACE_INSTR(sim->pc, "INVALID 1");
                        TRACE_ERROR(sim);
                        sim->pc += 4;
                        return 1;
                }
                break;
            case 0x20:
                if (funct3 == 0x00) {
                    // SUB
                    TRACE_INSTR(sim->pc, "SUB");
                    RSET(rd, R(rs1) - R(rs2));
                } else if (funct3 == 0x5) {
                    // SRA
                    // TODO: TEST!!!
                    TRACE_INSTR(sim->pc, "SRA");
                    RSET(rd, (R(rs1) >> R(rs2)) | (BITS_32 << (32 - R(rs2))));
                } else {
                    TRACE_INSTR(sim->pc, "INVALID 2");
                    TRACE_ERROR(sim);
                    sim->pc += 4;
                    return 2;
                }
                break;
        }
        sim->pc += 4;
    } else if (opcode == OC_OP_IMM) {
        TRACE_ARGUMENTS(rs1, 0, rd, s_imm_i);
        switch (funct3) {
            // ADDI
            case 0x0:
                TRACE_INSTR(sim->pc, "ADDI");
                RSET(rd, R(rs1) + s_imm_i);
                break;
                // XORI
            case 0x4:
                TRACE_INSTR(sim->pc, "XORI");
                RSET(rd, R(rs1) ^ s_imm_i);
                break;
                // ORI
            case 0x6:
                TRACE_INSTR(sim->pc, "ORI");
                RSET(rd, R(rs1) | s_imm_i);
                break;
                // ANDI
            case 0x7:
                TRACE_INSTR(sim->pc, "ANDI");
                RSET(rd, R(rs1) & s_imm_i);
                break;
                // SLLI
            case 0x1:
                TRACE_INSTR(sim->pc, "SLLI");
                if (BITS(imm_i, 5, 11) == 0x00) {
                    RSET(rd, R(rs1) << (imm_i & 0b11111));
                } else {
                    TRACE_INSTR(sim->pc, "INVALID 3");
                    TRACE_ERROR(sim);
                    sim->pc += 4;
                    return 3;
                }
                break;
            case 0x5:
                // TODO: Check signext
                if (BITS(imm_i, 5, 11) == 0x00) {
                    // SRLI
                    TRACE_INSTR(sim->pc, "SRLI");
                    RSET(rd, R(rs1) >> (imm_i & 0b11111));
                } else if (BITS(imm_i, 5, 11) == 0x20) {
                    // SRAI
                    TRACE_INSTR(sim->pc, "SRAI");
                    uint32_t samt = imm_i & 0b11111;
                    RSET(rd, (R(rs1) >> samt) | (BITS_32 << (32 - samt)));
                } else {
                    TRACE_INSTR(sim->pc, "INVALID 4");
                    TRACE_ERROR(sim);
                    sim->pc += 4;
                    return 4;
                }
                break;
                // SLTI
            case 0x2:
            {
                // TODO: Check signext
                TRACE_INSTR(sim->pc, "SLTI");
                RSET(rd, ((int32_t)(rs1) < s_imm_i) ? 1 : 0);
            }
            break;
            // SLTIU
            case 0x3:
                TRACE_INSTR(sim->pc, "SLTIU");
                RSET(rd, (R(rs1) < imm_i) ? 1 : 0);
                break;
        }
        sim->pc += 4;
    } else if (opcode == OC_LOAD) {
        TRACE_ARGUMENTS(rs1, 0, rd, s_imm_i);
        uint32_t baseaddr = R(rs1) + s_imm_i;
        if (funct3 == 0x0) {
            // LB
            TRACE_INSTR(sim->pc, "LB");
            RSET(rd, signext(M(baseaddr), 8));
        } else if (funct3 == 0x1) {
            // LH
            TRACE_INSTR(sim->pc, "LH");
            RSET(rd, signext(M(baseaddr) | (M(baseaddr + 1) << 8), 16));
        } else if (funct3 == 0x2) {
            // LW
            TRACE_INSTR(sim->pc, "LW");
            RSET(rd,
                M(baseaddr + 0) | (M(baseaddr + 1) << 8) | (M(baseaddr + 2) << 16) | (M(baseaddr + 3) << (24))
            );
        } else if (funct3 == 0x4) {
            // LBU
            TRACE_INSTR(sim->pc, "LBU");
            RSET(rd, M(baseaddr));
        } else if (funct3 == 0x5) {
            // LHU
            TRACE_INSTR(sim->pc, "LHU");
            RSET(rd, M(baseaddr) | (M(baseaddr + 1) << 8));
        }
        sim->pc += 4;
    } else if (opcode == OC_STORE) {
        TRACE_ARGUMENTS(rs1, 0, rd, s_imm_s);
        uint32_t baseaddr = R(rs1) + s_imm_s;
        if (funct3 == 0x0) {
            // SB
            TRACE_INSTR(sim->pc, "SB");
            MSET(baseaddr + 0, BITS(R(rs2), 0, 7));
        } else if (funct3 == 0x1) {
            // SH
            TRACE_INSTR(sim->pc, "SH");
            MSET(baseaddr + 0, BITS(R(rs2), 0, 7));
            MSET(baseaddr + 1, BITS(R(rs2), 8, 15));
        } else if (funct3 == 0x2) {
            // SW
            TRACE_INSTR(sim->pc, "SW");
            MSET(baseaddr + 0, BITS(R(rs2), 0, 7));
            MSET(baseaddr + 1, BITS(R(rs2), 8, 15));
            MSET(baseaddr + 2, BITS(R(rs2), 16, 23));
            MSET(baseaddr + 3, BITS(R(rs2), 24, 31));
        }
        sim->pc += 4;
    } else if (opcode == OC_BRANCH) {
        bool conditional = false;
        TRACE_ARGUMENTS(rs1, rs2, 0, s_imm_b);
        uint32_t target = sim->pc + s_imm_b;
        // type-B
        switch (funct3) {
            case 0x0:
                // BEQ
                TRACE_INSTR(sim->pc, "BEQ");
                conditional = R(rs1) == R(rs2);
                break;
            case 0x1:
                // BNE
                TRACE_INSTR(sim->pc, "BNE");
                conditional = R(rs1) != R(rs2);
                break;
            case 0x4:
                // BLT
                TRACE_INSTR(sim->pc, "BLT");
                conditional = (int32_t)R(rs1) < (int32_t)R(rs2);
                break;
            case 0x5:
                // BGE
                TRACE_INSTR(sim->pc, "BGE");
                conditional = (int32_t)R(rs1) >= (int32_t)R(rs2);
                break;
            case 0x6:
                // BLTU
                TRACE_INSTR(sim->pc, "BLTU");
                conditional = R(rs1) < R(rs2);
                break;
            case 0x7:
                // BGEU
                TRACE_INSTR(sim->pc, "BGEU");
                conditional = R(rs1) >= R(rs2);
                break;
        }

        if (conditional) {
            TRACE_COND(true);
            sim->pc = target;
        } else {
            TRACE_COND(false);
            sim->pc += 4;
        }
    } else if (opcode == OC_JAL) {
        // JAL
        TRACE_ARGUMENTS(0, 0, rd, s_imm_j);
        TRACE_INSTR(sim->pc, "JAL");
        uint32_t target = sim->pc + s_imm_j;
        RSET(rd, sim->pc + 4);
        sim->pc = target;
    } else if (opcode == OC_JALR) {
        // JALR
        TRACE_ARGUMENTS(rs1, 0, rd, s_imm_i);
        TRACE_INSTR(sim->pc, "JALR");
        uint32_t target = s_imm_i + R(rs1);
        // rv_simulator_print_regs(sim);
        // printf("target: %x\n", target);
        RSET(rd, sim->pc + 4);
        sim->pc = target;
    } else if (opcode == OC_LUI) {
        // LUI
        TRACE_ARGUMENTS(0, 0, rd, s_imm_u);
        TRACE_INSTR(sim->pc, "LUI");
        RSET(
            rd,
            s_imm_u // | BITS(R(rd), 0, 11)
        );
        sim->pc += 4;

    } else if (opcode == OC_AUIPC) {
        // AUIPC
        TRACE_ARGUMENTS(0, 0, rd, s_imm_u);
        TRACE_INSTR(sim->pc, "AUIPC");
        RSET(
            rd,
            sim->pc + s_imm_u
        );
        sim->pc += 4;

    } else if (opcode == OC_SYSTEM) {
        sim->pc += 4;
        TRACE_ARGUMENTS(0, 0, 0, s_imm_i);
        if (imm_i == 0x00) {
            // ECALL
            TRACE_INSTR(sim->pc, "ECALL");
            return -2;
        } else if (imm_i == 0x01) {
            // EBREAK
            TRACE_INSTR(sim->pc, "EBREAK");
            return -1;
        } else {
            TRACE_INSTR(sim->pc, "CSR (UNIMPLEMENTED)");
            TRACE_ERROR(sim);
            // Unimplemented (CSRs)
            return 5;
        }
    } else {
        TRACE_INSTR(sim->pc, "INVALID 6");
        TRACE_ERROR(sim);
        sim->pc += 4;
        return 6;
    }

    // Not even gonna implement fence, it's not neccesary

    return 0;
}

bool rv_simulator_load_memory(rv_simulator_t* sim, uint8_t* data, uint32_t offset, uint32_t count) {
    if (offset + count > sim->mem_size) {
        return true;
    } else {
        memcpy(&sim->memory[offset], data, count);
    }
}

void rv_simulator_init(rv_simulator_t* sim, uint32_t mem_size) {
    sim->memory = (uint8_t*)calloc((size_t)mem_size, sizeof(uint8_t));
    sim->mem_size = mem_size;
    sim->pc = 0;
    memset(sim->x, 0, sizeof(uint32_t) * 32);
}
void rv_simulator_deinit(rv_simulator_t* sim) {
    free(sim->memory);
    sim->mem_size = 0;
}

void rv_simulator_print_regs(rv_simulator_t* sim) {
    printf("Register Dump:\n");
    for (int r = 0; r < 32; ++r) {
        printf("\tx%d = %d (0x%x)\n", r, (int32_t)sim->x[r], sim->x[r]);
    }
}

void rv_simulator_dump_regs(rv_simulator_t* sim, const char* reg_filename) {
    FILE* regfile = fopen(reg_filename, "w");
    if (regfile == NULL) {
        fprintf(stderr, "Error opening register dump file\n");
        return 4;
    }

    fprintf(regfile, "arch_name,abi_name,value\n");

    for (int r = 0; r < 32; ++r) {
        fprintf(regfile, "x%d,WIP,%d\n", r, sim->x[r]);
    }

    // fwrite(sim->x, sizeof(uint32_t), 32, regfile);
    fflush(regfile);
    fclose(regfile);
}

void rv_simulator_dump_memory(rv_simulator_t* sim, const char* mem_filename) {
    FILE* memfile = fopen(mem_filename, "w");
    if (memfile == NULL) {
        fprintf(stderr, "Error opening memory dump file\n");
        return 4;
    }
    fwrite(sim->memory, 1, sim->mem_size, memfile);
    fflush(memfile);
    fclose(memfile);
}