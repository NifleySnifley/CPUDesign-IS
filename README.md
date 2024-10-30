# RISC-V CPU Design Independent Study

Software, hardware designs, and notes from my CPU design/computer architecture independent study. The goal of this independent study project was to design a fully functional and standards-compliant RISC-V `rv32im` microprocessor and SoC.

## Current Achievements:

- Pipelined `rv32im` CPU and SoC capable of running on a ColorLight 5A-75B board (Lattice ECP5 LFE5U-25F) at 50MHz. 33.386 MIPS @ 50MHz, with the Dhrystone benchmark (1.5 CPI).

- Multi-cycle `rv32im` CPU and SoC capable of running on an Upduino board (Lattice ICE40UP5K) at 25MHz (overclocked). 4.7MIPS according @ 25MHz with the Dhrystone benchmark (5.32 CPI)

- 2-bit-color memory-mapped text mode VGA display adapter (640x480, 8x16 bitmap font, fg&bg color)

- Memory-mapped parallel IO and SPI host controller

- SPI Flash memory bootloader for Upduino SoC (flash memory->SPRAM)

- `rv32im` simulator written in C, side-by-side comparative verification by simulation of HDL designs (Verilator) alongside the software simulator. Running the official RISC-V `rv32im` test suite.

- SDL-based emulator for the Upduino SoC with VGA display emulation.

### Improvements

- [X] Add SRAM support as a bus device for stack memory

- [X] Pipelining (**eek**)

- [X] Caching & programs from external memory

- [ ] Compressed instruction decoding & support

- [ ] Branch prediction

### Features:

- [X] Test VGA peripheral (black & white text mode) graphics adapter

- [ ] Multicore? (A extension & other stuff)

- [X] M extension

- [ ] B extension

- [ ] CSRs for perf, interrupt control, core ID, etc.

- [ ] Interrupt support (learn more about the ISA in this aspect)

- [X] GPIO periperal

- [X] SPI / PWM / I2C, other peripherals, GPIO muxing!

### Repo Structure

- `software`
  - `simulator` simulator for emulation & verification
    - `test` official RISC-V `rv32im` test programs
    - `sim_emulator` SDL-based emulator for the ice40UP5K (Upduino) SoC.
    - `sim_cli` basic simulator for debugging.
  - `library` basic SoC support for programming in C (and linker scripts)
    - `crt0.S` C-runtime startup routine
    - `crt0_minimal.S` C bootstrapping without libc initialization
    - `map_bootloaded.ld` linker script for programs to be bootloaded
    - `map_ecp5.ld` normal memory model (Von Neumann), 100KiB RAM for ECP5 SoC
    - `map_minimal.ld` 1KiB RAM, 256B stack, used for the bootloader that fits in 256 words of memory.
    - `map_spram.ld` bootloader for 10KiB BRAM and 128KiB SPRAM on `soc_upduino` *without* bootloader
    - `map.ld` basic 10KiB BRAM for `soc_icefun`
   - `programs` miscellaneous programs for the SoC
    - `test_baremetal` first steps using `riscv32-unknown-elf-gcc` with no libc
    - `test_embedded` programs using newlib, custom `crt0`, and SoC support library.
    - `bootloader` similar to `test_embedded`, but linked to be loaded from SPI flash memory using the bootloader.
    - `qr_code` program (bootloaded) using an open-source library to generate and display a QR code
    - `images` program that can display low-resolution images using the 2-bit color text-mode graphics adapter.
- `rtl` HDL code (SystemVerilog designs)
  - `alu` ALU module used by both versions of the CPU. supports multiplication and division (M extension)
  - `common` shared modules (memory, bus hub generator, etc.)
  - `cpu` V1 multi-cycle `rv32im` CPU, Von Neumann architecture
  - `cpu_v2` V2 pipelined `rv32im` CPU, Harvard architecture 
    - `pipeline_tester` simple Verilator testbench for producing a VCD waveform from running a specified program
    - `simulator` co-simulator for verification and testing (`make test` runs the test suite)
    - `sim_cocotb` CoCoTB testbench using Icarus Verilog for timing and more detailed testing.
  - `fpga` FPGA-specific (more hardware oriented) modules (debouncers, IO, SPI, LED controller, etc.)
  - `graphics` text-mode graphics adapter (b/w and color, font ROM)
  - `soc_ecp5` complete SoC using the V2 processor for the ColorLight 5A-75B board. Timed at 50MHz. WIP IO.
  - `soc_fpga` SoCs for ice40 HX8K and UP5K (iceFUN and Upduino). Upduino runs at 25MHz (overclocked) with 2-bit color graphics, 128KiB RAM, and SPI bootloader.
  - `soc_sim` SoC for basic testing and verification of the V1 processor
    - `verilator` co-simulator for verification of the non-pipelined processor and basic bus architecture.