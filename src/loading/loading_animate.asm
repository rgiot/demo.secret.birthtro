
	include '../animate_lib.asm'

	SPRITE2_NB_FRAMES equ 9
	SPRITE2_HEIGHT equ 92
	SPRITE2_WIDTH equ 28//2
	SPRITE2_LOCATION equ 0xc000 + (0x800*(20%8)) + (80*(20//8)) + 10   ; = 0xE0AA


NB_REPEATED_FRAMES_IN_ANIMATION equ 20
animation_do_nothing ret
macro ANIMATION_STEP routine
	dw {routine}
	repeat NB_REPEATED_FRAMES_IN_ANIMATION-1, i, 0
		dw animation_do_nothing
	endrepeat
endm


	repeat SPRITE2_NB_FRAMES, frame, 0
SPRITE2_STEP{{frame}}_CONTENT equ load(string_concat("../../data/VAPEUR_00" ,{frame},".SPR"))
	endrepeat



	repeat SPRITE2_NB_FRAMES, src, 0
		if {src} < SPRITE2_NB_FRAMES-1
			dest = {src}+1
		else
			dest = 0
		endif

		print "Generate sprite display code for sprite ", {src}, " to sprite ", dest

		SPRITE2_FROM{{src}}_TO{dest}_HISTOGRAM equ histogram_delta(SPRITE2_STEP{{src}}_CONTENT, SPRITE2_STEP{dest}_CONTENT)
		SPRITE2_FROM{{src}}_TO{dest}_ARGSORT equ list_argsort(SPRITE2_FROM{{src}}_TO{dest}_HISTOGRAM)

		;print "histogram of sprite ", {src}, " to sprite ", {dest}, " is ", SPRITE2_FROM{{src}}_TO{{dest}}_HISTOGRAM
		;print "argsort of sprite ", {src}, " to sprite ", {dest}, " is ", SPRITE2_FROM{{src}}_TO{{dest}}_ARGSORT

		TMP_ADR=$
		GENERATE_SPRITE_DISPLAY_CODE_DELTA(2, {src}, {eval}dest, false, false, 80) ; only difference between the two sprites is shown
		print "Generated sprite display code for sprite ", {src}, " to sprite ", dest, " at address ", {hex}TMP_ADR, " with size ", {hex}($-TMP_ADR)

	endrepeat


animate_sprite_2
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
	call call_hl
	ret
.over
    ld a, ANIMATION_STATE_FINISHED
    ld (animation_state), a
    ret

.table
		ANIMATION_STEP(replace_background_sprite_2_0_1)
		ANIMATION_STEP(replace_background_sprite_2_1_2)
		ANIMATION_STEP(replace_background_sprite_2_2_3)
		ANIMATION_STEP(replace_background_sprite_2_3_4)
		ANIMATION_STEP(replace_background_sprite_2_4_5)
		ANIMATION_STEP(replace_background_sprite_2_5_6)
		ANIMATION_STEP(replace_background_sprite_2_6_7)
		ANIMATION_STEP(replace_background_sprite_2_7_8)
		ANIMATION_STEP(replace_background_sprite_2_8_0)
	dw 0


animation_state db ANIMATION_STATE_PLAYING

call_hl jp hl