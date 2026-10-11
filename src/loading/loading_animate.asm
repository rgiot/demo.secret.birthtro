
	include '../animate_lib.asm'

	SMOKE_NB_FRAMES equ 9

	repeat SMOKE_NB_FRAMES, frame, 0
SMOKE_STEP{{frame}}_CONTENT equ load("../../data/VAPEUR_00" + {frame} +".SPR")
	endrepeat



	repeat SMOKE_NB_FRAMES, src, 0
		if {src} < SMOKE_NB_FRAMES-1
			dest = {src}+1
		else
			dest = 0
		endif

		print "Generate sprite display code for sprite ", {src}, " to sprite ", {dest}

;		SMOKE_FROM{{src}}_TO{{dest}}_HISTOGRAM equ histogram_delta(SMOKE_STEP{{src}}_CONTENT, SMOKE_STEP{{dest}}_CONTENT)
;		SMOKE_FROM{{src}}_TO{{dest}}_ARGSORT equ list_argsort(SMOKE_FROM{{src}}_TO{{dest}}_HISTOGRAM)

		;print "histogram of sprite ", {src}, " to sprite ", {dest}, " is ", SMOKE_FROM{{src}}_TO{{dest}}_HISTOGRAM
		;print "argsort of sprite ", {src}, " to sprite ", {dest}, " is ", SMOKE_FROM{{src}}_TO{{dest}}_ARGSORT

		TMP_ADR=$
		GENERATE_SPRITE_DISPLAY_CODE_DELTA(2, {src}, {dest}, true) ; only difference between the two sprites is shown
		print "Generated sprite display code for sprite ", {src}, " to sprite ", {dest}, " at address ", {hex}TMP_ADR, " with size ", {hex}($-TMP_ADR)

	endrepeat


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
