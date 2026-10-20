
    org LOADER_LINKER_ADDRESS

    include "../demosystem/linker_common.asm"

    run $


    SELECTED_CRUNCHER equ CRUNCHER_ZX0_BACKWARD

    ; Interruption are disabled to be sure system is silenced
    ; Registers are preserved to avoid any side effect on the system
    di
      exx
        push hl, de, bc
      exx
      ex af, af'
        push af
      ex af, af'
      push ix, iy

        UNCRUNCH(C0_C000, 0xC000)
        UNCRUNCH(C0_2000, LOADER_CODE_ADDRESS)
        call LOADER_CODE_ADDRESS

      pop iy, ix
      ex af, af'
        pop af
      ex af, af'
      exx
        pop bc, de, hl
      exx
    ei
    ret ; go back to basic
    


    INSTALL_UNCRUNCHER()

    LOAD_N_CRUNCH(C0_2000, "C0.2000")
    LOAD_N_CRUNCH(C0_C000, "C0.C000")


    SAVE "LOADER.BIN"