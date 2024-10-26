ecpbram -f ./build/phony.hex -t $2 -i $1 -o ./build/loaded.config
ecppack --compress --input ./build/loaded.config --bit ./build/loaded.bit
echo "Loaded Firmware $2 into bitstream $1"
ecpprog -S ./build/loaded.bit
# openFPGALoader --vid 0x0403 --pid 0x6010 --unprotect-flash -f ./build/loaded.bit
