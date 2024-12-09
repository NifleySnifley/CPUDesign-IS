     .section .text.start;
    .global  _start;
_start:
    li x10, 0x80
    li x11, 1
    li x12, 0x80

    // Address for parallel (LED) IO bank
    li x9, 0xf000

    // Go left until == 1
shrt:
    srli x10,x10, 1
    sw x10, 0(x9)
    bgt x10,x11, shrt

    // Go right until == 0x80
shlt:
    slli x10,x10, 1
    sw x10, 0(x9)
    blt x10,x12, shlt

    j shrt

.section .data
.balign 4
testword: .word 0xDEADBEEF // Just for fun
