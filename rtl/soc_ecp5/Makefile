PROJNAME=soc_ecp5
SYNTH_SRCS=../cpu/cpu.sv ../cpu_v2/cpu_pipelined.sv ../alu/alu.sv ./$(PROJNAME).sv ../common/memory.sv ../common/bus_hub_4.sv ../common/bus_hub_2.sv ../common/bus_hub_3.sv ../common/bus_hub_5.sv ../fpga/parallel_port.sv ../fpga/spi.sv ../graphics/rtl/bw_textmode_gpu.sv ../graphics/rtl/vga_pll.sv ../graphics/rtl/fontROM.sv ../graphics/rtl/color_textmode_gpu.sv
COMMONDIR=../common

PACKAGE=CABGA256
LFP=$(PROJNAME).lpf

MEMSIZE=8192

all: build/$(PROJNAME).svf build/$(PROJNAME).bit

build/$(PROJNAME).json: $(SYNTH_SRCS) build/phony.hex
	yosys -q -p "read_verilog -I./ -I$(COMMONDIR) -I../gpu/rtl -sv $(SYNTH_SRCS); synth_ecp5 -no-rw-check -abc9 -top $(PROJNAME) -json $@;" 
#	yosys -q -p 'read_verilog $(SYNTH_SRCS); synth_ecp5 -top $(PROJNAME) -abc9 -json $@'

build/$(PROJNAME).config: build/$(PROJNAME).json $(LPF)
	nextpnr-ecp5 --25k --package $(PACKAGE) --speed 6 --lpf $(LFP) --json build/$(PROJNAME).json --textcfg build/$(PROJNAME).config

build/$(PROJNAME).svf: build/$(PROJNAME).config
	ecppack --compress --input $< --svf $@

build/$(PROJNAME).bit: build/$(PROJNAME).config
	ecppack --compress --input $< --bit $@

build/phony.hex:
	ecpbram -g build/phony.hex -w 32 -d $(MEMSIZE)

# build/blink_tb: $(SIM_SRCS)
# 	iverilog -I `yosys-config --datdir/ecp5/` `yosys-config --datdir/ecp5/cells_sim.v` $(SIM_SRCS) -o $@

# build/blink_tb.vcd: build/blink_tb
# 	build/blink_tb

prog: build/$(PROJNAME).bit
	ecpprog -S $<

flash: build/$(PROJNAME).bit
	openFPGALoader --vid 0x0403 --pid 0x6010 --unprotect-flash -f build/$(PROJNAME).bit

clean:
	rm -f build/*


