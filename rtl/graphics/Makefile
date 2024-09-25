VERILOG_DIR=./rtl
HDL_FILES=$(VERILOG_DIR)/bw_textmode_gpu.sv
SIM_DIR=../../software/simulator

.PHONY: run

run:  obj_dir/Vbw_textmode_gpu
	obj_dir/Vbw_textmode_gpu

obj_dir/Vbw_textmode_gpu: generate
	$(MAKE) -C obj_dir -f Vbw_textmode_gpu.mk Vbw_textmode_gpu

generate: gpu_sim.cpp $(HDL_FILES)
	verilator -cc -I$(VERILOG_DIR) -I$(VERILOG_DIR)/common -DSIM --trace --no-trace-params --top bw_textmode_gpu $(HDL_FILES) --exe gpu_sim.cpp -LDFLAGS -lSDL2 ../$(SIM_DIR)/build/rv32i_simulator.o