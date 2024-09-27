
**Accesing registers also takes one cycle! eeek!!! this is why pipelining is a thing......**
- Honestly, I'm excited to implement a simple pipeline (stall on hazards)
### Components:
- ALU (functs, input -> operation)
	- All arithmetic instructions and shifts

Types of instructions:
- According to `learn_fpga`'s FemtoRV
	- branch
		- All conditionals can be determined combinatorically from decoded instruction & regs?
		- Might need reg loading time??
	- ALU reg
		- Yes, all ALU can do same with an ALU commanded from decoded instruction
		- I think I could do immediate and reg ALU instructions the same, just with a mux for immediate v/s reg
	- ALU imm
		- Same
	- Load
		- Yeah, needs state for timeful reads too
		- Bytes & count can be combinatorically determined
		- Need multiple cycles/state for multi byte? (8-bit memory bus)
		- Otherwise, 32 bit wide memory bus for unaligned reads also needs state
	- Store
		- Same as load, takes time!
		- with 32-wide bus, need to determine a way tko set write type?
		- Otherwise, need state to read & write with slicing.
	- LUI
		- Not hard at all, imm -> reg
	- AUIPC
		- LUI with muxed in 0 v/s PC (same as LUI basically?)
	- JAL/JALR
		- Same, just different targets, can be determined combinatorically
	- Fence: **NOT NEEDED!**
	- System
		- Would be nice to have hardware support for breakpoints!

>there is also a `funct7` field (7 MSBs of instruction word). Bit
 30 of the instruction word encodes `ADD`/`SUB` and `SRA`/`SRL`
 - FemtoRV

Good to know for ALU!

#### Very nice table about the imm encodings:

| Instr. type | Description                            | Immediate value encoding                             |
| ----------- | -------------------------------------- | ---------------------------------------------------- |
| `R-type`    | register-register ALU ops.             | None                                                 |
| `I-type`    | register-immediate ALU ops and `JALR`. | 12 bits, sign expansion                              |
| `S-type`    | store                                  | 12 bits, sign expansion                              |
| `B-type`    | branch                                 | 12 bits, sign expansion, upper `[31:1]` (bit 0 is 0) |
| `U-type`    | `LUI`,`AUIPC`                          | 20 bits, upper `31:12` (bits `[11:0]` are 0)         |
| `J-type`    | `JAL` (speshul)                        | 12 bits, sign expansion, upper `[31:1]` (bit 0 is 0) |
Instead of going for the flat (`isXXX`) approach of FemtoRV, I think I'd like to do a more heirarchical one (eg. logic to seperate different types of operations, then logic to use `funct3` and `funct4` to control lower operations)

### Big questions:
- How am I going to interface with memory? (word, half, byte!)
- Also, delays!
- **What the hell kind of black magic is used for caching? the synchronization must be a NIGHTMARE!!!**


Seems like adding support for the `C` extension (16-bit instructions) in the future wouldn't be that bad actually, all that would be neccesary would be a instruction "recoder" that translates the 16-bit instructions to their 32-bit counterparts, and knowing whether to advance PC by 2 rather than 4 if current PC is a 16-bit (easy).

**One-hot states!**

### Seperate memory from the start!!! (always make it r/w)
- Start out with a multi-cycle shifter, would be good to have the multi-cycle difficulty!

## State Machines!:
- Fetch instruction (load mem)
	- Set addr, wait for ready
- **Decode** (Fetch operands & immediates based on instruction encoding type, etc.)
	- Combinatorically generate inputs to ALU, shifter, memory load/save, etc?
- Execute
	- Depending on which tool (alu, shifter) used, wait for completion
	- Set PC to next neccesary value (++ or target)
	- state = fetcj
- Writeback (After execute, sort-of during next instruction fetch?)
	- Not always neccesary, check for rd in encoding type
	- Make sure not to write to x0 (hardwire it to 0 when reading to be super sure)
	- **Move PC here**

## Optimizations:
- One-hot states & decoding for instructions?
	- Get it working first, then speed up, then save on LUTs
- Save on the adder for AUIPC & JAL/JALR
	- Use the ALU? or just share an adder
- This bit of shifting code from FemtoRV is really neat
```verilog
wire [31:0] shifter =
	   $signed({instr[30] & aluIn1[31], shifter_in}) >>> aluIn2[4:0];
```
- Uses one arithmetic shifter (for selecting what bit is extended with), and full bit reversal (input and output) for shift direction.
- One-hot `funct3` for ALU
	- Split funct3 into shifted one-hot
	- Use ternaries, `32'b0`, and or-ing to select output
		- Saves LUTs on case-statement multiplexing

Optimize ALU later?
- Fancy sub comparison thing
- Many sub-wires and combinations (get as close to the LUTs as possible)


### Adding multiplication extension:
- https://msyksphinz-self.github.io/riscv-isadoc/html/rvm.html
	- Good info on the (slightly confusing) specification about signedness
	- rs1 is signed when: mul, mulh, mulhsu
	- rs2 is signed when: mul, mulh