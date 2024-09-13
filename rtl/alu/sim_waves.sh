iverilog -g2012 -s tb_alu -DBENCH -DBOARD_FREQ=10 alu_waves.sv -o tb.vvp
vvp ./tb.vvp