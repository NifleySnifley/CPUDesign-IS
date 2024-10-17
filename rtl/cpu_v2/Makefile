VERILOG_DIR=../
HDL_FILES=./cpu_pipelined.sv $(VERILOG_DIR)/alu/alu.sv
SIM_DIR=../../software/simulator
ASSEMBLER=$(SIM_DIR)/asm2bin.py
PROJNAME=cpu_pipelined

.PHONY: run

run:  obj_dir/V$(PROJNAME)
	obj_dir/V$(PROJNAME) test_build/program.bin

obj_dir/V$(PROJNAME): generate
	$(MAKE) -C obj_dir -f V$(PROJNAME).mk V$(PROJNAME)

generate: pipeline_tester.cpp $(HDL_FILES)
	verilator -cc -I$(VERILOG_DIR) -I$(VERILOG_DIR)/common --trace-structs --trace-depth 10 --trace --no-trace-params --top $(PROJNAME) $(HDL_FILES) --exe pipeline_tester.cpp ../$(SIM_DIR)/build/rv32i_simulator.o