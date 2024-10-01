icebram ./build/phony.hex $2 < $1 > ./build/loaded.asc
icepack ./build/loaded.asc ./build/loaded.bin
echo "Loaded Firmware $2 into bitstream $1"
iceprog ./build/loaded.bin