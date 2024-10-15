HDL Options:
- Keep using (System)Verilog
- SpinalHDL? (learn more about this)

## Design:
- 4 Stages:
	- FETCH (load instruction from instruction cache, partially decode and transfer instruction into DECODE stage)
	- DECODE (load register values into EXECUTE stage)
	- EXECUTE (memory operations, run the ALU, **make PC changes**)
	- WRITEBACK (if necessary, write results to registers)