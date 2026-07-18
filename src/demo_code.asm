;; July 2026
;; Krusty/Benediction

    include once "inner://ga.asm"



;; We assume everythin is proerly loaded in memory, and we just need to run the demo
demo_start
    ; kill the system
    di
        ld hl, 0xC9fb
        ld (0x38), hl
        ld sp, $
    ei

    call demo_init
    jp demo_run


demo_init
    call demo_init_screen
    call demo_init_music
    ret

demo_init_screen
.ga_init
    ; set up the screen in black
    ld bc, 0x7F54: xor a
.all_black_loop
    out (c), a : out (c), c
    inc a
    cp 17
    jr nz, .all_black_loop    
    ld a, 0x8c : out (c), a   ; mode 0

    
    ; set up the CRTC as expected
.crtc_setup
    ld bc, 0xbc00 + 1 : out (c), c : ld bc, 0xbd00 + 96/2 : out (c), c
    ld bc, 0xbc00 + 2 : out (c), c : ld bc, 0xbd00 + 50 : out (c), c
    ld bc, 0xbc00 + 7 : out (c), c : ld bc, 0xbd00 + 29 : out (c), c
    ld bc, 0xbc00 + 6 : out (c), c : ld bc, 0xbd00 + SCREEN_HEIGHT_CHARS : out (c), c
    ld bc, 0xbc00 + 12 : out (c),c : ld bc, 0xbd00 + 0x30 : out (c), c
    ld bc, 0xbc00 + 13 : out (c),c : ld bc, 0xbd00 : out (c), c
    ret

demo_init_music
    ret


    include "constants.asm"
    include "palettes.asm"
