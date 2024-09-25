	.section .text.start;
	.global  _start;
_start:
	li x1, 0x00001000
	lb x3, 0(x1)

	li x1, 0x00f10000
	lb x2, 0(x1)
	j _start