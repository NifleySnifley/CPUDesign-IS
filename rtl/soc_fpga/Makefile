COMMONDIR=../common
BUILDDIR=./build

DEFAULT_PROGRAM=program.S
MEMSIZE=2048
 # --pad $$(($(MEMSIZE) * 4))
ASSEMBLER=../../software/simulator/asm2bin.py --hex --assemble
BINARY=$(BUILDDIR)/program.hex

DEVICE=hx8k # Upduino: up5k, iceFUN: hx8k
PACKAGE=cb132 # Upduino: sg48, iceFUN: cb132
PROGTOOL=iceFUNprog #Upduino: "iceprog -d i:0x0403:0x6014", iceFUN: iceFUNprog

PROJNAME=soc_iceFUN
SRCFILES=../cpu/cpu.sv ../alu/alu.sv ./$(PROJNAME).sv ../common/memory.sv ../common/bus_hub_*.sv ../fpga/parallel_port.sv
TOPNAME=$(PROJNAME)
PNR_ARGS=--$(DEVICE) --package $(PACKAGE) --json $(BUILDDIR)/$(PROJNAME).json --pcf ./$(PROJNAME).pcf --asc $(BUILDDIR)/$(PROJNAME)_base.asc

# THIS is where programming happens!
.PHONY: $(BUILDDIR)/$(PROJNAME).bin
$(BUILDDIR)/$(PROJNAME).bin: $(BUILDDIR) $(BUILDDIR)/$(PROJNAME)_base.asc $(BINARY)
	icebram $(BUILDDIR)/phony.hex $(BINARY) < $(BUILDDIR)/$(PROJNAME)_base.asc > $(BUILDDIR)/$(PROJNAME).asc
	icepack $(BUILDDIR)/$(PROJNAME).asc $(BUILDDIR)/$(PROJNAME).bin

$(BUILDDIR)/$(PROJNAME)_base.asc: $(BUILDDIR) $(BUILDDIR)/$(PROJNAME).json ./$(PROJNAME).pcf 
	nextpnr-ice40 $(PNR_ARGS)

$(BUILDDIR)/$(PROJNAME).json: $(BUILDDIR) $(SRCFILES) $(BUILDDIR)/phony.hex
	yosys -q -p "read_verilog -I./ -I$(COMMONDIR) -sv $(SRCFILES); synth_ice40 -top $(TOPNAME) -json $(BUILDDIR)/$(PROJNAME).json" 

$(BUILDDIR)/phony.hex: $(BUILDDIR)
	icebram -g 32 $(MEMSIZE) > $(BUILDDIR)/phony.hex

$(BINARY): $(BUILDDIR) $(DEFAULT_PROGRAM)
	$(ASSEMBLER) $(DEFAULT_PROGRAM) -o $(BINARY)

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
	$(RM) -rf $(BUILDDIR)