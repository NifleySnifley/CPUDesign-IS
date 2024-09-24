make PROJNAME=soc_upduino BINARY=../../software/programs/test_embedded/build/main.hex PACKAGE=sg48 DEVICE=up5k
iceprog -d i:0x0403:0x6014 build/soc_upduino.bin
