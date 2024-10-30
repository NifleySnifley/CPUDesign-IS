# Work Items for Pipelined CPU (v2):

- [x] Register forwarding (shouldn't be too bad)
  - Done, not sure what the timing affects of this is, but it seems fine.
- [ ] Branch prediction (basic) and pipeline flushing (make a more formal PC change system than just reading from WB stage...)
- [X] Unify the memory (implement a cache, or... just make a memory arbiter and read in the fetch stage! could maybe get down to single-cycle reads too with just one register?)
  - https://github.com/zebmehring/Processor-Cache
  - https://github.com/psnjk/SimpleCache
  - Currently, there is no reason to have a cache. When I get around to making a SDRAM controller, cache would probably increase the speed of this as data memory.
- [X] Build a proper SoC with this (ice40 would be cool, but ECP5 is reasonable)
  - `soc_ecp5`