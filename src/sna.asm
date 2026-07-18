;;
;; July 2026
;; sna for the main part
    
    SNASET CRTC_SEL, 0
    

    include "inner://ga.asm"

    run demo_start

range 0x0000, 0x00ff, stack_and_rst
range 0x0100, 0x3fff, demo_code
range 0x4000, 0x7fff, music
range 0x8000, 0xbfff, screen_buffer
range 0xc000, 0xffff, screen_main


section demo_code
    include "demo_code.asm"

section screen_buffer
    incbin "../../data/face0_cpc.scr"
