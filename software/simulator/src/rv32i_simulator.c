#include <stdio.h>
#include <stdint.h>
#include "rv32i_simulator.h"
#include <memory.h>
#include <stdlib.h>
#include <unistd.h>

const char* REG_ABI_NAMES[32] = {
    "zero",
    "ra",
    "sp",
    "gp",
    "tp",
    "t0",
    "t1",
    "t2",
    "s0/fp",
    "s1",
    "a0",
    "a1",
    "a2",
    "a3",
    "a4",
    "a5",
    "a6",
    "a7",
    "s2",
    "s3",
    "s4",
    "s5",
    "s6",
    "s7",
    "s8",
    "s9",
    "s10",
    "s11",
    "t3",
    "t4",
    "t5",
    "t6"
};

bool RV_SIM_VERBOSE = false;

/// @brief Sign-extends the binary representation of a number
/// @param num number to extend
/// @param n_bits bit length of number to extend
/// @return `num` sign-extended to 32 bits
uint32_t signext(uint32_t num, int n_bits) {
    return num | (num & (1 << (n_bits - 1)) ? (BITS_32 << n_bits) : 0);
}

uint32_t sra(uint32_t num, int shift_amount) {
    bool msb = num & (1 << 31);
    num >>= shift_amount;
    if (msb) {
        num |= (BITS_32 << 32 - 1 - shift_amount);
    }
    return num;
}

int rv_simulator_step(rv_simulator_t* sim) {
    uint32_t inst = (rv_simulator_read_byte(sim, sim->pc + 0) << 0) | \
        (rv_simulator_read_byte(sim, sim->pc + 1) << 8) | \
        (rv_simulator_read_byte(sim, sim->pc + 2) << 16) | \
        (rv_simulator_read_byte(sim, sim->pc + 3) << 24);

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
        if (RV_SIM_VERBOSE) printf("Invalid instruction @ pc=%d (%b/%x)\n", sim->pc, inst, inst);
        TRACE_ERROR(sim);
        return 1;
    }

    // Remove the len bits
    opcode >>= 2;

    // To allow for future tracing of memory/register interactions
