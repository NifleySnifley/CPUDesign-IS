STACK_SIZE = DEFINED(__stack_size__) ? __stack_size__ : 0x0800;
BRAM_SIZE = 0x2800;
SPRAM_SIZE = 0x20000;

ENTRY(_start)

MEMORY
{
    bram (rwx)    : ORIGIN = 0x00000000, LENGTH = BRAM_SIZE
    /* NOT LOADABLE!*/
    spram (rwx) : ORIGIN = 0xf0000000, LENGTH = SPRAM_SIZE
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
    } > bram

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
    } > spram AT > bram */
    .data : ALIGN(4) { *(.data*) } > bram
    .rodata : ALIGN(4) { *(.rodata*) } > bram
    /* .bss : ALIGN(4) { *(.bss*) } > bram */

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
    } > spram

    .stack (NOLOAD) : ALIGN(4)
    {
        . = ALIGN(4);
        _stack = .;
        . = . + STACK_SIZE;
        . = ALIGN(4);
        _stack = .;
    } > spram

    .heap (NOLOAD) : ALIGN(4)
    {   
        . = ALIGN(4);
        PROVIDE (_heap_start = .);
        _end = . ;
    } > spram

}