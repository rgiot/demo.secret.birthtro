	;; We do not want to display complete sprite, but sprite delta between a source sprite and a destintion sprite

    include once 'animate_lib.asm'










;;
;; The animation cannot run if the scroll is too low because it takes too much tim
cancel_animation_0_if_needed
    ld a, (demo_frame_run.wait_lines-1)
    cp ANIMATION_SCROLLER_POSITION_THRESHOLD
    ret c

    ; we go back one step in the animation
    ld hl, (replace_background_sprite_0.ptr)
    dec hl : dec hl
    ld (replace_background_sprite_0.ptr), hl

    pop hl ; we consume the return address of the drwining routine to really leave
    ret


; Generate sprites data and code

;SPRITE0_STEP0_CONTENT equ load("../data/face0_eye0.spr")
;SPRITE0_STEP1_CONTENT equ load("../data/face0_eye1.spr")
;SPRITE0_STEP2_CONTENT equ load("../data/face0_eye2.spr")

	; load the sprites
	repeat SPRITE0_NB_FRAMES, frame, 0
SPRITE0_STEP{{frame}}_CONTENT equ load(LEFT_EYE{{frame}}_SPR)
	endrepeat

	; Generate the transition routines
	repeat SPRITE0_NB_FRAMES, src, 0
		repeat SPRITE0_NB_FRAMES, dest, 0
			; We generate only consecutive sprites for the animation purposes
			if {dest}!={src} && (({dest}=={src}+1) || ({src}=={dest}+1))

                print "Generate sprite display code for sprite ", {src}, " to sprite ", {dest}

				SPRITE0_FROM{{src}}_TO{{dest}}_HISTOGRAM equ histogram_delta(SPRITE0_STEP{{src}}_CONTENT, SPRITE0_STEP{{dest}}_CONTENT)
				SPRITE0_FROM{{src}}_TO{{dest}}_ARGSORT equ list_argsort(SPRITE0_FROM{{src}}_TO{{dest}}_HISTOGRAM)

				;print "histogram of sprite ", {src}, " to sprite ", {dest}, " is ", SPRITE0_FROM{{src}}_TO{{dest}}_HISTOGRAM
				;print "argsort of sprite ", {src}, " to sprite ", {dest}, " is ", SPRITE0_FROM{{src}}_TO{{dest}}_ARGSORT

                TMP_ADR=$
				GENERATE_SPRITE_DISPLAY_CODE_DELTA(0, {src}, {dest}, true, true, 96) ; only difference between the two sprites is shown
                print "Generated sprite display code for sprite ", {src}, " to sprite ", {dest}, " at address ", {hex}TMP_ADR, " with size ", {hex}($-TMP_ADR)
			endif

		endrepeat
	endrepeat



NB_REPEATED_FRAMES_IN_ANIMATION equ 10
animation_do_nothing ret
macro ANIMATION_STEP routine
	dw {routine}
	repeat NB_REPEATED_FRAMES_IN_ANIMATION-1, i, 0
		dw animation_do_nothing
	endrepeat
endm

reset_background_sprite_0
	ld hl, replace_background_sprite_0.table
	ld (replace_background_sprite_0.ptr), hl


	ret

replace_background_sprite_0
	; Get the appropriate routine
	ld hl, .table : .ptr equ $-2
	ld e, (hl) : inc hl : ld d, (hl)
	ld a, e : or d

	jr z, .over ; animation is played just one  time
.not_end
	inc hl
	ld (.ptr), hl


	; and call it
	ex de, hl
	di
	call call_hl
	ei
	ret
.over
    ld a, ANIMATION_STATE_FINISHED
    ld (animation_state), a
    ret

.table
		ANIMATION_STEP(replace_background_sprite_0_0_1)
		ANIMATION_STEP(replace_background_sprite_0_1_2)
		ANIMATION_STEP(replace_background_sprite_0_2_1)
		ANIMATION_STEP(replace_background_sprite_0_1_0)
	dw 0

