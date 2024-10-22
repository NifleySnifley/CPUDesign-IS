# Work Items for Pipelined CPU (v2):

- [x] Register forwarding (shouldn't be too bad)
- [ ] Branch prediction (basic) and pipeline flushing (make a more formal PC change system than just reading from WB stage...)
- [ ] Unify the memory (implement a cache, or... just make a memory arbiter and read in the fetch stage! could maybe get down to single-cycle reads too with just one register?)
  - https://github.com/zebmehring/Processor-Cache
  - https://github.com/psnjk/SimpleCache
- [ ] Build a proper SoC with this (ice40 would be cool, but ECP5 is reasonable)
  - Make a proper linker script (to deal with the harvard architecture for now... sadly no bootloader...)