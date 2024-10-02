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
    control = 0b01_0_0 # FIXME: Actually read control register
    # print(f"Control is: {control}")
    control |= 1 # tx_start
    await bus_write(dut, BASEADDR+4, control, 0b0001)
    
    # TODO: Make sure status (spi finished) is immediately low after TX start so I don't need a clk in here
    # await clk(dut)
    while 1:
        stat = await bus_read(dut, BASEADDR)
        if not (stat & 2):
            break
    
    # Unset start bit
    control &= 0xFF ^ 1 # tx_start
    await bus_write(dut, BASEADDR+4, control, 0b0001)

    rd = await bus_read(dut, BASEADDR+8)
    return ((rd) >> 8) & 0xFF

@cocotb.test()
async def test_spi(dut):
    control = 0b01_0_0
    await bus_write(dut, BASEADDR+4, control, 0b0001)
    # data = await bus_read(dut, BASEADDR+4)
    # assert data == control

    LOOPBACK = 1
    for b in range(256):
        rx = await spi_transact(dut, b)
        assert rx == b
    # print(f"Received: {rx}")
