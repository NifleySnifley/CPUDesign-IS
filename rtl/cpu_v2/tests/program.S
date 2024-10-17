    .section .text.start;
    .global  _start;
_start:
    addi     x1, x0, 100
    addi     x2, x1, 400
    addi     x3, x0, 200
    addi     x4, x0, 250
    li       x5, 124124122
    li       x6, 12
# divu x5, x5, x6

    sw       x5, 0(x0)
    nop
    nop
    nop
    nop
    lw       x10, 0(x0)
# nop
# divu x5, x5, x6