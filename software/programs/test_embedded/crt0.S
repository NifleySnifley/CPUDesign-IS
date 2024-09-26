	.section .text.start;
	.global  _start;
_start:
	//       Load stack pointer
	la       sp, _stack

	//       Zero out all of BSS
	la       x26, _bss_start
	la       x27, _bss_end
	bge      x26, x27, zend
zloop:
	sw       x0, 0(x26)
	addi     x26, x26, 4
	ble      x26, x27, zloop
zend:

	//       Do libc init stuff
	call     __libc_init_array

	//       Call main
	la       ra,_start
	call     main