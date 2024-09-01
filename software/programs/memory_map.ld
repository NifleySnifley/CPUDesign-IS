ENTRY(_start)

MEMORY
{
    rom (rx): ORIGIN = 0x00000000, LENGTH = 0x1000
    ram (rw): ORIGIN = 0x00001000, LENGTH = 0x1000
}

SECTIONS
{
    .text : {
        KEEP(*(.text.boot))

        *(.text*)
    } > rom

    .rodata : { *(.rodata*) } > rom

    .bss : { *(.bss*) } > ram
}