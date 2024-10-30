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

async def bus_read(dut, addr):
    dut.ren.value = 1
    dut.wen.value = 0
    dut.addr.value = addr
    dut.wdata.value = 0
    dut.wmask.value = 0
    await clk(dut)
    while (not dut.ready):
        await clk(dut)
    return dut.rdata.value

async def bus_write(dut, addr, data, mask):
    dut.ren.value = 0
    dut.wen.value = 1
    dut.addr.value = addr
    dut.wdata.value = data
    dut.wmask.value = mask
    await clk(dut)
    while (not dut.ready):
        await clk(dut)
    # return dut.rdata

BASEADDR=0x81000000

async def set_pixel(dut, bufidx, x, y, r,g,b):
    color = r|(g<<8)|(b<<16)
    word_addr = (64*64*bufidx) + x + y*64
    await bus_write(dut, BASEADDR+(word_addr<<2), color, 0b1111)

@cocotb.test()
async def test_hub75(dut):
    for x in range(10):
        for y in range(10):
            await set_pixel(dut, 0, x, y, 255,255,255)

    for cyc in range(10000):
        await clk(dut)