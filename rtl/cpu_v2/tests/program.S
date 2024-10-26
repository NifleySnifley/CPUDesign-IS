    .section .text.start;
    .global  _start;
_start:
# addi x4, x4, 1
    li       x1, 200

lp:
    addi     x10, x10, 10
# j lp
    blt      x10, x1, lp


    li       x5, 0xAA
    li       x5, 0xAB
    li       x5, 0xAC
    li       x5, 0xAD
    li       x5, 0xAE
    li       x5, 0xAF
    ebreak
# nop
# divu x5, x5, x6