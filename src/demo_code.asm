;; July 2026
;; Krusty/Benediction

    include once "inner://ga.asm"



;; We assume everythin is properly loaded in memory, and we just need to run the demo
demo_start

    ; kill the system
    di
        ld hl, 0xC9fb
        ld (0x38), hl
        ld sp, $
    ei

    BREAKPOINT
    BREAKPOINT 0xe77
    call demo_init
    ; Really run the demo
    jp demo_run


    ; Initialize the various components of effects
demo_init
    call demo_init_screen
    call demo_init_music
    if ENABLE_COMPLETE_SCREEN_COPY
        call demo_init_copy_screen ; TODO remove later to make it appear progressively
    endif
    call show_static_sprite
    ret

    if ENABLE_COMPLETE_SCREEN_COPY
demo_init_copy_screen
    ld hl, 0x8000
    ld de, 0xc000
    ld bc, 0x4000
    ldir
    ret
    endif

; Ensure the screen is BLACK and CRTC setup properly
demo_init_screen
.ga_init
    ; set up the screen in black
    ld bc, 0x7F54: xor a
.all_black_loop
    out (c), a : out (c), c
    inc a
    cp 17
    jr nz, .all_black_loop    
    ; set mode 0
    ld a, 0x8c : out (c), a

    
    ; set up the CRTC as expected
.setup_crtc
    ld bc, 0xbc00 + 0 : out (c), c : ld bc, 0xbd00 + 64-1 : out (c), c
    ld bc, 0xbc00 + 1 : out (c), c : ld bc, 0xbd00 + SCREEN_WIDTHS_WORD : out (c), c
    ld bc, 0xbc00 + 2 : out (c), c : ld bc, 0xbd00 + 50 : out (c), c
    ld bc, 0xbc00 + 7 : out (c), c : ld bc, 0xbd00 + 29 : out (c), c
    ld bc, 0xbc00 + 6 : out (c), c : ld bc, 0xbd00 + SCREEN_HEIGHT_CHARS : out (c), c
    ld bc, 0xbc00 + 12 : out (c),c : ld bc, 0xbd00 + 0x30 : out (c), c
    ld bc, 0xbc00 + 13 : out (c),c : ld bc, 0xbd00 : out (c), c
    ret

; Prepare the player to play the music
demo_init_music
    print "TODO - write music init"
    ret


demo_run
    ld b, 0xf5
.vsync_loop
    in a, (c)
    rra
    jr nc, .vsync_loop


    call demo_frame_init
    call demo_frame_run


    jp demo_run



;; handle the current effects of the frame
demo_frame_run
    di
    call spectral_sprite_move_along_curve
    ei
    ret

;;
;; During init, we
;; - setup the current palette as it may change over time
;; TODO handle the animate part of the screen
demo_frame_init
    ;ld hl, palette_sprites_monochrome_only
    ;ld hl, palette_sprites_monochrome_and_background
    ;ld hl, palette_sprites_spectral_and_background
    ld hl,  palette_all_visible
    ;ld hl, palette_background_only 
    call ga_set_palette

    ret

    ; all common stuffs
    include "constants.asm"
    include "lib.asm"
    include "palettes.asm"

    ; effects code and data
    include "spectral_sprites.asm"