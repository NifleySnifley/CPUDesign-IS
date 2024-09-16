     .section .text.start;
    .global  _start;
_start:
    li x10, 0x80
    li x11, 1
    li x12, 0x80

    lw x8, testword
    addi x8, x8, 12
    la x9, testword
    sw x8, 0(x9)

    // Go left until == 1
shrt:
    srli x10,x10, 1
    bgt x10,x11, shrt

    // Go right until == 0x80
shlt:
    slli x10,x10, 1
    blt x10,x12, shlt

    j shrt

.section .data
.balign 4
testword: .word 0xDEADBEEF
