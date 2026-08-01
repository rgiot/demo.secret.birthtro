;; July 2026
;; Krusty/Benediction

    include once "macros.asm"
    include once "inner://ga.asm"



;; We assume everythin is properly loaded in memory, and we just need to run the demo
demo_start

    ; kill the system
    di
        ld hl, 0xC9fb
        ld (0x38), hl
        ld sp, $
    ei

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

    call show_static_sprite             ; init the spectral sprites

    call scroller_generate_initial_code ; init the split scroller

    if true ; does not work at all
    di
    NB_REPEAT equ 30*4+24
    assert NB_REPEAT%8 == 0
    ld b, NB_REPEAT
.consume_scroller_data
    push bc
        call scroller_handle_char_update
        call scroller_handle_scrolling
    pop bc
    djnz .consume_scroller_data
    ei
    endif

    di
    ld hl, WRITTER_PAGE0 : call writter_draw_page_start ; Init the writter
    ei
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
    ld bc, 0xbc00 + 2 : out (c), c
    if SHIFT_SCREEN_FOR_DEBUG
        ld bc, 0xbd00 + 50 + 4 : out (c), c
    else
        ld bc, 0xbd00 + 50 : out (c), c
    endif
    ld bc, 0xbc00 + 7 : out (c), c : ld bc, 0xbd00 + 29 : out (c), c
    ld bc, 0xbc00 + 6 : out (c), c : ld bc, 0xbd00 + SCREEN_HEIGHT_CHARS : out (c), c
    ld bc, 0xbc00 + 12 : out (c),c : ld bc, 0xbd00 + 0x30 : out (c), c
    ld bc, 0xbc00 + 13 : out (c),c : ld bc, 0xbd00 : out (c), c
    ret

; Prepare the player to play the music
demo_init_music
    ld hl, MUSIC : xor a
    call PLY_AKG_Init
    ret


demo_run
    call secure_vsync
    call demo_frame_init
    call demo_frame_run

    jp demo_run



;; handle the current effects of the frame
demo_frame_run
    DEBUG(GA_RED)
    ; We provide at maximum one halt to the sinus raster
    call spectral_sprite_move_along_curve
    DEBUG(GA_WHITE)
    halt


    DEBUG(GA_RED)
    call scroller_handle_char_update
    call scroller_handle_scrolling
    DEBUG(GA_WHITE)
    ; 2 halts before the scroll

    halt
    di


    ; we want to have a sine wave
    ld b, 20
.wait_lines
    defs 64 - duration(djnz $)-1
    djnz .wait_lines

    defs 64 - 6

	call scroller_show 

    ; TODO use the time when the scroll is up to make move big sprites

    ; compensate to avoid bad surprises
    ld a, (.wait_lines-1)
    add 0-max(SCROLLER_SINE)-1
    neg
    ld b, a
.wait_lines2
    defs 64 - duration(djnz $)-1
    djnz .wait_lines2

    defs 64 - 6

 ;   call spectral_sprite_move_along_curve ; x2 movement speed

    DEBUG(GA_RED)

    di : call PLY_AKG_Play : ei
    DEBUG(GA_GREEN)
   call writter_draw_page_step
    DEBUG(GA_BLACK)

	ei



    ret

;;
;; During init, we
;; - setup the current palette as it may change over time
;; - setup the scroller curve
;; TODO handle the animate part of the screen
demo_frame_init
    ;ld hl, palette_sprites_monochrome_only
    ;ld hl, palette_sprites_monochrome_and_background
    ;ld hl, palette_sprites_spectral_and_background
    ld hl,  palette_all_visible
    ;ld hl, palette_background_only
    ;ld hl, palette_writter_only
    call ga_set_palette


    ; handle the scroller sine
    ld hl, SCROLLER_CURVE_DATA : .curve_ptr equ $-2
    inc l
    ld (.curve_ptr), hl
    ld a, (hl)
    ld (demo_frame_run.wait_lines-1), a



    ret

    ; all common stuffs
    include "constants.asm"
    include "lib.asm"
    include "palettes.asm"

    ; music
    include MUSIC_CFG
MUSIC
    include MUSIC_DATA
    include "PlayerAkg.asm"

    ; effects code and data
    include "spectral_sprites.asm"
    include "split_scroller.asm"
    include "writter.asm"
