/* Linker layout for the RV32 bare-metal SoC. */
OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    IRAM (rx)  : ORIGIN = 0x80000000, LENGTH = 4K
    /* Keep software state/stack above the three reserved 36 KiB JPEG outputs. */
    DRAM (rwx) : ORIGIN = 0x0003E000, LENGTH = 8K
}

SECTIONS
{
    /* Reset code stays at the CPU reset vector. */
    .text.init ORIGIN(IRAM) :
    {
        . = ALIGN(4);
        KEEP(*(.text.init))
        . = ALIGN(4);
    } > IRAM

    /* my_core.v sets direct-mode mtvec to 0x80000100. */
    .trap 0x80000100 :
    {
        . = ALIGN(4);
        KEEP(*(.trap))
        . = ALIGN(4);
    } > IRAM

    /* Leave space after the trap wrapper and start normal code at 0x80000300. */
    .text 0x80000300 :
    {
        . = ALIGN(4);
        *(.text)
        *(.text.*)
        . = ALIGN(4);
    } > IRAM

    .rodata :
    {
        . = ALIGN(4);
        *(.rodata)
        *(.rodata.*)
        *(.srodata)
        *(.srodata.*)
        . = ALIGN(4);
    } > IRAM

    .data :
    {
        . = ALIGN(4);
        _sdata = .;
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.sdata.*)
        . = ALIGN(4);
        _edata = .;
    } > DRAM AT > IRAM

    _sidata = LOADADDR(.data);

    .bss :
    {
        . = ALIGN(4);
        _sbss = .;
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > DRAM

    __global_pointer$ = ORIGIN(DRAM) + 0x800;
    _stack_top = ORIGIN(DRAM) + LENGTH(DRAM);

    ASSERT(ADDR(.text.init) + SIZEOF(.text.init) <= ADDR(.trap),
           "startup code overlaps the interrupt vector")
    ASSERT(ADDR(.trap) + SIZEOF(.trap) <= ADDR(.text),
           "trap wrapper overlaps normal code")
    ASSERT(LOADADDR(.data) + SIZEOF(.data) <= ORIGIN(IRAM) + LENGTH(IRAM),
           "firmware image exceeds instruction RAM")
    ASSERT(ADDR(.bss) + SIZEOF(.bss) <= ORIGIN(DRAM) + LENGTH(DRAM),
           "firmware BSS exceeds data RAM")
}
