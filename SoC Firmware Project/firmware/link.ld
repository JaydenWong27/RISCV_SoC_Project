ENTRY(_start)

/* Single 32 KB unified memory, matching wb_bram (8192 x 32-bit words).
   crt0.S sets sp to 0x8000, the top of this region. */
MEMORY {
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 32K
}

SECTIONS {
    .text : {
        *(.text.init)
        *(.text)
    } > RAM

    .rodata : { *(.rodata) *(.rodata.*) } > RAM

    .data : { *(.data) *(.data.*) } > RAM

    .bss : {
        __bss_start = .;
        *(.bss)
        *(.bss.*)
        *(COMMON)
        __bss_end = .;
    } > RAM
}
