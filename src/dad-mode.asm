
    org 0x100
START
    ; PATER.000 is saved without any AMSDOS header (see pater.asm): nothing has to be skipped
    incbin "PATER.000"
STOP

    SAVE "DAD-MODE.000", START, (0x4000-START), AMSDOS
    SAVE "DAD-MODE.001", 0x4000, STOP-0X4000, AMSDOS