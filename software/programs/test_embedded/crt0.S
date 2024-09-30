	.section .text.start;
	.global  _start;
_start:
	//       Load stack pointer
	la       sp, _stack

	//       Zero out all of BSS
	la       s10, _bss_start
	la       s11, _bss_end
# bgeu x26, x27, zend
zloop:
	sw       x0, 0(s10)
	addi     s10, s10, 4
	ble      s10, s11, zloop

	//       Do libc init stuff
	call     __libc_init_array

	//       Call main
	la       ra,_start
	call     main