# .PHONY: apio
# apio: build/icefun.pcf build/soc_fpga.v build/apio.ini
# 	cd build && apio build --verbose-pnr && apio upload

# build/soc_fpga.v: build $(SV_FILES) ../../software/programs/assembly/test_program.txt
# 	sv2v --siloed $(SV_FILES) -w build/soc_fpga.v

# .PHONY:../../software/programs/assembly/test_program.txt
# ../../software/programs/assembly/test_program.txt: ../../software/programs/assembly/test_program.S
# build/apio.ini: build apio.ini
# 	cp ./apio.ini ./build/apio.ini

# build/icefun.pcf: build icefun.pcf
# 	cp ./icefun.pcf ./build/icefun.pcf

# build:
# 	mkdir -p build

ASSEMBLER=../../software/simulator/asm2bin.py
PROGRAM=program.S

COMMONDIR=../common
BUILDDIR=./build

DEVICE=hx8k # Upduino: up5k, iceFUN: hx8k
PACKAGE=cb132 # Upduino: sg48, iceFUN: cb132
PROGTOOL=iceFUNprog #Upduino: "iceprog -d i:0x0403:0x6014", iceFUN: iceFUNprog

SRCFILES=../cpu/cpu.sv ../alu/alu.sv ./soc_fpga.sv ../common/memory.sv ../common/bus_hub_1.sv ../common/bus_hub_2.sv ../fpga/parallel_port.sv
PROJNAME=soc_fpga
TOPNAME=$(PROJNAME)
PNR_ARGS=--$(DEVICE) --package $(PACKAGE) --json $(BUILDDIR)/$(PROJNAME).json --pcf ./$(PROJNAME).pcf --asc $(BUILDDIR)/$(PROJNAME).asc

$(BUILDDIR)/$(PROJNAME).bin: $(BUILDDIR) $(BUILDDIR)/$(PROJNAME).asc 
	icepack $(BUILDDIR)/$(PROJNAME).asc $(BUILDDIR)/$(PROJNAME).bin

$(BUILDDIR)/$(PROJNAME).asc: $(BUILDDIR) $(BUILDDIR)/$(PROJNAME).json ./$(PROJNAME).pcf 
	nextpnr-ice40 $(PNR_ARGS)

$(BUILDDIR)/$(PROJNAME).json: $(BUILDDIR) $(SRCFILES) $(BUILDDIR)/program.txt
	yosys -q -p "read_verilog -I./ -I$(COMMONDIR) -sv $(SRCFILES); synth_ice40 -top $(TOPNAME) -json $(BUILDDIR)/$(PROJNAME).json" 

$(BUILDDIR)/program.txt: $(PROGRAM)
	$(ASSEMBLER) $(PROGRAM) -o $(BUILDDIR)/program.txt

$(BUILDDIR):
	mkdir -p $(BUILDDIR)

.PHONY: view
view:
	nextpnr-ice40 $(PNR_ARGS) --gui


.PHONY: flash
flash:
	$(PROGTOOL) $(BUILDDIR)/$(PROJNAME).bin

.PHONY: clean
clean:
	$(RM) -f $(BUILDDIR)/$(PROJNAME).json $(BUILDDIR)/$(PROJNAME).asc $(BUILDDIR)/$(PROJNAME).bin