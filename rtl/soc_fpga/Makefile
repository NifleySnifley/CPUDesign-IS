SV_FILES=../common/defs.sv ../cpu/cpu.sv ../alu/alu.sv ../common/memory.sv ./soc_fpga.sv

.PHONY: apio
apio: build/icefun.pcf build/soc_fpga.v build/apio.ini
	cd build && apio build && apio upload

build/soc_fpga.v: build $(SV_FILES) ../../software/programs/assembly/test_program.txt
	sv2v --siloed $(SV_FILES) -w build/soc_fpga.v

.PHONY:../../software/programs/assembly/test_program.txt
../../software/programs/assembly/test_program.txt: ../../software/programs/assembly/test_program.S
	../../software/simulator/asm2bin.py ../../software/programs/assembly/test_program.S

build/apio.ini: build apio.ini
	cp ./apio.ini ./build/apio.ini

build/icefun.pcf: build icefun.pcf
	cp ./icefun.pcf ./build/icefun.pcf

build:
	mkdir -p build