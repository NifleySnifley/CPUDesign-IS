ASMFILES := $(wildcard asm/*.S)
OUTPUTS := $(patsubst asm/%.S,build/%.bin,$(wildcard asm/*.S))
# .PHONY: $(OUTPUTS)

test: sim_tests.c $(OUTPUTS) build
	gcc $< ../build/rv32i_simulator.o -o ./build/test -lcheck -lsubunit -lm -I../src
	./build/test

$(OUTPUTS): $(ASMFILES) build
	python3 ./assembletests.py

build:
	mkdir -p ./build

clean:
	rm -rf ./build