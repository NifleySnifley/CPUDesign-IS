ENTRY(_start)

RAM_SIZE = 0x8000;
PROGROM_SIZE = 0x8000;
STACK_SIZE = 0x800;

MEMORY
{
    progrom (x)    : ORIGIN = 0x00000000, LENGTH = PROGROM_SIZE
    /* NOT LOADABLE!*/
    ram (rw) : ORIGIN = 0xf0000000, LENGTH = RAM_SIZE
}

SECTIONS
{
    /* __global_pointer$ = ORIGIN(ram) + LENGTH(ram); */
    .text : ALIGN(4) {
        KEEP(*(.text.start));
        *(.text .text.* .gnu.linkonce.t.*);
        *(.rodata .rodata* .gnu.linkonce.r.*);

        . = ALIGN(4);
        KEEP(*(.init));
        . = ALIGN(4);
        __preinit_array_start = .;
        KEEP (*(.preinit_array));
        __preinit_array_end = .;
        . = ALIGN(4);
        __init_array_start = .;
        KEEP (*(SORT(.init_array.*)));
        KEEP (*(.init_array));
        __init_array_end = .;

        . = ALIGN(4);
        KEEP(*(.fini))
        . = ALIGN(4);
        __fini_array_start = .;
        KEEP (*(.fini_array))
        KEEP (*(SORT(.fini_array.*)))
        __fini_array_end = .;
    } > progrom

    /* Move variables to SPRAM */
    /* Does this need to be implemented in CRT0???? */
    /* TODO: Implement proper data segment in crt0 to copy into SPRAM, make a different crt0 for systems with SPRAM */
    /* Although this is not neccesary unless the program is readonly */
    /* .data : ALIGN(4) { 
        . = ALIGN(4);
        _sdata = .;
        *(.ramfunc .ramfunc.*);
        *(.data .data.*);
        . = ALIGN(4);
        _edata = .;
    } > spram AT > progrom */
    .data : ALIGN(4) { *(.data*) } > ram
    .rodata : ALIGN(4) { *(.rodata*) } > ram
    /* .bss : ALIGN(4) { *(.bss*) } > progrom */

    .bss (NOLOAD) : ALIGN(4)
    {
        . = ALIGN(4);
        _bss_start = .;
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        *(COMMON)
        _bss_end = .;
    } > ram

    .stack (NOLOAD) : ALIGN(4)
    {
        . = ALIGN(4);
        _stack = .;
        . = . + STACK_SIZE;
        . = ALIGN(4);
        _stack = .;
    } > ram

    .heap (NOLOAD) : ALIGN(4)
    {   
        . = ALIGN(4);
        PROVIDE (_heap_start = .);
        _end = . ;
    } > ram

}