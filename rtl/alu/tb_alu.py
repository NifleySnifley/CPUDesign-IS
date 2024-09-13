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
    dut.alu_start.value = 0
    dut.rst.value = 1
    await clk(dut)
    dut.clk.value = 0
    dut.rst.value = 0
    await clk(dut)

async def run(dut, op1: int, op2: int, funct3: int, funct7: int):
    dut.funct3.value = funct3
    dut.funct7.value = funct7
    dut.in1.value = op1
    dut.in2.value = op2
    dut.alu_start.value = 1
    await clk(dut)
    dut.alu_start.value = 0
    while not dut.alu_done.value:
        await clk(dut)

    return dut.out.value

@cocotb.test()
async def test_add(dut):
    await reset(dut)

    for _ in range(1000):
        a,b = random.randint(0, 2**32-1), random.randint(0, 2**32-1)
        ans = await run(dut, a,b,0b000, 0b0000000)
        assert ans.value == ((a+b) % (2**32))


@cocotb.test()
async def test_and(dut):
    await reset(dut)

    for _ in range(1000):
        a,b = random.randint(0, 2**32-1), random.randint(0, 2**32-1)
        ans = await run(dut, a,b,0b111, 0b0000000)
        assert ans.value == (a&b)

def from_twos(num: int):
    return num if (num < 2**31) else num-2**32

def to_twos(num: int):
    return num if (num > 0) else (2**32-num)

@cocotb.test()
async def test_sub(dut):
    await reset(dut)

    for _ in range(1000):
        a,b = random.randint(0, 2**32-1), random.randint(0, 2**32-1)
        ans = await run(dut, a,b,0b000, 0b0100000)
        assert int(ans) == (a-b)&0xFFFFFFFF

@cocotb.test()
async def test_or(dut):
    await reset(dut)

    for _ in range(1000):
        a,b = random.randint(0, 2**32-1), random.randint(0, 2**32-1)
        ans = await run(dut, a,b,0b110, 0b0000000)
        assert ans.value == (a|b)

@cocotb.test()
async def test_xor(dut):
    await reset(dut)

    for _ in range(1000):
        a,b = random.randint(0, 2**32-1), random.randint(0, 2**32-1)
        ans = await run(dut, a,b,0b100, 0b0000000)
        assert ans.value == (a^b)

@cocotb.test()
async def test_sll(dut):
    await reset(dut)

    for _ in range(1000):
        a,b = random.randint(0, 2**32-1), random.randint(0, 32)
        ans = await run(dut, a,b,0b001, 0b0000000)
        assert ans.value == (a<<(b&0b11111))&0xFFFFFFFF
