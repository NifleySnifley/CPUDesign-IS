# Makefile
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
VERILOG_SOURCES += $(PWD)/alu.sv
# EXTRA_ARGS += --trace --trace-structs

TOPLEVEL = alu
# basename of the Python test file
MODULE = tb_alu

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim