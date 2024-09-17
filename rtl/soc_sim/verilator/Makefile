VERILOG_DIR=../..
HDL_FILES=$(VERILOG_DIR)/soc_sim/soc_sim.sv $(VERILOG_DIR)/alu/alu.sv $(VERILOG_DIR)/common/memory.sv $(VERILOG_DIR)/cpu/cpu.sv 
SIM_DIR=../../../software/simulator
ASSEMBLER=$(SIM_DIR)/asm2bin.py
PROGRAM_FILE=../../../software/programs/assembly/test_program.S

.PHONY: run

run:  obj_dir/Vsoc_sim obj_dir/memory.bin
	obj_dir/Vsoc_sim -v -d -l256 obj_dir/memory.bin

obj_dir/memory.bin: $(PROGRAM_FILE)
	$(ASSEMBLER) $(PROGRAM_FILE) --bin -o obj_dir/memory.bin

obj_dir/Vsoc_sim: generate
	$(MAKE) -C obj_dir -f Vsoc_sim.mk Vsoc_sim

generate: main.cpp $(HDL_FILES)
	verilator -cc -I$(VERILOG_DIR) -I$(VERILOG_DIR)/common --trace --no-trace-params --top soc_sim $(HDL_FILES) --exe main.cpp ../$(SIM_DIR)/build/rv32i_simulator.o