#define R(r) (sim->x[r])
// #define M(a) (sim->memory[a])
#define M(a) rv_simulator_read_byte(sim, a)
#define RSET(r, v) if(r!=0) {sim->x[r]=(v);}
// #define MSET(a, v) TRACE_MEM_WRITE(a, v); if (a < sim->mem_size) { (sim->memory[a] = v); } else {fprintf(stderr, "Error: write address %x exceeds memory size of %x\n", a, sim->mem_size);}; 
#define MSET(a, v) rv_simulator_write_byte(sim, a, v)

    // TODO: Fix PC with returns

    if (opcode == OC_OP) {
        TRACE_ARGUMENTS(rs1, rs2, rd, 0);

        switch (funct7) {
            case 0x00:
                switch (funct3) {
                    // ADD
                    case 0x0:
                        TRACE_INSTR(sim, "ADD");
                        RSET(rd, R(rs1) + R(rs2));
                        break;
                        // XOR
                    case 0x4:
                        TRACE_INSTR(sim, "XOR");
                        RSET(rd, R(rs1) ^ R(rs2));
                        break;
                        // OR
                    case 0x6:
                        TRACE_INSTR(sim, "OR");
                        RSET(rd, R(rs1) | R(rs2));
                        break;
                        // AND
                    case 0x7:
                        TRACE_INSTR(sim, "AND");
                        RSET(rd, R(rs1) & R(rs2));
                        break;
                        // SLL
                    case 0x1:
                        TRACE_INSTR(sim, "SLL");
                        RSET(rd, R(rs1) << (R(rs2) & NONES(5)));
                        break;
                        // SRL
                    case 0x5:
                        TRACE_INSTR(sim, "SRL");
                        RSET(rd, R(rs1) >> (R(rs2) & NONES(5)));
                        break;
                        // SLT
                    case 0x2:
                        TRACE_INSTR(sim, "SLT");
                        RSET(rd, ((int32_t)(R(rs1)) < (int32_t)(R(rs2))) ? 1 : 0);
                        break;
                        // SLTU
                    case 0x3:
                        TRACE_INSTR(sim, "SLTU");
                        RSET(rd, (R(rs1) < R(rs2)) ? 1 : 0);
                        break;
                    default:
                        TRACE_INSTR(sim, "INVALID 1");
                        TRACE_ERROR(sim);
                        sim->pc += 4;
                        return 1;
                }
                break;
            case 0x20:
                if (funct3 == 0x00) {
                    // SUB
                    TRACE_INSTR(sim, "SUB");
                    RSET(rd, R(rs1) - R(rs2));
                } else if (funct3 == 0x5) {
                    // SRA
                    // TODO: TEST!!!
                    TRACE_INSTR(sim, "SRA");
                    RSET(rd, sra(R(rs1), R(rs2)));
                } else {
                    TRACE_INSTR(sim, "INVALID 2");
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
                TRACE_INSTR(sim, "ADDI");
                RSET(rd, R(rs1) + s_imm_i);
                break;
                // XORI
            case 0x4:
                TRACE_INSTR(sim, "XORI");
                RSET(rd, R(rs1) ^ s_imm_i);
                break;
                // ORI
            case 0x6:
                TRACE_INSTR(sim, "ORI");
                RSET(rd, R(rs1) | s_imm_i);
                break;
                // ANDI
            case 0x7:
                TRACE_INSTR(sim, "ANDI");
                RSET(rd, R(rs1) & s_imm_i);
                break;
                // SLLI
            case 0x1:
                TRACE_INSTR(sim, "SLLI");
                if (BITS(imm_i, 5, 11) == 0x00) {
                    RSET(rd, R(rs1) << (imm_i & 0b11111));
                } else {
                    TRACE_INSTR(sim, "INVALID 3");
                    TRACE_ERROR(sim);
                    sim->pc += 4;
                    return 3;
                }
                break;
            case 0x5:
                // TODO: Check signext
                if (BITS(imm_i, 5, 11) == 0x00) {
                    // SRLI
                    TRACE_INSTR(sim, "SRLI");
                    RSET(rd, R(rs1) >> (imm_i & 0b11111));
                } else if (BITS(imm_i, 5, 11) == 0x20) {
                    // SRAI
                    TRACE_INSTR(sim, "SRAI");
                    uint32_t samt = imm_i & 0b11111;
                    RSET(rd, sra(R(rs1), samt));
                } else {
                    TRACE_INSTR(sim, "INVALID 4");
                    TRACE_ERROR(sim);
                    sim->pc += 4;
                    return 4;
                }
                break;
                // SLTI
            case 0x2:
            {
                // TODO: Check signext
                TRACE_INSTR(sim, "SLTI");
                RSET(rd, ((int32_t)(R(rs1)) < (int32_t)s_imm_i) ? 1 : 0);
            }
            break;
            // SLTIU
            case 0x3:
                TRACE_INSTR(sim, "SLTIU");
                RSET(rd, (R(rs1) < imm_i) ? 1 : 0);
                break;
        }
        sim->pc += 4;
    } else if (opcode == OC_LOAD) {
        TRACE_ARGUMENTS(rs1, 0, rd, s_imm_i);
        uint32_t baseaddr = R(rs1) + s_imm_i;
        if (funct3 == 0x0) {
            // LB
            TRACE_INSTR(sim, "LB");
            RSET(rd, signext(M(baseaddr), 8));
        } else if (funct3 == 0x1) {
            // LH
            TRACE_INSTR(sim, "LH");
            RSET(rd, signext(M(baseaddr) | (M(baseaddr + 1) << 8), 16));
        } else if (funct3 == 0x2) {
            // LW
            TRACE_INSTR(sim, "LW");
            RSET(rd,
                M(baseaddr + 0) | (M(baseaddr + 1) << 8) | (M(baseaddr + 2) << 16) | (M(baseaddr + 3) << (24))
            );
        } else if (funct3 == 0x4) {
            // LBU
            TRACE_INSTR(sim, "LBU");
            RSET(rd, M(baseaddr));
        } else if (funct3 == 0x5) {
            // LHU
            TRACE_INSTR(sim, "LHU");
            RSET(rd, M(baseaddr) | (M(baseaddr + 1) << 8));
        }
        sim->pc += 4;
    } else if (opcode == OC_STORE) {
        TRACE_ARGUMENTS(rs1, 0, rd, s_imm_s);
        uint32_t baseaddr = R(rs1) + s_imm_s;
        if (funct3 == 0x0) {
            // SB
            TRACE_INSTR(sim, "SB");
            MSET(baseaddr + 0, BITS(R(rs2), 0, 7));
        } else if (funct3 == 0x1) {
            // SH
            TRACE_INSTR(sim, "SH");
            MSET(baseaddr + 0, BITS(R(rs2), 0, 7));
            MSET(baseaddr + 1, BITS(R(rs2), 8, 15));
        } else if (funct3 == 0x2) {
            // SW
            TRACE_INSTR(sim, "SW");
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
                TRACE_INSTR(sim, "BEQ");
                conditional = R(rs1) == R(rs2);
                break;
            case 0x1:
                // BNE
                TRACE_INSTR(sim, "BNE");
                conditional = R(rs1) != R(rs2);
                break;
            case 0x4:
                // BLT
                TRACE_INSTR(sim, "BLT");
                conditional = (int32_t)R(rs1) < (int32_t)R(rs2);
                break;
            case 0x5:
                // BGE
                TRACE_INSTR(sim, "BGE");
                conditional = (int32_t)R(rs1) >= (int32_t)R(rs2);
                break;
            case 0x6:
                // BLTU
                TRACE_INSTR(sim, "BLTU");
                conditional = R(rs1) < R(rs2);
                break;
            case 0x7:
                // BGEU
                TRACE_INSTR(sim, "BGEU");
                conditional = R(rs1) >= R(rs2);
                break;
        }

        if (conditional) {
            TRACE_COND(sim, true);
            sim->pc = target;
        } else {
            TRACE_COND(sim, false);
            sim->pc += 4;
        }
    } else if (opcode == OC_JAL) {
        // JAL
        TRACE_ARGUMENTS(0, 0, rd, s_imm_j);
        TRACE_INSTR(sim, "JAL");
        uint32_t target = sim->pc + s_imm_j;
        RSET(rd, sim->pc + 4);
        sim->pc = target;
    } else if (opcode == OC_JALR) {
        // JALR
        TRACE_ARGUMENTS(rs1, 0, rd, s_imm_i);
        TRACE_INSTR(sim, "JALR");
        uint32_t target = s_imm_i + R(rs1);
        // rv_simulator_print_regs(sim);
        // printf("target: %x\n", target);
        RSET(rd, sim->pc + 4);
        sim->pc = target;
    } else if (opcode == OC_LUI) {
        // LUI
        TRACE_ARGUMENTS(0, 0, rd, s_imm_u);
        TRACE_INSTR(sim, "LUI");
        RSET(
            rd,
            s_imm_u // | BITS(R(rd), 0, 11)
        );
        sim->pc += 4;

    } else if (opcode == OC_AUIPC) {
        // AUIPC
        TRACE_ARGUMENTS(0, 0, rd, s_imm_u);
        TRACE_INSTR(sim, "AUIPC");
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
            TRACE_INSTR(sim, "ECALL");
            if (sim->scall_fn != NULL) {
                (sim->scall_fn)(sim);
            }
            return -2;
        } else if (imm_i == 0x01) {
            // EBREAK
            TRACE_INSTR(sim, "EBREAK");
            if (sim->bkpt_fn != NULL) {
                (sim->bkpt_fn)(sim);
            }
            return -1;
        } else {
            TRACE_INSTR(sim, "CSR (UNIMPLEMENTED)");
            TRACE_ERROR(sim);
            // Unimplemented (CSRs)
            return 5;
        }
    } else {
        TRACE_INSTR(sim, "INVALID 6");
        TRACE_ERROR(sim);
        sim->pc += 4;
        return 6;
    }

    // Not even gonna implement fence, it's not neccesary

    return 0;
}

