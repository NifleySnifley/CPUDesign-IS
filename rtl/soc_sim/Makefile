# Makefile
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
VERILOG_SOURCES += $(PWD)/soc_sim.sv $(PWD)/../cpu/cpu.sv $(PWD)/../alu/alu.sv $(PWD)/../common/memory.sv
# EXTRA_ARGS += --trace --trace-structs
WAVES=1

TOPLEVEL = soc_sim
# basename of the Python test file
MODULE = soc_tb

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim