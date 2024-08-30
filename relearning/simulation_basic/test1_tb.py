# test_my_design.py (simple)

import cocotb
from cocotb.triggers import Timer
import random


@cocotb.test()
async def my_first_test(dut):
    """Try accessing the design."""

    # for cycle in range(10):
    #     dut.inp.value = bin()
    #     await Timer(1, units="ns")
    #     dut.inp.value = 2
    #     await Timer(1, units="ns")

    # dut._log.info("testout is %s", dut.out_xor.value)
    
    for testn in range(100):
        iv = random.randint(0, 2**99-1)
        xoriv = sum([int(i) for i in bin(iv)[2:]])
        
        dut.inp.value = iv
        await Timer(1, units="ns")
        assert dut.out_xor.value == (xoriv & 1)
        
    # assert dut.my_signal_2.value[0] == 0, "my_signal_2[0] is not 0!"