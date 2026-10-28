;; July 2026
;; Krusty/Benediction

    include once "inner://ga.asm"
    include once 'demosystem/public.asm'
    include once "macros.asm"
    include once "functions.asm"
    include "constants.asm"


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
    call demo_adapt_for_crtc ; Need to be the very first stuff
    call demo_init_screen
    call demo_init_music
    if ENABLE_COMPLETE_SCREEN_COPY
        call demo_init_copy_screen ; TODO remove later to make it appear progressively
    endif

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

    include "demosystem/arkos_setup_crtc.asm"

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
    AKS_HANDLE_CRTC_TRANSITION(crtc_table)
    ret

demo_adapt_for_crtc
    call ds_crtc_detector
    cp 1 : jr z, .patch_crtc1
    cp 3 : jr z, .patch_crtc3
    cp 4 : jr z, .patch_crtc4
    ret
.patch_crtc3
.patch_crtc4
    ret
.patch_crtc1
    ld a, 6 : ld (scroller_show.crtc_register), a
    if ! HIDE_SCROLLER
        ld hl, SCREEN_HEIGHT_CHARS<<8 : ld (scroller_show.crtc_value), hl
    endif
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


; XXX Can be moved in an ara that will be overriden later
crtc_detection 
	DS_PRODUCE_CRTC_DETECTOR_ROUTINE()

demo_run
    call secure_vsync
    call demo_frame_init
    call demo_frame_run

    jp demo_run




;; handle the current effects of the frame
demo_frame_run
    DEBUG(GA_RED)
    ; We provide at maximum one halt to the sinus raster
    CALL_IN_BANK(spectral_sprite_handle, SPECTRAL_BANK)
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


    if false    
    ; compensate to avoid bad surprises
    ld a, (.wait_lines-1)
    add 0-max(SCROLLER_SINE)-1
    neg
    ld b, a
.wait_lines2
    defs 64 - duration(djnz $)-1
    djnz .wait_lines2

    endif


    DEBUG(GA_RED)

    call demo_play_music_frame

    DEBUG(GA_GREEN)


   ld a, 0 : .writter_enable equ $-1
   or a
   call nz, writter_draw_page_step
   DEBUG(GA_BRIGHT_CYAN)
   ld a, 0 : .animated_background_activated equ $-1
   or a
   jr z, .no_animated_background


    ld a, 1 : .reset_animation equ $-1
    or a
    jr z, .no_reset_animation


    ; set the state of the animation to let the writter know it is playing and it should not copy now
    ld a, ANIMATION_STATE_PLAYING
    ld (animation_state), a
    xor a : ld (.reset_animation), a
    CALL_IN_BANK(reset_background_sprite_0, ANIMATE_BANK)
    CALL_IN_BANK(reset_background_sprite_1, ANIMATE2_BANK)
.no_reset_animation

   CALL_IN_BANK(replace_background_sprite_0, ANIMATE_BANK)
   CALL_IN_BANK(replace_background_sprite_1, ANIMATE2_BANK)
.no_animated_background
    DEBUG(GA_BLACK)

	ei



    ret

    assert $<0x4000 || $>0x8000
    animation_state db ANIMATION_STATE_FINISHED


;;
;; During init, we
;; - setup the current palette as it may change over time
;; - setup the scroller curve
;; TODO handle the animate part of the screen
demo_frame_init
    call event_handler

    ld hl, PALETTE_INITIAL : .selected_palette equ $-2
    call ga_set_palette


    ; handle the scroller sine
    ld hl, SCROLLER_CURVE_DATA : .curve_ptr equ $-2
    inc l
    ld (.curve_ptr), hl
    ld a, (hl)
    ld (demo_frame_run.wait_lines-1), a
    ret



; Prepare the player to play the music
demo_init_music
    assert $<=0x4000 || $>=0x8000
    ld bc, 0x7fc6: out (c), c
    ld hl, MUSIC : xor a
    call PLY_AKG_Init
    ld bc, 0x7fc0: out (c), c
    assert $<=0x4000 || $>=0x8000
    ret




    assert $<0x4000

;; The music is played once per frame, by demo_frame_run.
;; While the restart code is running, it is played by the interrupt handler instead
;; (see event_routine_restart) as the frame loop does not play it at the right pace.
demo_play_music_frame
    ld a, 0 : .played_by_interrupt equ $-1
    or a : jr z, .play
        xor a : ld (.played_by_interrupt), a ; already played during this frame
        ret
.play
    di : call demo_play_music : ei
    ret

;; Number of interrupts (6 per frame) between two plays of the music: it is played at 50Hz.
MUSIC_INTERRUPT_PERIOD equ 6

demo_interrupt_counter db 0

;; Bank configuration (gate array command) currently selected.
;; The music lives in another bank, so the handler has to restore the one of the interrupted code.
;; Maintained by SELECT_BANK/RESTORE_BANK/CALL_IN_BANK
current_ram_config dw 0x7fc0

;; Install/remove the handler that plays the music under interrupt.
demo_install_interrupt_handler
    di
        xor a : ld (demo_interrupt_counter), a
        ld a, 0xc3 : ld (0x38), a
        ld hl, demo_interrupt_handler : ld (0x39), hl
    ei
    ret

demo_remove_interrupt_handler
    di
        ld hl, 0xc9fb : ld (0x38), hl ; ei : ret
    ei
    ret

demo_interrupt_handler
    push af : push bc : push de : push hl : push ix : push iy
    ex af, af' : exx
    push af : push bc : push de : push hl

    ld a, (demo_interrupt_counter)
    inc a
    cp MUSIC_INTERRUPT_PERIOD
    jr c, .save_counter
        call demo_play_music
        ld a, 1 : ld (demo_play_music_frame.played_by_interrupt), a
        xor a
.save_counter
    ld (demo_interrupt_counter), a

    pop hl : pop de : pop bc : pop af
    exx : ex af, af'
    pop iy : pop ix : pop hl : pop de : pop bc : pop af
    ei
    ret


;; Called by the interrupt handler (interrupts are disabled)
demo_play_music
    ld a, 0 : .activated equ $-1 ; music is not played at the very beginning
    or a : ret z

    ld bc, 0x7fc6: out (c), c
        ; a restart has been requested: lower the volume progressively, then stop and rewind the music
        ld a, 0 : .fading equ $-1
        or a : jr z, .play

        ld a, 5 : .fade_delay equ $-1 ; the volume is lowered every 5 plays
        dec a : ld (.fade_delay), a
        jr nz, .play
        ld a, 5 : ld (.fade_delay), a

        ld a, (PLY_AKG_FADE) : inc a : ld (PLY_AKG_FADE), a
        cp 16 : jr nz, .play

        ; fade out is over: stop the PSG, rewind the music, and wait for the next START_MUSIC event
        call PLY_AKG_Stop
        ld hl, MUSIC : xor a
        call PLY_AKG_Init
        xor a
        ld (PLY_AKG_FADE), a
        ld (.fading), a
        ld (.activated), a
        jr .end

.play
        call PLY_AKG_Play
.end
    ld bc, (current_ram_config) : out (c), c
    ret

    assert $<0x4000

    ; all common stuffs
    include "lib.asm"
    include "palettes.asm"
    include "events.asm"



    ; effects code and data
    include "split_scroller.asm"
    include "writter.asm"
