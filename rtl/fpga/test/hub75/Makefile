# Makefile
SIM ?= verilator
TOPLEVEL_LANG ?= verilog
VERILOG_SOURCES += $(PWD)/../../hub75_driver.sv
EXTRA_ARGS += --trace --trace-structs

TOPLEVEL = hub75_driver
# basename of the Python test file
MODULE = test_hub75

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim