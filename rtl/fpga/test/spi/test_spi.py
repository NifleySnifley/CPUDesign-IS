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
    # Wait for unbusy
    # while 1:
    #     stat = await bus_read(dut, BASEADDR)
    #     if not (stat & 2):
    #         break
    
    # dut._log.info(f"Sending: {txdata}")
    # Set TX data
    await bus_write(dut, BASEADDR+8, txdata, 0b0001)

    # Get control and update it
    control_base = await bus_read(dut, BASEADDR+4)
    # print(f"Control is: {control_base}")
    await bus_write(dut, BASEADDR+4, control_base | 1, 0b0001)
    
    for i in range(10*4):
        await clk(dut)
    
    while 1:
        stat = await bus_read(dut, BASEADDR)
        if (stat & 1):
            break
    
    # Unset start bit
    await bus_write(dut, BASEADDR+4, control_base, 0b0001)
    
    rd = await bus_read(dut, BASEADDR+8)
    # dut._log.info(f"Received: {((rd) >> 8) & 0xFF}")
    
    return ((rd) >> 8) & 0xFF

@cocotb.test()
async def test_spi(dut):
    global LOOPBACK
    LOOPBACK = 1

    for d in range(0, 16):
        # divider = random.randint(0, 2**4-1)
        divider = d
        print(f"Testing with divider = {divider:04b}")
        control = 0b0000_0_0 | (divider << 2)
        await bus_write(dut, BASEADDR+4, control, 0b1111)

        for bi in range(32):
            b = random.randint(0, 255)
            rx = await spi_transact(dut, b)
            assert rx == b
    
    # control = 0b0000_0_0 | (0 << 2)
    # await bus_write(dut, BASEADDR+4, control, 0b1111)
    
    # rx = await spi_transact(dut, 0xFF)
    # assert rx == 0xFF