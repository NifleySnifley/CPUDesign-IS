.PHONY: run

run: tb
	vvp tb

tb: tb.v add_sub.v
	iverilog -stb -DBENCH -DBOARD_FREQ=10 tb.v add_sub.v -o tb