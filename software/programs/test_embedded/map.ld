ENTRY(_start)

MEMORY
{
    ram (rwx): ORIGIN = 0x00000000, LENGTH = 0x2000
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

    STACK_SIZE = 0x1000;
    .stack (NOLOAD) : ALIGN(4)
    {
        . = ALIGN(4);
        _stack = .;
        . = . + STACK_SIZE;
        . = ALIGN(4);
        _stack = .;
    } > ram

    .bss : ALIGN(4) { *(.bss*) } > ram
}