bool rv_simulator_load_memory(rv_simulator_t* sim, uint8_t* data, uint32_t offset, uint32_t count) {
    if (sim->memory_interface.type == MONOLITHIC) {
        rv_simulator_monolithic_memory_t* mem = (rv_simulator_monolithic_memory_t*)sim->memory_interface.memory;
        if (offset + count > mem->size) {
            printf("Error loading memory, data is larger than simulator memory! (data=%d bytes, memory=%d bytes)\n", count, mem->size);
            return true;
        } else {
            memcpy(&mem->data[offset], data, count);
        }
        return false;
    } else if (sim->memory_interface.type == SEGMENTED) {
        // FIXME: This is stupid, and has no way of returning error codes, would instead flood the console with error messages!
        // Could certainly implement a more optimized version with memcpy and segment searching
        for (int i = 0; i < count; ++i) {
            rv_simulator_write_byte(sim, offset + i, data[i]);
        }
        return false;
    } else {
        return true;
    }
}

void rv_simulator_init_monolithic_memory(rv_simulator_t* sim, uint32_t mem_size) {
    rv_simulator_monolithic_memory_t* mem = (rv_simulator_monolithic_memory_t*)calloc(1, sizeof(rv_simulator_monolithic_memory_t));
    rv_simulator_monolithic_memory_init(mem, mem_size);
    sim->memory_interface.memory = mem;
    sim->memory_interface.type = MONOLITHIC;
    sim->memory_interface.read_byte_fn = rv_simulator_monolithic_memory_read;
    sim->memory_interface.write_byte_fn = rv_simulator_monolithic_memory_write;
}

