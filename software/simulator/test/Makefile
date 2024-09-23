

test: sim_tests.c assemble build
	gcc $< ../build/rv32i_simulator.o -o ./build/test -lcheck -lsubunit -lm -I../src
	./build/test

.PHONY: assemble
assemble: build
	python3 ./assembletests.py

build:
	mkdir -p ./build

clean:
	rm -rf ./build