    include "../constants_screen.asm"
    
    org 0x4000
    run $
LOGO_START

; we do not want to kill the demosystem

    di
        push af, hl, bc, de

    ; black and mode 0
        ld bc, 0x7F54
        xor a
.black_loop
        out (c), a: out (c), c
        inc a : cp 17
        jr nz, .black_loop
        ld c, 0x8c : out (c), c


        ; set up crtc configraiton
        call handle_crtc_in_transition

        ; do the fade in
fade_in_loop
        ld b, 0xf5
.novbl
        in a, (c)
        rra
        jr nc, .novbl

        call delay_stuff
        call z, palette_fade_handle
        jp nz, fade_in_loop


        call palette_fade_handle_switch

        ; play the sample
        call wait_2_seconds
        call PlayBenedictionSample
        call wait_2_seconds


        ; do the fade out
fade_out_loop
        ld b, 0xf5
.novbl
        in a, (c)
        rra
        jr nc, .novbl

        call delay_stuff
        call z, palette_fade_handle
        jp nz, fade_out_loop


    ; restore standard crtc configuration

        ; go back to the firmware screen configuration (the loader screen expects it).
        ; crtc_restore cannot be used: it only re-applies the LAST configuration given to crtc_setup,
        ; which is the one of the demo (R2=50 shifts the picture on the left).
        ld hl, crtc_table_firmware : call crtc_setup


        pop de, bc, hl, af
        ld (0x38), hl

the_end

    ret

delay_stuff
.wait+*: ld a, 0
    inc a
    and %111
    ld (.wait), a
    ret

wait_2_seconds
    ld hl, 50*1
.loop
    ld b, 0xf5
.vsync
    in a, (c)
    rra
    jr c, .vsync
.nvsync
    in a, (c)
    rra
    jr nc, .nvsync

    dec hl
    ld a, h : or l
    ret z

    jp .loop


palette_fade_handle_switch
    ld a, palette_fade_steps + 1
    ld (palette_fade_handle.step), a

    xor a : ld (palette_fade_handle.patch_or_a), a
    ld (palette_fade_handle.patch_sbc), a

    ld a, opcode(add hl, bc)
    ld (palette_fade_handle.patch_sbc+1), a

    ld hl, palette_fade
    ld (palette_fade_handle.palette), hl
    ret

palette_fade_handle
    ; stop when needed
.step+*: ld a, palette_fade_steps + 1
    dec a : or a : ret z
    ld (.step), a

    ; setup the palette
.palette+*:    ld hl, palette_fade + (palette_fade_steps - 1) * palette_length
    ld b, 0x7f : xor a
.loop
    out (c), a
    ld c, (hl) : out (c), c
    inc a : inc hl
    cp 17
    jp nz, .loop

    ; compute next palette address
    ld hl, (.palette)
    ld bc, palette_length
.patch_or_a
    or a 
.patch_sbc
    sbc hl, bc
    ld (.palette), hl

    ld a, 1 : or a
    ret


palette_length = 17
palette_fade
    incbin "../../data/logo.fadepal"
palette_fade_steps equ ($-palette_fade)//palette_length

    include "logo_benediction_sample.asm"

    include "../demosystem/arkos_setup_crtc.asm"

handle_crtc_in_transition
    AKS_HANDLE_CRTC_TRANSITION(crtc_table)
    ret

crtc_table
    AKS_CRTC_TRANS_TABLE([
        [0, 64-1], 
        [1, SCREEN_WIDTH_WORDS], 
        [2, SCREEN_CRTC_R2], 
        [3, SCREEN_CRTC_R3], 
        [6, SCREEN_HEIGHT_CHARS], 
        [7, 29],
        [12, 0x30],
     [13, 0x00]
    ])



crtc_table_firmware
    AKS_CRTC_TRANS_TABLE([
        [0, 63], [1, 40], [2, 46], [3, 0x8E], [4, 38], [5, 0],
        [6, 25], [7, 30], [9, 7], [12, 0x30], [13, 0x00]
    ])

    print "Last byte", {hex}$
    SAVE "C0.4000", LOGO_START, $-LOGO_START



    org 0xC000
    incbin "../../data/logo.scr"
    SAVE "C0.C000", 0xC000, 0x4000

