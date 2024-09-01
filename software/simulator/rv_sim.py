#! /bin/env python3

from collections import defaultdict
from ctypes import c_uint8, c_uint32

def bits(val: int, idx_lo: int, idx_hi: int) -> int:
    return (val >> idx_lo) & ((2<<(idx_hi-idx_lo))-1)

BITS_32 = (2**32-1)
def signext(num: int, nbits: int) -> c_uint32:
    topbit = num & (1<<(nbits-1))
    return c_uint32(num | ((BITS_32 << nbits) if topbit else 0))
    
    
# OP_IMM =
OC_LOAD = 0b00_000
OC_LOAD_FP = 0b00_001
OC_CUSTOM0 = 0b00_010
OC_MISC_MEM = 0b00_011
OC_OP_IMM = 0b00_100
OC_AUIPC = 0b00_101
OC_IMM_32 = 0b00_110
OC_48B_0 = 0b00_111   

OC_STORE = 0b01_000
OC_STORE_FP = 0b01_001
OC_CUSTOM1 = 0b01_010
OC_AMO = 0b01_011
OC_OP = 0b01_100
OC_LUI = 0b01_101
OC_OP_32 = 0b01_110
OC_64B_0 = 0b01_111

OC_MADD = 0b10_000
OC_MSUB = 0b10_001
OC_NMSUB = 0b10_010
OC_NMADD = 0b10_011
OC_OP_FP = 0b10_100
# OC_RSVD = 0b10_101
OC_CUSTOM2_RV128 = 0b10_110
OC_48B_1 = 0b10_111

OC_BRANCH = 0b11_000
OC_JALR = 0b11_001
# OC_RSVD = 0b11_010
OC_JAL = 0b11_011
OC_SYSTEM = 0b11_100
# OC_RSVD = 0b11_101
OC_CUSTOM3_RV128 = 0b11_110
OC_80BP_0 = 0b11_111

class RV32I_Emu():
    def __init__(self, memsize, pc_start: int = 0) -> None:
        self.memory = [c_uint8(0) for i in range(memsize)] 
        self.pc = c_uint32(pc_start)
        self.reg = [c_uint32(0) for i in range(32)]
    
    def readword(self, addr) -> c_uint32:
        bs = [self.memory[(addr + i) % len(self.memory)] for i in range(4)]
        assert len(bs) == 4
        return c_uint32(sum([bs[i] * (2**(8*i)) for i in len(bs)]))
    
    def exec_instr(self):
        # Fetch
        inst = self.memory[self.pc.value].value
        
        # Decode
        imm_i = bits(inst, 20, 31)
        imm_s = (bits(inst,  25, 31) << 5) | bits(inst, 7,11)
        imm_b = (bits(inst, 8, 11) << 1) | (bits(inst, 25, 30) << (1+4)) | (bits(inst, 7,7) << 11) | (bits(inst, 31, 31) << 12)
        imm_u = inst & (BITS_32 << 12) # no need for sign extension
        imm_j = (bits(inst, 21, 30) << 1) | (bits(inst, 20,20) << 11) | (bits(inst,12,19) << 12) | (bits(inst, 31, 31) << 20)
        
        s_imm_i = signext(imm_i, 12)
        s_imm_s = signext(imm_s, 12)
        s_imm_b = signext(imm_b, 13)
        s_imm_u = imm_u
        s_imm_j = signext(imm_j, 21)
        
        opcode = inst & 0b1111111
        funct3 = bits(inst, 12, 14)
        funct7 = bits(inst, 25, 31)

        rd = bits(inst, 7,11)
        rs1 = bits(inst, 15, 19)
        rs2 = bits(inst, 20, 24)
        
        # if (inst == BITS_32):
        #     print("Testing (all ones)")
        #     assert bin(imm_i).count('1') == 12
        #     assert bin(imm_s).count('1') == 12
        #     assert bin(imm_b).count('1') == 12
        #     assert (imm_b & 1) == 0
        #     assert bin(imm_u).count('1') == 20
        #     assert bin(imm_j).count('1') == 20
        #     print("Success")
                    
        if (opcode & 0b11) != 0b11:
            print(f"Invalid instruction @ pc=0x{self.pc.value:x}")
        
        if (opcode == OC_OP):
            # 01100
            self.reg[0] = 0
            fb = (funct3, funct7)
            if fb == (0x0, 0x00): # ADD
                self.reg[rd].value = c_uint32(self.reg[rs1].value) + c_uint32(self.reg[rs2].value)
            elif fb == (0x0, 0x20): # SUB
                self.reg[rd].value = c_uint32(self.reg[rs1]) - c_uint32(self.reg[rs2])
            elif fb == (0x4, 0x0): # XOR
                self.reg[rd].value = c_uint32(self.reg[rs1]) ^ c_uint32(self.reg[rs2])
            elif fb == (0x6, 0x00): # OR
                self.reg[rd].value = c_uint32(self.reg[rs1]) | c_uint32(self.reg[rs2])
            elif fb == (0x7, 0x20): # AND
                self.reg[rd].value = c_uint32(self.reg[rs1]) & c_uint32(self.reg[rs2])
            
        # TODO: Better way to not set x0?
        self.reg[0] = 0

if __name__ == "__main__":
    sim = RV32I_Emu(0x1000)
    sim.memory[0] = c_uint32(BITS_32)
    sim.exec_instr()
    
