import cocotb
from cocotb.triggers import Timer
from cocotb.binary import BinaryValue
import random
from ctypes import c_uint32, c_int32

async def clk(dut):
    dut.clk.value = 0
    await Timer(1, units="ns")
    dut.clk.value = 1
    await Timer(1, units="ns")

async def reset(dut):
    dut.rst.value = 1
    await clk(dut)
    dut.clk.value = 0
    dut.rst.value = 0
    await clk(dut)

@cocotb.test()
async def test_sim(dut):
    await reset(dut)

    for i in range(250):
        await clk(dut)