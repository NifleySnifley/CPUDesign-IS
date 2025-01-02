# Project Structure 
This repository contains the implementation of all of the various different components required for hardware synthesis, simulation, verification, and software support of the full system on a chip (SoC). The SoC can be used and tested either as a software simulation or synthesized to run on three different FPGA boards

This project contains two separate implementations of the RISC-V `rv32im` architecture, a simple, minimal multi-cycle design, and a performance-optimized pipelined design.

## CPU component architecture.

Each CPU is implemented as two major components:
- The processor itself (control logic, instruction decoding, etc)
- The arithmetic logic unit or ALU that is used by the CPU containing the implementation of all arithmetic instructions
- A bus, which allows the CPU to read instructions from a memory device (non-pipelined version) and interface with other miscellaneous IO/peripheral devices through a bus hub.
- [More Implementation Details Here](cpu_arch.md)

## Bus Architecture

This system on a chip is designed around a central bus hub which serves as interface between the CPU and multiple bus devices including peripherals and memory. More information can be found in the [Bus Architecture](./bus.md) section.

## FPGA-Oriented Peripherals

This project contains four specialized bus devices (peripherals) designed for use on FPGAs.

- A minimal parallel port implementation is provided 
  - 32 bits of input and 32 bits of output (separate wires)
  - controlled with a single 32 bit word (configurable address).
  - Synchronous, updates its output bits on the positive edge of clock when write enable is asserted and the device is active.
- [SPI (Serial Peripheral Interface)](https://en.wikipedia.org/wiki/Serial_Peripheral_Interface) Host Controller 
  - A more efficient alternative to bit banging SPI with the parallel port.
  - Configurable clock reduction with 30-bit resolution
    - Why is this useful? no idea. You could make chiptune music with it, I guess.
  - Automated SPI transactions through an internal finite state machine.
  - Three words of control and data registers
    - `BASEADDR + 0`: Status register
      - Bit 0: Transaction finished
      - Bit 1: Busy
    - `BASEADDR + 4`: Control register
      - Bit 0: Start transaction
      - Bit 1: Hardware chip-select level
      - Bits 2-31: 30-bit clock divider (sclk_freq = clock_in_freq/clock_divider)
  - GPIO Bank (for `ICE40` devices)
    - Bidirectional IO pins
    - Configurable number of IO (up to 32)
  - [HUB75 LED Matrix Display Driver](./hub75.md)