rv_simulator_segmented_memory_t* rv_simulator_init_segmented_memory(rv_simulator_t* sim) {
    rv_simulator_segmented_memory_t* mem = (rv_simulator_segmented_memory_t*)calloc(1, sizeof(rv_simulator_segmented_memory_t));
    rv_simulator_segmented_memory_init(mem);
    sim->memory_interface.memory = mem;
    sim->memory_interface.type = SEGMENTED;
    sim->memory_interface.read_byte_fn = rv_simulator_segmented_memory_read;
    sim->memory_interface.write_byte_fn = rv_simulator_segmented_memory_write;

    return mem;
}

void rv_simulator_init(rv_simulator_t* sim) {
    sim->err_trace = NULL;
    sim->cond_trace = NULL;
    sim->instr_trace = NULL;

    sim->pc = 0;
    memset(sim->x, 0, sizeof(sim->x));

    sim->bkpt_fn = NULL;
    sim->scall_fn = NULL;
}
void rv_simulator_deinit(rv_simulator_t* sim) {
    if (sim->memory_interface.type == MONOLITHIC) {
        rv_simulator_monolithic_memory_deinit((rv_simulator_monolithic_memory_t*)sim->memory_interface.memory);
    } else {
        // TODO: Implement tiled memory model
    }
}

void rv_simulator_print_regs(rv_simulator_t* sim) {
    printf("Register Dump:\n");
    for (int r = 0; r < 32; ++r) {
        printf("\tx%d = %d (0x%x)\n", r, (int32_t)sim->x[r], sim->x[r]);
    }
}

int rv_simulator_dump_regs(rv_simulator_t* sim, FILE* regfile) {
    fprintf(regfile, "arch_name,abi_name,value\n");

    for (int r = 0; r < 32; ++r) {
        fprintf(regfile, "x%d,%s,%d\n", r, REG_ABI_NAMES[r], sim->x[r]);
    }
    fflush(regfile);
    return 0;
}

uint32_t rv_simulator_total_memory_size(rv_simulator_t* sim) {
    if (sim->memory_interface.type == MONOLITHIC) {
        rv_simulator_monolithic_memory_t* mem = (rv_simulator_monolithic_memory_t*)sim->memory_interface.memory;
        return mem->size;
    } else if (sim->memory_interface.type == SEGMENTED) {
        rv_simulator_segmented_memory_t* segmem = (rv_simulator_segmented_memory_t*)sim->memory_interface.memory;
        uint32_t total = 0;
        printf("N = %d\n", segmem->n_segments);
        for (int i = 0; i < segmem->n_segments; ++i)
            total += segmem->segments[i].size;
        return total;
    } else {
        return -1;
    }
}

// FIXME: Fix for different memory implementations
int rv_simulator_dump_memory(rv_simulator_t* sim, FILE* memfile) {
    if (sim->memory_interface.type == MONOLITHIC) {
        rv_simulator_monolithic_memory_t* mem = (rv_simulator_monolithic_memory_t*)sim->memory_interface.memory;
        fwrite(mem->data, 1, mem->size, memfile);
        fflush(memfile);
    } else {
        printf("Error, memory dump not yet supported for the segmented memory model.\n");
        return 1;
    }

    return 0;
}

