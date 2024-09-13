    .section .text.start;
    .global  _start;
_start:
    li       a0, 0xDEADBEEF // a0 = DEADBEEF
    li       a1, 0xBEEF // a1 = 0000BEEF
    sub      a2, a0, a1 // a2 = DEAD0000
    j        _start