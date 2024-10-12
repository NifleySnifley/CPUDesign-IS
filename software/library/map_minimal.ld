ENTRY(_start)

BRAM_SIZE = 0x400;
STACK_SIZE = 0x100;


MEMORY
{
    ram (rwx): ORIGIN = 0x00000000, LENGTH = BRAM_SIZE
}

SECTIONS
{
    __global_pointer$ = ORIGIN(ram) + LENGTH(ram);
    .text : ALIGN(4) {
        KEEP(*(.text.start))

        *(.text*)
    } > ram

    .data : ALIGN(4) { *(.data*) } > ram
    .rodata : ALIGN(4) { *(.rodata*) } > ram

    .stack (NOLOAD) : ALIGN(4)
    {
        . = ALIGN(4);
        _stack = .;
        . = . + STACK_SIZE;
        . = ALIGN(4);
        _stack = .;
    } > ram

    .bss : ALIGN(4) 
    { 
        _bss_start = .;
        *(.bss*) 
        _bss_end = .;
    } > ram
}