    .section .text.start;
    .global  _start;
_start:
	la sp,_stack
	la ra,_start
	call main