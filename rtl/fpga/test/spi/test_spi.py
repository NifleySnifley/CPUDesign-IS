import cocotb
from cocotb.triggers import Timer
from cocotb.binary import BinaryValue
import random
from ctypes import c_uint32, c_int32

LOOPBACK = True

async def clk(dut):
    dut.clk.value = 0
    if (LOOPBACK): dut.data_rx.value = dut.data_tx.value
    await Timer(1, units="ns")
    dut.clk.value = 1
    if (LOOPBACK): dut.data_rx.value = dut.data_tx.value
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

BASEADDR=0xd000

async def spi_transact(dut, txdata):
    # Set TX data
    await bus_write(dut, BASEADDR+8, txdata, 0b0001)

    # Get control and update it
    control_base = await bus_read(dut, BASEADDR+4) # FIXME: Actually read control register
    # print(f"Control is: {control_base}")
    await bus_write(dut, BASEADDR+4, control_base | 1, 0b0001)
    
    while 1:
        stat = await bus_read(dut, BASEADDR)
        if not (stat & 2):
            break
    
    # Unset start bit
    await bus_write(dut, BASEADDR+4, control_base, 0b0001)

    rd = await bus_read(dut, BASEADDR+8)
    return ((rd) >> 8) & 0xFF

@cocotb.test()
async def test_spi(dut):
    global LOOPBACK
    LOOPBACK = 1

    # for divider in range(0, 16):
    divider = 0b0011
    print(f"Testing with divider = {divider:04b}")
    control = 0b0000_0_0 | (divider << 2)
    await bus_write(dut, BASEADDR+4, control, 0b0001)

    for b in range(256):
        rx = await spi_transact(dut, b)
        assert rx == b
