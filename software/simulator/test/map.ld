ENTRY(_start)

MEMORY
{
    ram (rwx): ORIGIN = 0x00000000, LENGTH = 0x2000
}

SECTIONS
{
    .text : {
        KEEP(*(.text.start))

        *(.text*)
    } > ram

    .rodata : { *(.rodata*) } > ram

    .bss : { *(.bss*) } > ram
}