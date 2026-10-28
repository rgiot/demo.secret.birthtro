    include once "animate_lib.asm"

    ;; animate the right eye






;;
;; The animation cannot run if the scroll is too low because it takes too much tim
cancel_animation_1_if_needed
    ld a, (demo_frame_run.wait_lines-1)
    cp ANIMATION_SCROLLER_POSITION_THRESHOLD
    ret c

    ; we go back one step in the animation
    ld hl, (replace_background_sprite_1.ptr)
    dec hl : dec hl
    ld (replace_background_sprite_1.ptr), hl

    pop hl ; we consume the return address of the drwining routine to really leave
    ret


; Generate sprites data and code


	; load the sprites
	repeat SPRITE1_NB_FRAMES, frame, 0
SPRITE1_STEP{{frame}}_CONTENT equ load(RIGHT_EYE{{frame}}_SPR)
	endrepeat

	; Generate the transition routines
	repeat SPRITE1_NB_FRAMES, src, 0
		repeat SPRITE1_NB_FRAMES, dest, 0
			; We generate only consecutive sprites for the animation purposes
			if {dest}!={src} && (({dest}=={src}+1) || ({src}=={dest}+1))

                print "Generate sprite display code for sprite ", {src}, " to sprite ", {dest}

				SPRITE1_FROM{{src}}_TO{{dest}}_HISTOGRAM equ histogram_delta(SPRITE1_STEP{{src}}_CONTENT, SPRITE1_STEP{{dest}}_CONTENT)
				SPRITE1_FROM{{src}}_TO{{dest}}_ARGSORT equ list_argsort(SPRITE1_FROM{{src}}_TO{{dest}}_HISTOGRAM)

				;print "histogram of sprite ", {src}, " to sprite ", {dest}, " is ", SPRITE1_FROM{{src}}_TO{{dest}}_HISTOGRAM
				;print "argsort of sprite ", {src}, " to sprite ", {dest}, " is ", SPRITE1_FROM{{src}}_TO{{dest}}_ARGSORT

                TMP_ADR=$
				GENERATE_SPRITE_DISPLAY_CODE_DELTA(1, {src}, {dest}, true, true, 96) ; only difference between the two sprites is shown
                print "Generated sprite display code for sprite ", {src}, " to sprite ", {dest}, " at address ", {hex}TMP_ADR, " with size ", {hex}($-TMP_ADR)
			endif

		endrepeat
	endrepeat

;; This bank is mapped at the same address as the one of animate.asm, so we MUST NOT use its
;; animation_do_nothing: in this bank the same address points in the middle of another routine.
animation2_do_nothing ret

macro ANIMATION2_STEP routine
	repeat NB_REPEATED_FRAMES_IN_ANIMATION-1, i, 0
		dw animation2_do_nothing
	endrepeat
	dw {routine}
endm


reset_background_sprite_1
	ld hl, replace_background_sprite_1.table
	ld (replace_background_sprite_1.ptr), hl


	ret

replace_background_sprite_1
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
		ANIMATION2_STEP(replace_background_sprite_1_0_1)
		ANIMATION2_STEP(replace_background_sprite_1_1_2)
		ANIMATION2_STEP(replace_background_sprite_1_2_1)
		ANIMATION2_STEP(replace_background_sprite_1_1_0)
	dw 0

    print {hex}$