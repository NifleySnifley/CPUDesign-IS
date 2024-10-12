COMMONDIR=../common
BUILDDIR=./build

MEMSIZE=2560
 # --pad $$(($(MEMSIZE) * 4))
ASSEMBLER=../../software/simulator/asm2bin.py --hex --assemble
BINARY=../../software/programs/bootloader/build/bootloader_v2.hex

DEVICE=hx8k # Upduino: up5k, iceFUN: hx8k
PACKAGE=cb132 # Upduino: sg48, iceFUN: cb132
PROGTOOL=iceFUNprog #Upduino: "iceprog -d i:0x0403:0x6014", iceFUN: iceFUNprog
SYNTHARGS=-dsp

PROJNAME=soc_iceFUN
SRCFILES=../cpu/cpu.sv ../alu/alu.sv ./$(PROJNAME).sv ../common/memory_spram.sv ../common/memory.sv ../common/bus_hub_4.sv ../common/bus_hub_2.sv ../common/bus_hub_3.sv ../common/bus_hub_5.sv ../fpga/parallel_port.sv ../fpga/spi.sv ../graphics/rtl/bw_textmode_gpu.sv
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
	yosys -q -p "read_verilog -I./ -I$(COMMONDIR) -I../gpu/rtl -sv $(SRCFILES); proc; opt; fsm; opt; synth_ice40 $(SYNTHARGS) -top $(TOPNAME) -json $(BUILDDIR)/$(PROJNAME).json; opt" 

$(BUILDDIR)/phony.hex: $(BUILDDIR)
	icebram -g 32 $(MEMSIZE) > $(BUILDDIR)/phony.hex

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