PROJNAME=soc_ecp5
SYNTH_SRCS=../cpu_v2/cpu_pipelined.sv ../alu/alu.sv ./$(PROJNAME).sv ../common/bus_hub_2.sv ../fpga/parallel_port.sv
COMMONDIR=../common

PACKAGE=CABGA256
LFP=$(PROJNAME).lpf

MEMSIZE=8192

all: build/$(PROJNAME).svf build/$(PROJNAME).bit

build/$(PROJNAME).json: $(SYNTH_SRCS) build/phony.hex
# -no-rw-check 
	yosys -q -p "read_verilog -I./ -I$(COMMONDIR) -sv $(SYNTH_SRCS); synth_ecp5 -abc9 -no-rw-check -top $(PROJNAME) -json $@;" 
#	yosys -q -p 'read_verilog $(SYNTH_SRCS); synth_ecp5 -top $(PROJNAME) -abc9 -json $@'

build/$(PROJNAME).config: build/$(PROJNAME).json $(LPF)
	nextpnr-ecp5 --25k --package $(PACKAGE) --speed 6 --lpf $(LFP) --json build/$(PROJNAME).json --textcfg build/$(PROJNAME).config

build/$(PROJNAME).svf: build/$(PROJNAME).config
	ecppack --compress --input $< --svf $@

build/$(PROJNAME).bit: build/$(PROJNAME).config
	ecppack --compress --input $< --bit $@

build/phony.hex:
	ecpbram -g build/phony.hex -w 32 -d $(MEMSIZE)

lint:
	verilator --lint-only -DVERILATOR_LINT -Werror-UNUSED -Wall -Wno-DECLFILENAME -Wno-GENUNNAMED -I$(COMMONDIR) -I../ -I./ --top soc_ecp5 $(SYNTH_SRCS)

sim: 
	yosys -q -p "read_verilog -I./ -I$(COMMONDIR) -sv $(SYNTH_SRCS); script semisynth.ys; sim -resetn button -clock osc_clk25 -n 10000 -fst soc_ecp5_sim.fst soc_ecp5"

prog: build/$(PROJNAME).bit
	ecpprog -S $<

flash: build/$(PROJNAME).bit
	openFPGALoader --vid 0x0403 --pid 0x6010 --unprotect-flash -f build/$(PROJNAME).bit

clean:
	rm -f build/*