// FIXME: Fix for different memory implementations
void rv_simulator_pprint_memory(rv_simulator_t* sim) {
    // Use 'hd' to do a nice hexdump! (pipe memory to hd)

    if (sim->memory_interface.type == MONOLITHIC) {
        rv_simulator_monolithic_memory_t* mem = (rv_simulator_monolithic_memory_t*)sim->memory_interface.memory;
        FILE* hd_proc = popen("hd", "w");
        fwrite(mem->data, 1, mem->size, hd_proc);
        fflush(hd_proc);
        int status = pclose(hd_proc);
    } else if (sim->memory_interface.type == SEGMENTED) {
        rv_simulator_segmented_memory_t* segmem = (rv_simulator_segmented_memory_t*)sim->memory_interface.memory;
        for (int i = 0; i < segmem->n_segments; ++i) {
            rv_simulator_segmented_memory_segment_t* segment = &segmem->segments[i];
            printf("Memory segment '%s' (%x-%x):\n", segment->tag, segment->start_address, segment->start_address + segment->size);
            FILE* hd_proc = popen("hd", "w");
            fwrite(segment->data, 1, segment->size, hd_proc);
            fflush(hd_proc);
            pclose(hd_proc);
        }
    }
}

void rv_simulator_pprint_registers(rv_simulator_t* sim) {
    printf("Registers:\n");
    for (int r = 0; r < 32; ++r) {
        printf("\t\x1b[31mx%d\x1b[0m/%s = \x1b[32m%d\x1b[0m (0x%x)\n", r, REG_ABI_NAMES[r], (int32_t)sim->x[r], sim->x[r]);
    }
}

int rv_simulator_load_memory_from_file(rv_simulator_t* sim, const char* filename, rv_mem_filetype_t type, uint32_t offset) {
    FILE* binfile = fopen(filename, "r");
    if (binfile == NULL) {
        return -1;
    }

    fseek(binfile, 0, SEEK_END);
    int filesize = ftell(binfile);
    rewind(binfile);

    if (type == FILETYPE_AUTO) {
        int namelen = strlen(filename);
        char* suffix = &filename[namelen - 3];
        // BIN files are RAW! remember!
        if (strcmp(suffix, "txt") == 0) {
            printf("Detected input file format to be binary-text\n");
            type = FILETYPE_BINTXT;
        } else if (strcmp(suffix, "hex") == 0) {
            printf("Detected input file format to be hex\n");
            type = FILETYPE_HEXTXT;
        } else {
            printf("Could not detect input file format, treating as binary\n");
            type = FILETYPE_RAW;
        }
    }

    if (type == FILETYPE_RAW) {
        int binsize = filesize;
        uint8_t* buffer = (uint8_t*)malloc(binsize);

        int idx = 0;
        do {
            int n = fread(&buffer[idx], 1, binsize - idx, binfile);
            if (n == -1) {
                fprintf(stderr, "Error reading file!\n");
                return -4;
            }
            idx += n;
        } while (idx != binsize);
        fclose(binfile);

        if (rv_simulator_load_memory(sim, buffer, offset, binsize)) {
            free(buffer);
            return -2;
        }

        free(buffer);
        return binsize;

    } else if ((type = FILETYPE_HEXTXT) || (type == FILETYPE_BINTXT)) {
        int max_size = filesize / 2; // 2 Characters per hex byte
        uint8_t* contents = (uint8_t*)malloc(max_size);
        int byte_size = 0;

        char* line = NULL;
        size_t len;

        ssize_t n = 0;
        while ((n = getline(&line, &len, binfile)) != -1) {
            line[n - 1] = '\0';// Remove newline;
            uint32_t number = (uint32_t)strtol(line, NULL, type == FILETYPE_HEXTXT ? 16 : 2);
            // printf("@%x = %x\n", byte_size, number);
            // Little endian
            contents[byte_size++] = (number >> 0) & 0xFF;
            contents[byte_size++] = (number >> 8) & 0xFF;
            contents[byte_size++] = (number >> 16) & 0xFF;
            contents[byte_size++] = (number >> 24) & 0xFF;
        }

        fclose(binfile);

        if (rv_simulator_load_memory(sim, contents, offset, byte_size)) {
            free(contents);
            return -2;
        }

        free(contents);
        return byte_size;
    }

}

uint8_t rv_simulator_monolithic_memory_read(void* mmem, uint32_t addr) {
    rv_simulator_monolithic_memory_t* mem = (rv_simulator_monolithic_memory_t*)mmem;
    if (addr < mem->size) {
        return mem->data[addr];
    } else {
        if (RV_SIM_VERBOSE) printf("Monolithic memory: attempted read out of memory bounds (read @ %x)\n", addr);
        return 0;
    }
}

