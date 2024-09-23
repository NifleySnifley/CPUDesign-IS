#ifndef RV32I_SIMULATOR_H
#define RV32I_SIMULATOR_H

#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>

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

/// @brief Official RISC-V ABI names for each of the 32 registers.
extern const char* REG_ABI_NAMES[32];

/// @brief Instruction trace function for `rv_simulator_t->instr_trace`
typedef void (*rv_sim_instr_trace_fn_t) (void*, const char*);
/// @brief Conditional branch result trace function for `rv_simulator_t->cond_trace`
typedef void (*rv_sim_cond_trace_fn_t) (void*, bool);
/// @brief Error trace function for `rv_simulator_t->err_trace`
typedef void (*rv_sim_err_trace_fn_t) (void*);

/// @brief Function used by \ref rv_simulator_t for reading bytes from memory
typedef uint8_t(*rv_sim_read_fn_t) (void*, uint32_t);
/// @brief Function used by \ref rv_simulator_t for writing bytes from memory
typedef void (*rv_sim_write_fn_t) (void*, uint32_t, uint8_t);

/// @brief Function used by \ref rv_simulator_t for breakpoints
typedef void (*rv_sim_breakpoint_fn_t) (void*);
/// @brief Function used by \ref rv_simulator_t for syscalls (`ecall`)
typedef void (*rv_sim_syscall_fn_t) (void*);

#define TRACE_INSTR(simptr, name) if (simptr->instr_trace != NULL) {(simptr->instr_trace)((void*)simptr, name);}
#define TRACE_COND(simptr, bval) if (simptr->cond_trace != NULL) {(simptr->cond_trace)((void*)simptr, bval);}
#define TRACE_ERROR(simptr) if (simptr->err_trace != NULL) {(simptr->err_trace)((void*)simptr);}

// TODO: Move this to a proper hook function
#ifndef TRACE_ARGUMENTS
#define TRACE_ARGUMENTS(src1, src2, dest, imm)
#endif

typedef enum rv_simulator_memory_type_t {
    MONOLITHIC,
    SEGMENTED,
} rv_simulator_memory_type_t;

typedef struct rv_simulator_memory_interface_t {
    /// @brief Hook function for memory reading. set to \ref rv_simulator_default_read by default
    rv_sim_read_fn_t read_byte_fn;
    /// @brief Hook function for memory writing. set to \ref rv_simulator_default_write by default
    rv_sim_write_fn_t write_byte_fn;

    /// @brief Type of current memory being used
    rv_simulator_memory_type_t type;

    /// @brief User-defined pointer to underlying implementation of the memory
    void* memory;
}rv_simulator_memory_interface_t;

// /// @brief Structure used by the segmented memory implementation representing a single, contiguous region of memory attached to the simulated processor's bus.
// typedef struct rv_simulator_segmented_memory_segment_t {
//     /// @brief User-defined name for the memory segment
//     const char* tag;
//     /// @brief Start address of the memory segment
//     uint32_t start_address;
//     /// @brief Size (bytes) of the memory segment
//     uint32_t size;
//     /// @brief Pointer to the underlying storage used by the segment
//     uint8_t* memory;
// } rv_simulator_segmented_memory_segment_t;

/// @brief Monolithic (single contiguous) memory implementation for basic simulations
typedef struct rv_simulator_monolithic_memory_t {
    uint8_t* data;
    uint32_t size;
} rv_simulator_monolithic_memory_t;

uint8_t rv_simulator_monolithic_memory_read(void* mmem, uint32_t addr);
void rv_simulator_monolithic_memory_write(void* mmem, uint32_t addr, uint8_t data);

void rv_simulator_monolithic_memory_init(rv_simulator_monolithic_memory_t* mmem, uint32_t size);
void rv_simulator_monolithic_memory_deinit(rv_simulator_monolithic_memory_t* mmem);

