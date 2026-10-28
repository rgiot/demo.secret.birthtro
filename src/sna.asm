;#!bndbuild
; {% include "build.bnd" %}

;;
;; July 2026
;; sna for the main part


ENABLE_COMPLETE_SCREEN_COPY equ false ; now we let the demo display the screen
SHIFT_SCREEN_FOR_DEBUG equ false ;true
HIDE_SCROLLER equ false
SHOW_DEBUG equ false

SPECTRAL_BANK equ 0xc4
ANIMATE_BANK equ 0xc5
ANIMATE2_BANK equ 0xc7


	if false
    	SNASET CRTC_TYPE, 3; Demo is coded for CRTC0 but emulatro is requested to be CRTC1. adaptation must work and make the scroller visible
		SNASET CPC_TYPE, 4 ; 6128 plus
	else
		SNASET CRTC_TYPE, 0
		SNASET CPC_TYPE, 2 ; CPC
	endif
    run demo_start
    

    include "inner://ga.asm"

    BANKSET 0
range 0x0000, 0x00ff, stack_and_rst
range 0x0300, 0x7fff, demo_code_main
range 0x8000, 0xbfff, screen_buffer
range 0xc000, 0xffff, screen_main

    BANKSET 1
range 0x0000, 0x3fff, demo_code_c4
range 0x4000, 0x7fff, demo_code_c5
range 0x8000, 0xb000, paged_music_for_c6
range 0xC000, 0xffff, demo_code_c7

    BANKSET 0
section demo_code_main
    include "demo_code.asm"
section screen_buffer
    incbin  FACE_SCR


    BANKSET 1
section demo_code_c4
	rorg 0x4000
   		include "spectral_sprites.asm"
		assert $<0x8000
	endr

section demo_code_c5
	rorg 0x4000
    	include "animate.asm"
		assert $<0x8000
	endr

section paged_music_for_c6
	rorg 0x4000
	
	; music
    include MUSIC_CFG
MUSIC
    include MUSIC_DATA
    include "PlayerAkg.asm"

	assert $<0x8000
	rend

section demo_code_c7
	rorg 0x4000
	  include "animate2.asm"
	  assert $>=0x4000
	  assert $<=0xffff
	rend



	; XXX It seems there is a bug n BASM that makes it save 16k instead of 
	; the true amount of bytes generated
	; in the meanwhile, we can manually specify size
	macro SAVE_SECTION, name, fname
		section {name}
		save {fname}, section_start("{name}"), section_used("{name}")
	endm

	SAVE_SECTION(demo_code_main, "C0.300")
	SAVE_SECTION(demo_code_c4, "C4.4000")
	SAVE_SECTION(screen_buffer, "C0.8000")
	SAVE_SECTION(demo_code_c5,"C5.4000")
	SAVE_SECTION(paged_music_for_c6,"C6.4000")
	SAVE_SECTION(demo_code_c7,"C7.4000")

