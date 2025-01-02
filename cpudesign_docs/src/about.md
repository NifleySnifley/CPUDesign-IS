# About This Project

This project contains all of the SystemVerilog HDL, scripts, tools, software support, and programs (C) for my 2024 CPU Design/Computer Architecture Independent Study project. My goal for this project was to implement a fully-functional RISC-V `rv32im` processor that could be synthesized for a `ICE40` FPGA on my Upduino board. I've done a bit more than just that (made a pipelined version for an `ECP5` FPGA, many peripherals, and a software simulator!)

See [Project Structure](./repo_structure.md) for more details.

A big thanks to all of the folks who helped create the [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build) which has been essential for all of my FPGA and HDL tinkering including this project. Specifically:
- [Yosys](https://github.com/YosysHQ/yosys)
- [NextPNR](https://github.com/YosysHQ/nextpnr)
- [Project IceStorm](https://github.com/YosysHQ/icestorm) and [Project Trellis](https://github.com/YosysHQ/prjtrellis)
- [Verilator](https://github.com/verilator/verilator) and [cocotb](https://github.com/cocotb/cocotb)