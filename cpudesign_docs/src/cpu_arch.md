# CPU implementation.

This project contains two separate implementations, two separate fully functional processors.
- The first, a simple multi-cycle, non-pipeline design, is designed with logic space in mind and has been optimized to be able to fit on small inexpensive FPGAs (ICE40 UP or HX).
- The second design is a more complex pipeline design, designed for performance rather than logic size, and as of the moment cannot fit on any of my small inexpensive FPGA and additionally requires dual port random access memory for a Von Neumann architecture.
  - With dual port memory, this pipeline processor can fuse the program and data (bus access) ports into operating on the same memory space.
  - With single-port RAM, data and program memory must be split (Harvard)

## ALU
Both of these CPUs rely on a shared arithmetic logic unit implementation, which handles all numerical and arithmetic instructions in the RV32IM instruction set (including those of the multiplication and division extension)
The arithmetic logic unit is a compromise between speed and logic size.
- A few logic size reduction techniques are used
  - Single barrel shifter for both left and right shifts, rather than two, (result: less LUTs, increased critical path length) 
  - Sharing a single multiplier for the various different multiplication instructions with input and output multiplexers. (result: less hardware multipliers/LUTs, increased critical path length) 

The ALU takes input of:
- both operands for the instruction (immediates/registers are multiplexed in the CPU's control logic)
- a flag indicating whether the instruction contains an immediate value or not (affects decoding)
- a ready flag (start signal)
- `funct3` and `funct7` sections of the decoded instruction
To produce a 32-bit output as well as a done flag (which is always asserted unless a division instruction is requested in which the done flag will stay low until the division procedure has completed).

The ALU implements a 32-cycle division process which is designed more with logic size and simplicity in mind rather than performance.

## Non-Pipelined CPU (V1)
The non-pipelined CPU is a state machine that progresses through four separate stages to execute a single instruction.
- Note: some instructions only use three of the four stages.

### 1. Fetch
The instruction fetch stage uses the CPU's bus host interface to read a 32-bit instruction from the current program counter and decodes various immediate values and instruction parameters. The fetch stage also loads the values of any operand registers if applicable.

### 2. Decode
In the decode stage:
- Operands are loaded into the ALU and ALU control signals are set.
- Branch conditions are calculated and the load store address is calculated if applicable.
- The ALU is signaled to be ready to start completing its function
- The control logic of the CPU decides whether to progress to the execute or write back stage.
  - Only multi-cycle ALU instructions, load instructions, and store instructions require the execute stage.
  - If the execute stage is not required, the instruction pipeline skips the execute stage and goes directly to writeback.

### 3. Execute
The execute stage's sole function is to wait for completion of either an ALU operation or a memory transaction which was started in the decode stage.
The CPU will simply stay in execute until said transaction completes and will then progress to the write back stage.

### 4. Write-Back
In the write back stage:
  - The program counter is updated to the next calculated program counter (whether that is the current program counter + 4 or a specific jump or branch program counter, which is calculated combinationally)
  - Signals the ALU to flush any data currently stored
  - Writes the current calculated value to a destination register if applicable.
    - This write back value is multiplexed from the ALU, memory loads, and immediates.
    - 
In the write back stage, the processor also asserts an "instruction sync" signal which is used only internally for verification of the processor. (synchronization with the simulator)

This processor can achieve ~4.7 MIPS (Mega-Instructions Per Second) running the Dhrystones benchmark at 25 megahertz on a Lattice ICE40 UP5K FPGA (Upduino board) and meets timing requirements for such.

## Pipelined CPU (V2)

The second version of the CPU in this project is a pipelined version of my original processor - a complete rewrite, and is optimized for speed and simplicity rather than for logic size.

### Understanding of Pipelining

While I was writing the first version of the processor, my goal was to minimize logic size and be able to run it on a small FPGA rather than to have a high-performing core. During my research, I was intrigued by the idea of pipelining and being able to get so much more performance out of the same architecture by using a different structure and implementation inside of the CPU. I thought that it would be an arduous task to implement a pipelined processor, but once I made sense of what pipelining really was, it was quite intuitive.

The way I think about it, pipelining is like doing your laundry.
- My non-pipelined CPU is like putting dirty clothes in the washer, washing them, taking them out, putting them in the dryer, drying them, taking them out of the dryer, and hanging them up on your clothes rack before going and putting the next load in the washer.
- Pipelining is doing laundry how you normally do laundry.
  - Take dirty clothes put them in the washer.
  - when that's done, take whatever is in the dryer and set it aside
  - then you take what was in the washer, you put it in the dryer, you put a new load in the washer, and you start both of them at the same time.

Doing laundry is a simple real-world example of a two-stage pipeline that helped me develop a lot of the intuition necessary for putting together this pipelined implementation.

### Implementation

The way I've implemented my pipeline processor is with four separate stages:
- Fetch 
- Decode 
- Execute
- Write-Back

Wait, those are the same as in the non-pipelined version? how can that be?
In this version, the stages are not part of a state machine, but rather separate entities that work in parallel and move data through every clock cycle.
- Each stage has registers to maintain the state of that stage
- Wvery clock cycle, each stage of the pipeline checks if the next stage is open, and if so, shifts the data forwards one step in the pipeline.
- Stages can block (stall) to prevent data from being shifted in when work is not done in aforementioned stage

The most important things necessary for proper operation the pipelined processor are the status flags in each stage that signal whether that stage has valid data that's being processed, and whether that stage will be "open" at the next clock cycle to shift data into.
These status flags are either registered (for indicating valid data) or combinationally determined values (in the case of whether the stage is open or not for new data). Some stages such as the execute stage can block for multiple cycles (when operation such as division is happening in the ALU).

### Pipelined Memory Model
One of the more unique things about my pipelined processor is the memory architecture.
I didn't really like the idea of having a (modified) Harvard architecture with separated program and data, which is typical for pipelined processors. (modified Harvard uses shared program/data main memory, but has split program/data caches, and is more complexity than I would like for this project)
For this project, and consistency between the pipelined and non-pipelined versions of the CPU, I would much rather have a Von Neumann architecture where program and data memory are one and the same.

To accomplish this while still being synthesizable for the target FPGA (ECP5, for this pipelined version), I had to use a few tricks.
- The memory for this processor (and SoC) is contained *within* the CPU logic.
- Rather than having a bus-host interface for the memory, this processor has both a host port (peripherals/memory), and a device port that uses one of the read/write ports on the dual-port RAM used for program and data
- The other port of the dual-port RAM is used internally to the CPU for reading program data.

#### Fetch
In the fetch stage of my processor, the next program counter is determined, whether that is simply the next program counter in the sequence, or possibly a branching program counter if there is a branch instruction in the write back stage.
- A single word, the instruction, is read from directly from the memory contained within the CPU and passed into the decode stage if the decode stage is open.
- There are many checks in place that need to be in the correct state before the fetch stage actually puts data into the decode stage.
  - Decode stage needs to be open for data (that is, none of the pipeline stages after it are stalled)
  - The fetch stage does not put any data in the decode stage if there is a data-dependency of the instruction (an instruction that requires a register value that has not yet been written by the pipeline)
    - Exception: register forwarding (we'll get to that later) and 
  - The fetch stage will not place data in the decode stage if "unsafe execution" is occurring.

"Unsafe execution" is defined in this implementation as there being an instruction in the decode, execute, or write back stage that will affect the program counter of the next executed instruction (a branch or a jump instruction).
This processor does not implement any sort of branch prediction for simplicity, so all branches and jump instructions are treated as possibly changing the program counter, and thus, unsafe execution.

#### Decode
Once an instruction reaches the decode stage, the opcode, various immediates, as well as register values are decoded *into* the execute stage. Although most of these values could be combinationally determined, I have found that doing so in the decode stage improves the timing characteristics by having more flip-flops in the data path (which reduces the critical path length for these signals).

Note: in the decode, execute and, write back stage, flags are raised (combinationally determined) for whether the instruction in each stage has a data dependency or is unsafe. These flags are used by the fetch stage to determine whether instructions should be flowing into the pipeline or not.

#### Execute
Once the instruction reaches the execute stage, it is further decoded into the ALU control signals. Register operands and immediates are multiplexed into the ALU inputs and bus interface.
The execute stage is the only stage in the pipeline that can stall, and it will do so if the ALU takes multiple cycles to execute the instruction (division) or if the bus is held (not finished) for multiple cycles during a read or write.

Note: if using the dual-port memory built in to the CPU the execute stage will never take more than one cycle for loads and stores.

#### Write-Back
When the execute stage is finished, data from the execute stage is written into the write back stage.
Note: The write back stage is always open and never blocks.

The write-back stage's task is to:
- write back the currently calculated result into a destination register (if applicable)
- forward any possible program counter changes back to the fetch stage so execution can resume after a conditional branch or jump.


### Register Forwarding
One performance enhancing feature that I have added is [register forwarding](https://courses.cs.washington.edu/courses/cse378/07au/lectures/L12-Forwarding.pdf).

If there is a data dependency detected, instructions will still progress from the fetch stage to the decode stage and rather than the fetch stage waiting until a data dependency is resolved, the decode stage will wait (only one cycle) and then load data not from registers but directly from the result of the execute stage. This optimization saves one clock cycle in the case of consecutive instructions with a data dependency and increases the performance of this implementation by a significant factor without adding significant complexity.

Forwarding is accomplished through a number of simple checks on the indices of registers present in the execute and decode stage of the processor and multiplexing forwarded values with register reads in the decode stage.

Note: 
- The memory inside of the pipelined version of the processor is initializable when used on certain FPGA targets (ECP5).
- Currently this processor only supports the Lattice ECP5 FPGA because it's the only FPGA I could get my hands on (cheap enough) that was large enough to synthesize and run a SoC with this processor on.
- The base configuration of this pipeline processor does not require a bus switch with no peripherals.
  - Bus host port of the processor can just be connected to the bus device port (that is, the memory access port) of the processor and it can run as an entirely self-contained system.
- For peripherals a bus hub must be inserted between the host and device ports of the memory on the processor itself, and any number of peripherals can be connected using the exact same bus architecture as the non pipeline version of the processor.