/// @brief Structure representing the state and periphery of a simulated RISC-V processor.
typedef struct rv_simulator_t {
    /// @brief Register file (x0-x31). x0 will always be 0.
    union {
        uint32_t x[32];
        struct {
            uint32_t zero, ra, sp, gp, tp, t0, t1, t2, fp, s1, a0, a1, a2, a3, a4, a5, a6, a7, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, t3, t4, t5, t6;
        };
    };

    /// @brief Program-counter for the simulator
    uint32_t pc;

    /// @brief Trace function for instruction execution. `NULL` to disable instruction tracing
    rv_sim_instr_trace_fn_t instr_trace;
    /// @brief Trace function for branch results. `NULL` to disable branch tracing
    rv_sim_cond_trace_fn_t cond_trace;
    /// @brief Trace function for errors. `NULL` to disable error tracing
    rv_sim_err_trace_fn_t err_trace;

    /// @brief Memory interface structure containing implementation of the current memory model
    rv_simulator_memory_interface_t memory_interface;

    /// @brief Function executed on breakpoints
    rv_sim_breakpoint_fn_t bkpt_fn;
    /// @brief Function executed on system calls (`ecall` instruction)
    rv_sim_syscall_fn_t scall_fn;
} rv_simulator_t;

/// @brief Executes a single instruction (at sim->pc)
/// @param sim simulator
/// @return 0 on success, -1 on breakpoint, -2 on syscall, >0 on error
int rv_simulator_step(rv_simulator_t* sim);

/// @brief Loads bytes into the memory of \ref
/// @param sim simulator to load memory contents into
/// @param data desired memory content pointer
/// @param offset starting offset in memory to load memory into
/// @param count number of bytes to load
/// @return `false` on success `true` if data cannot fit inside `sim`'s" allocated memory
bool rv_simulator_load_memory(rv_simulator_t* sim, uint8_t* data, uint32_t offset, uint32_t count);


void rv_simulator_init_monolithic_memory(rv_simulator_t* sim, uint32_t mem_size);

// /// @brief Initializes simulator
// /// @param sim simulator
// /// @param mem_size size of memory (bytes) to allocate for the simulator, uses the monolithic memory implementation by default
// void rv_simulator_init_with_memory(rv_simulator_t* sim, uint32_t mem_size);

/// @brief Initializes simulator
/// @param sim simulator
void rv_simulator_init(rv_simulator_t* sim);

/// @brief Frees all resources allocated by `sim`
/// @param sim simulator
void rv_simulator_deinit(rv_simulator_t* sim);

/// @brief Prints current state of all registers
/// @param sim simulator
void rv_simulator_print_regs(rv_simulator_t* sim);

uint32_t rv_simulator_total_memory_size(rv_simulator_t* sim);

/// @brief Dumps the current state of `sim`'s registers to a file (CSV formatted)
/// @param sim simulator
/// @param file open, read-capable `FILE*` to write to
/// @return 0 on success, nonzero on error
int rv_simulator_dump_regs(rv_simulator_t* sim, FILE* file);
/// @brief Dumps the contents of `sim`'s memory to a file (binary)
/// @param sim simulator
/// @param file open, read-capable `FILE*` to write to
/// @return 0 on success, nonzero on error
int rv_simulator_dump_memory(rv_simulator_t* sim, FILE* file);

/// @brief Pretty-prints current state of `sim`'s memory using `hd` (`hexdump -C`)
/// @param sim simulator
void rv_simulator_pprint_memory(rv_simulator_t* sim);
/// @brief Pretty-prints current state of `sim`'s registers (with color!) including ABI names
/// @param sim simulator
void rv_simulator_pprint_registers(rv_simulator_t* sim);

#define rv_simulator_read_byte(simptr, idx) sim->memory_interface.read_byte_fn(sim->memory_interface.memory, idx)
#define rv_simulator_write_byte(simptr, idx, b) sim->memory_interface.write_byte_fn(sim->memory_interface.memory, idx, b)

/// @brief Loads memory contents from a binary file into simulator's memory
/// @param sim simulator to load into
/// @param filename path to the file containing binary memory contents
/// @return binary size on success, negative on error
int rv_simulator_load_memory_from_file(rv_simulator_t* sim, const char* filename);

#endif