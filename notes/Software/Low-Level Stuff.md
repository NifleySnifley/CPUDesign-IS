### Support Library:
- `soc_core.h/c`
	- Provides basic newlib stubs (`_write` for IO, `_sbrk` for heap memory)
		- `_sbrk` relies on SPRAM, core configurations without SPRAM won't be able to use spram
	- Also provides `print` and `printchar` functions for basic text output
		- Currently uses the VGA text-mode adapter as a basic terminal
	- `delay_ms` for sleeping
		- Uses some approximate calculations, but it's pretty accurate from the limited testing I've done (inspected IO pin toggling with oscope)
- `soc_io.h`
	- Addresses & other things for parallel port and VGA graphics

### crt0
- Initializes stack pointer (defined in linker script)
- Zeros out `.bss` (defined in linker script)
- Calls main function
- Linker script
	- Based primarily on information from here: https://blog.thea.codes/the-most-thoroughly-commented-linker-script/ (this was so helpful for learning!)
- Borrowed a lot of basic stuff from this `crt0`:
	- https://github.com/pulp-platform/pulpino/blob/master/sw/ref/crt0.riscv.S

### Plans:
- External program bootloader (stored in BRAM)
	- BRAM is pretty small, so it would be great to copy a program from some external ROM (SPI flash, EEPROM, SD card, etc.)
	- Copy data from ROM to SPRAM, and then jump to the start of SPRAM
	- Might require a new linker script for programs loaded with the bootloader
		- (because SPRAM contains program as well as stack and heap)
		- Just do `.text` & `.data`, then stack (find a way to safely prevent overflow into program section?), then heap. Set heap and stack offsets based on program size!!!