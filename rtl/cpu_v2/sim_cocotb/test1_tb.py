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
    
    dut.rst.value = 1
    for n in range(10):
        dut.clk.value = 1
        await Timer(1, units="ns")
        dut.clk.value = 0
        await Timer(1, units="ns")
    dut.rst.value = 0
    
    for n in range(1000):
        dut.clk.value = 1
        await Timer(1, units="ns")
        dut.clk.value = 0
        await Timer(1, units="ns")
    # assert dut.my_signal_2.value[0] == 0, "my_signal_2[0] is not 0!"