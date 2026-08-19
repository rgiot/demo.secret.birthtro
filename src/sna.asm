;#!bndbuild
; {% include "build.bnd" %}

;;
;; July 2026
;; sna for the main part


ENABLE_COMPLETE_SCREEN_COPY equ false ; now we let the demo display the screen
SHIFT_SCREEN_FOR_DEBUG equ false ;true
HIDE_SCROLLER equ false
SHOW_DEBUG equ true    

    SNASET CRTC_TYPE, 0  ; Demo is coded for CRTC0 but emulatro is requested to be CRTC1. adaptation must work and make the scroller visible
    run demo_start
    

    include "inner://ga.asm"

    BANKSET 0
range 0x0000, 0x00ff, stack_and_rst
range 0x0300, 0x7fff, demo_code_main
range 0x8000, 0xbfff, screen_buffer
range 0xc000, 0xffff, screen_main

    BANKSET 1
range 0x4000, 0x7fff, demo_code_c5

    BANKSET 0
section demo_code_main
    include "demo_code.asm"
section screen_buffer
    incbin  FACE_SCR


    BANKSET 1
section demo_code_c5
    include "animate.asm"



	; XXX It seems there is a bug n BASM that makes it save 16k instead of 
	; the true amount of bytes generated
	; in the meanwhile, we can manually specify size
	macro SAVE_SECTION, name, fname
		section {name}
		save {fname}, section_start("{name}"), section_used("{name}")
	endm

	SAVE_SECTION(demo_code_main, "C0.300")
	SAVE_SECTION(screen_buffer, "C0.8000")
	SAVE_SECTION(demo_code_c5,"C5.4000")
