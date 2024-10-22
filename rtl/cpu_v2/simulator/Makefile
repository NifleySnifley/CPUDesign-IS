VERILOG_DIR=../..
HDL_FILES=cpu_pl_soc.sv $(VERILOG_DIR)/alu/alu.sv $(VERILOG_DIR)/common/memory.sv $(VERILOG_DIR)/common/memory_spram.sv  $(VERILOG_DIR)/cpu_v2/cpu_pipelined.sv $(VERILOG_DIR)/common/bus_hub_1.sv
SIM_DIR=../../../software/simulator
ASSEMBLER=$(SIM_DIR)/asm2bin.py
PROGRAM_FILE=../tests/program.S

.PHONY: run

run:  obj_dir/Vcpu_pl_soc obj_dir/memory.bin
	obj_dir/Vcpu_pl_soc -v -d -l256 -be -s -t soc_sim.vcd obj_dir/memory.bin

obj_dir/memory.bin: $(PROGRAM_FILE)
	$(ASSEMBLER) $(PROGRAM_FILE) --raw --assemble -o obj_dir/memory.bin

obj_dir/Vcpu_pl_soc: generate
	$(MAKE) -C obj_dir -f Vcpu_pl_soc.mk Vcpu_pl_soc

generate: main.cpp $(HDL_FILES)
	verilator -cc -I$(VERILOG_DIR) -I../ -I$(VERILOG_DIR)/common --trace-structs --trace-depth 10 --trace --no-trace-params --top cpu_pl_soc $(HDL_FILES) --exe main.cpp ../$(SIM_DIR)/build/rv32i_simulator.o