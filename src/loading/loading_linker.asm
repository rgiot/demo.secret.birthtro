
    org LOADER_LINKER_ADDRESS

    include "../demosystem/linker_common.asm"
    include "inner://firmware/scrpack.asm"

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

        ld bc, 0xbc00 + 1 : out (c), c : ld bc, 0xbd00+0: out (c),c
        UNCRUNCH(C0_C000, 0xC000)
        ld bc, 0xbc00 + 1 : out (c), c : ld bc, 0xbd00+80/2: out (c),c
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


  ; copy the interrupted stuff to the right place
  ld hl, interrupted_start
  ld de, 0x8000
  ld bc, interrupted_stop - interrupted_start
  ldir

  ; activate it
    ld hl,Event_Block
    call &bce3 ; KL ADD FAST TICKER
;
    ret ; go back to basic
    

interrupted_start
  rorg 0x8000

Event_Block
; bloc de controle
        dw 0
; partie commune
        dw 0
        db 0 ; compteur
        db %10000011 ; classe
        dw interrupted_routine ; routine d'interruption
        db 0

interrupted_routine
    push af, hl, de, bc
      call random_palette
    pop bc, de, hl, af
    reti


random_palette
    ld a, 10
.loop

    ; select random color for pen a
    push af
      ld a, r
      and 31
.safety
      cp 27
      jr nc, .continue
      sub 27
      jr .safety
.continue

    ld b, a
    pop af
    ld c, b
    ; A = pen
    ; B = C = ink
    push af
      call SCR_SET_INK
    pop af

    inc a
    cp 16
    jr nz, .loop
    ret

  rend
interrupted_stop


    INSTALL_UNCRUNCHER()

    LOAD_N_CRUNCH(C0_2000, "C0.2000")
    LOAD_N_CRUNCH(C0_C000, "C0.C000")


    SAVE "LOADER.BIN"