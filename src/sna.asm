;#!bndbuild
; {% include "build.bnd" %}




;#!bndbuild
; {% set SNA="birthtro.sna" %}
; {% set FACE_SCR="../data/face2_cpc.scr" %}
; {% set FACE_PAL="../data/face2_cpc.pal" %}
; - tgt: test
;   dep: {{ SNA }}
;   cmd: -emu --snapshot {{SNA}} run
; - tgt: {{SNA}}
;   dep:
;     - sna.asm 
;     - demo_code.asm
;     - palettes.asm
;     - constants.asm
;     - common.asm
;     - {{ FACE_SCR }}
;     - {{ FACE_PAL }}
;   cmd: 
;    - basm --snapshot sna.asm -o {{SNA}} -DFACE_SCR=\"{{FACE_SCR}}\" -D FACE_PAL=\"{{FACE_PAL}}\"
; - tgt: clean
;   phony: true
;   cmd:
;     - rm {{SNA}}

;;
;; July 2026
;; sna for the main part



ENABLE_COMPLETE_SCREEN_COPY equ true
SHIFT_SCREEN_FOR_DEBUG equ true
HIDE_SCROLLER equ true
    
    SNASET CRTC_SEL, 0
    run demo_start
    

    include "inner://ga.asm"

    BANKSET 0
range 0x0000, 0x00ff, stack_and_rst
range 0x0100, 0x7fff, demo_code_main
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



