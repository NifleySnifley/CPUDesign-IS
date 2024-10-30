# CPU V1

The simplest multi-cycle design I could come up with. Uses the common ALU supporting the `M` extension

- Reads program data using the bus
- Memory and IO access using the bus
- 4-stage FSM
  - Fetch - read instruction from the bus
  - Decode - load registers and immediates
  - Execute - wait for execution (ALU/bus) to finish (skipped for combinational ALU operations).
  - Writeback - register store, set next PC
- Not at all efficient
- Very simple implementation of RISC-V basics
- Efficient LUT usage/logic size