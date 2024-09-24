	.section .text.start;
	.global  _start;
_start:
# la sp,_stack
	li       sp,0x2000
	la       ra,_start
	call     main