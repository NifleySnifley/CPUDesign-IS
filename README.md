# RISC-V CPU Design Independent Study

### Improvements

- [X] Add SRAM support as a bus device for stack memory

- [X] Pipelining (**eek**)

- [X] Caching & programs from external memory

- [ ] Compressed instruction decoding & support

### Features:

- [X] Test VGA peripheral (black & white text mode) graphics adapter

- [ ] Multicore? (A extension & other stuff)

- [X] M extension

- [ ] B extension

- [ ] CSRs (or traps for system instructions)

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
  - `programs` miscellaneous programs for the SoC
    - `test_baremetal` first steps using `riscv32-unknown-elf-gcc` with no libc
    - `test_embedded` programs using newlib, custom `crt0`, and library.
    - `bootloader` similar to `test_embedded`, but linked to be loaded from SPI flash memory using the bootloader.
    - `qr_code` program (bootloaded) using an open-source library to generate and display a QR code
    - `images` program that can display low-resolution images using the 2-bit color text-mode graphics adapter.
- `rtl` HDL code (SystemVerilog designs)
  - `alu` ALU module used by both versions of the CPU. supports multiplication and division (M extension)
  - `common` shared modules (memory, bus hub generator, etc.)
  - `cpu` V1 multi-cycle `rv32im` CPU, Von Neumann architecture
  - `cpu_v2` V2 pipelined `rv32im` CPU, Harvard architecture 
  - `fpga` FPGA-specific (more hardware oriented) modules (debouncers, IO, SPI, LED controller, etc.)
  - `graphics` text-mode graphics adapter (b/w and color, font ROM)
  - `soc_ecp5` complete SoC using the V2 processor for the ColorLight 5A-75B board. Timed at 50MHz. WIP IO.
  - `soc_fpga` SoCs for ice40 HX8K and UP5K (iceFUN and Upduino). Upduino runs at 25MHz (overclocked) with 2-bit color graphics, 128KiB RAM, and SPI bootloader.
  - `soc_sim` SoC for basic testing and verification of the V1 processor