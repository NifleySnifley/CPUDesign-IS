VERILOG_DIR=../..
HDL_FILES=$(VERILOG_DIR)/soc_sim/soc_sim.sv $(VERILOG_DIR)/alu/alu.sv $(VERILOG_DIR)/common/memory.sv $(VERILOG_DIR)/cpu/cpu.sv 

.PHONY: run

run: obj_dir/Vsoc_sim
	obj_dir/Vsoc_sim

obj_dir/Vsoc_sim: generate
	$(MAKE) -C obj_dir -f Vsoc_sim.mk Vsoc_sim

generate: main.cpp $(HDL_FILES)
	verilator -cc -I$(VERILOG_DIR) -I$(VERILOG_DIR)/common --trace --top soc_sim $(HDL_FILES) -GINITF="\"../../../software/programs/assembly/test_program.txt\"" --exe main.cpp