void rv_simulator_monolithic_memory_write(void* mmem, uint32_t addr, uint8_t data) {
    rv_simulator_monolithic_memory_t* mem = (rv_simulator_monolithic_memory_t*)mmem;
    if (addr < mem->size) {
        mem->data[addr] = data;
    } else {
        if (RV_SIM_VERBOSE) printf("Monolithic memory: attempted write outside of memory bounds (write %x @ %x)\n", data, addr);
    }
}

void rv_simulator_monolithic_memory_init(rv_simulator_monolithic_memory_t* mmem, uint32_t size) {
    mmem->size = size;
    mmem->data = (uint8_t*)calloc(size, 1);
}

void rv_simulator_monolithic_memory_deinit(rv_simulator_monolithic_memory_t* mmem) {
    free(mmem->data);
    mmem->size = 0;
}

/// @brief Finds the index of the memory segment containing a certain address
/// @param segmem Segmented memory instance pointer
/// @param address Address to search for
/// @return -1 if no segments were found containing `address`, otherwise, returns the first segment containing `address`
int _rv_simulator_segmented_memory_find_segment(rv_simulator_segmented_memory_t* segmem, uint32_t address) {
    // TODO: This could be optimized with a binary search if all segments are stored in increasing order
    for (int i = 0; i < segmem->n_segments; ++i) {
        if (address >= segmem->segments[i].start_address && address < (segmem->segments[i].start_address + segmem->segments[i].size)) {
            return i;
        }
    }
    return -1;
}

uint8_t rv_simulator_segmented_memory_read(void* sptr, uint32_t addr) {
    rv_simulator_segmented_memory_t* segmem = (rv_simulator_segmented_memory_t*)sptr;
    int segnum = _rv_simulator_segmented_memory_find_segment(segmem, addr);
    if (segnum < 0) {
        if (RV_SIM_VERBOSE) printf("Segmented memory: attempted read out of memory bounds (read @ %x)\n", addr);
        return 0;
    } else {
        return segmem->segments[segnum].data[addr - segmem->segments[segnum].start_address];
    }
}
void rv_simulator_segmented_memory_write(void* sptr, uint32_t addr, uint8_t data) {
    rv_simulator_segmented_memory_t* segmem = (rv_simulator_segmented_memory_t*)sptr;
    int segnum = _rv_simulator_segmented_memory_find_segment(segmem, addr);
    if (segnum < 0) {
        if (RV_SIM_VERBOSE) printf("Segmented memory: attempted write outside of memory bounds (write %x @ %x)\n", data, addr);
    } else {
        rv_simulator_segmented_memory_segment_t* segment = &segmem->segments[segnum];
        if (segment->readonly) {
            if (RV_SIM_VERBOSE) printf("Segmented memory: attempted write to read only memory segment (write %x @ %x, segment tag '%s')\n", data, addr, segment->tag);
        } else {
            segment->data[addr - segment->start_address] = data;
        }
    }
}
void rv_simulator_segmented_memory_init(rv_simulator_segmented_memory_t* segmem) {
    segmem->n_segments = 0;
    // Allocate space for one segment initially
    segmem->segments = (rv_simulator_segmented_memory_segment_t*)calloc(0, sizeof(rv_simulator_segmented_memory_segment_t));
}
void rv_simulator_segmented_memory_add_segment(rv_simulator_segmented_memory_t* segmem, uint32_t start_address, uint32_t size, const char* name, bool readonly) {
    rv_simulator_segmented_memory_segment_t segment = {
        .data = calloc(size, 1),
        .readonly = readonly,
        .size = size,
        .start_address = start_address,
        .tag = name
    };

    // Allocate space for another segment
    segmem->segments = realloc(segmem->segments, (segmem->n_segments + 1) * sizeof(rv_simulator_segmented_memory_segment_t));
    segmem->segments[segmem->n_segments++] = segment;
}
void rv_simulator_segmented_memory_deinit(rv_simulator_segmented_memory_t* segmem) {
    for (int i = 0; i < segmem->n_segments; ++i) {
        free(segmem->segments[i].data);
    }
    free(segmem->segments);
    segmem->n_segments = 0;
}

rv_simulator_segmented_memory_segment_t* rv_simulator_segmented_memory_get_segment(rv_simulator_segmented_memory_t* segmem, uint32_t index) {
    return &segmem->segments[index];
}