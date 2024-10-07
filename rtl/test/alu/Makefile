obj_dir/Valu: obj_dir/Valu.cpp
	$(MAKE) -C ./obj_dir -f Valu.mk Valu

obj_dir/Valu.cpp: ./tb.cpp
	verilator -cc -I../../common ../../alu/alu.sv --trace --no-trace-params --top alu --exe ./tb.cpp

.PHONY: clean
clean:
	rm -rf ./obj_dir