;;
; Step 2 for split scroller with a nop precision instead of a out precision
; Try to properly handle left part of scroller
; Krusty/Benediction
; April 2026



SPECTRAL_BLOC_HEIGHT equ 8
MAXIMUM_LINE_SIZE equ 64; TODO really find the minimum value




SHIFT_STEP_FRAMES_DURATION equ 25

	org 0x4000

init
	run $
	di
		ld hl, 0xc9fb : ld (0x38), hl
		ld bc, 0xbc00 + 1 : out (c), c : ld bc, 0xbd00 + 96/2 : out (c), c
		ld bc, 0xbc00 + 2 : out (c), c : ld bc, 0xbd00 + 50 : out (c), c
		ld bc, 0xbc00 + 7 : out (c), c : ld bc, 0xbd00 : out (c), c
		ld hl, 0x1000
		ld bc, 0xbc00 + 12 : out (c),c : ld bc, 0xbd00 : out (c), h
		ld bc, 0xbc00 + 13 : out (c),c : ld bc, 0xbd00 : out (c), l
		ld bc, 0x7f8c : out (c), c

		ld bc, 0x7f10 : out (c), c
		ld bc, 0x7f40 : out (c), c
		ld sp, $
	ei

frame

	call secure_vsync

	halt


	halt
	di

	defs 13 ; ensure proper alignement
	call scroller_show
	call scroller_handle_variants

	ei
	jp frame


;;
; make changethe scroller shift to test stuff
scroller_handle_variants

if TRUE

	; handle a delay to move slowly
	ld a, SHIFT_STEP_FRAMES_DURATION
.delay equ $-1
	dec a
	ld (.delay), a
	ret nz

	ld a, SHIFT_STEP_FRAMES_DURATION
	ld (.delay), a
endif

	; make the screen shift to the left by one nop
	ld a, (scroller_show.left_shift)
	inc a
	and %11
	ld (scroller_show.left_shift), a
	; when arriving once again at 0, it means we need to move the code of 4 nops
	; and we'll try another code location

	ret nz



	ld hl, shift_table
.shift_table_position equ $-2
.reset_table_change
	ld e, (hl)
	inc hl
	ld d, (hl)

	ld a, e : or d
	jr nz, .request_table_change

	ld hl, shift_table
	jr .reset_table_change

.request_table_change
	inc hl
	ld (.shift_table_position), hl
	ld (scroller_show.selected_jump_table), de


	ret


shift_table
	dw scroller_routine_table_right_3
	dw scroller_routine_table_right_2
	dw scroller_routine_table_right_1
	dw scroller_routine_table_right
	dw scroller_routine_table_full
	dw scroller_routine_table_full_left
	dw scroller_routine_table_left_1
	dw scroller_routine_table_left_2
	dw scroller_routine_table_left_3
	dw scroller_routine_table_right_4
	dw 0


scroller_show
	ld (.backup_sp), sp

	; split raster
	;ld bc, 0x7f10 : out (c), c
	;ld de, 0x544b

	;split border
	ld bc, 0xbc00+8 : out (c), c ; (6 on CRTC 1)
	ld de, 0x0000 + %110000     ; 0x0000 + height on CRTC1
	inc b

	jr .wait4
.left_shift equ $-1
.wait4
	nop
.wait3
	nop
.wait2
	nop
.wait1

	ld sp, scroller_routine_table_right_4
.selected_jump_table equ $-2

	ret ; => execute the first line of scroller
.continue
	out (c), d

	ld sp, 0
.backup_sp equ $-2
	ret


scroller_routine_table_full
	repeat 8, line, 0
		repeat SPECTRAL_BLOC_HEIGHT
			dw scroller_line_full{{line}}.start_code ; First start with a single line
		endr
	endr
	dw scroller_show.continue

scroller_routine_table_full_left
	repeat 8, line, 0
		repeat SPECTRAL_BLOC_HEIGHT
			dw scroller_line_full_left{{line}}.start_code ; First start with a single line
		endr
	endr
	dw scroller_show.continue


scroller_routine_table_left_1
	repeat 8, line, 0
		repeat SPECTRAL_BLOC_HEIGHT
			dw scroller_line_left1_{{line}}.start_code ; First start with a single line
		endr
	endr
	dw scroller_show.continue

scroller_routine_table_left_2
	repeat 8, line, 0
		repeat SPECTRAL_BLOC_HEIGHT
			dw scroller_line_left2_{{line}}.start_code ; First start with a single line
		endr
	endr
	dw scroller_show.continue


scroller_routine_table_left_3
	repeat 8, line, 0
		repeat SPECTRAL_BLOC_HEIGHT
			dw scroller_line_left3_{{line}}.start_code
		endr
	endr
	dw scroller_show.continue



scroller_routine_table_right
	repeat 8, line, 0
		repeat SPECTRAL_BLOC_HEIGHT
			dw scroller_line_right{{line}}.start_code
		endr
	endr
	dw scroller_show.continue


scroller_routine_table_right_1
	repeat 8, line, 0
		repeat SPECTRAL_BLOC_HEIGHT
			dw scroller_line_right1_{{line}}.start_code
		endr
	endr

	dw scroller_show.continue

scroller_routine_table_right_2
	repeat 8, line, 0
		repeat SPECTRAL_BLOC_HEIGHT
			dw scroller_line_right2_{{line}}.start_code
		endr
	endr
	dw scroller_show.continue

scroller_routine_table_right_3
	repeat 8, line, 0
		repeat SPECTRAL_BLOC_HEIGHT
			dw scroller_line_right3_{{line}}.start_code
		endr
	endr
	dw scroller_show.continue


scroller_routine_table_right_4
	repeat 8, line, 0
		repeat SPECTRAL_BLOC_HEIGHT
			dw scroller_line_right4_{{line}}.start_code
		endr
	endr
	dw scroller_show.continue





;;Manual code for th S letter at the left with the 3 first 4 nops columns are hidden (ie all the visible columns)


scroller_line_left3_0
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), e ; hidden in the left part of monitor. Encodes the 1st visible color <= here we changed the color

.first_column

	out(c), d

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13+4+4+4
	ret

	org scroller_line_left3_0 + MAXIMUM_LINE_SIZE ;
scroller_line_left3_1
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color <= here we switched to d !!!

.first_column

	nop:nop:nop:nop

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13+4+4+4
	ret




	org scroller_line_left3_1 + MAXIMUM_LINE_SIZE ;
scroller_line_left3_2
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color <= here we switched to d !!!

.first_column


	nop:nop:nop:nop

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13+4+4+4
	ret

	org scroller_line_left3_2 + MAXIMUM_LINE_SIZE ;
scroller_line_left3_3
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color <= here we switched to d !!!

.first_column

	;nop
	;out(c), e

	nop : nop : nop
	nop

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13 + 4 + 4+4
	ret





	org scroller_line_left3_3 + MAXIMUM_LINE_SIZE ;
scroller_line_left3_4
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), e ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	out(c), d

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13+4+4+4
	ret


	org scroller_line_left3_4 + MAXIMUM_LINE_SIZE ;
scroller_line_left3_5
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), e ; hidden in the left part of monitor. Encodes the 1st visible color
.first_column
;.first_column

	out(c), d




	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13+4+4+4
	ret


org scroller_line_left3_5 + MAXIMUM_LINE_SIZE ;
scroller_line_left3_6
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), e ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	out(c), d

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13+4+4+4
	ret



org scroller_line_left3_6 + MAXIMUM_LINE_SIZE ;
scroller_line_left3_7
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color ; <= here we switched to e

.first_columne

	nop : nop : nop
	nop

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13+4+4+4
	ret






;;Manual code for th S letter at the left with the 2 first 4 nops columns are hidden


scroller_line_left2_0
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), e ; hidden in the left part of monitor. Encodes the 1st visible color <= here we changed the color

.first_column

	nop
	nop
	nop
	nop
	out(c), d

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13+4+4
	ret

	org scroller_line_left2_0 + MAXIMUM_LINE_SIZE ;
scroller_line_left2_1
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color <= here we switched to d !!!

.first_column

	nop:nop:nop:nop
	nop:nop:nop:nop

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13+4+4
	ret




	org scroller_line_left2_1 + MAXIMUM_LINE_SIZE ;
scroller_line_left2_2
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color <= here we switched to d !!!

.first_column


	nop:nop:nop:nop
	nop:nop:nop:nop

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13+4+4
	ret

	org scroller_line_left2_2 + MAXIMUM_LINE_SIZE ;
scroller_line_left2_3
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), e ; hidden in the left part of monitor. Encodes the 1st visible color <= here we switched to e !!!

.first_column

	;nop
	;out(c), e

	nop : nop : nop
	out(c), d
	nop

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13 + 4 + 4
	ret




	org scroller_line_left2_3 + MAXIMUM_LINE_SIZE ;
scroller_line_left2_4
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	out(c), e
	out(c), d

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13+4+4
	ret


	org scroller_line_left2_4 + MAXIMUM_LINE_SIZE ;
scroller_line_left2_5
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	out(c), e
	out(c), d




	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13+4+4
	ret


org scroller_line_left2_5 + MAXIMUM_LINE_SIZE ;
scroller_line_left2_6
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	out(c), e
	out(c), d

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13+4+4
	ret



org scroller_line_left2_6 + MAXIMUM_LINE_SIZE ;
scroller_line_left2_7
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), e ; hidden in the left part of monitor. Encodes the 1st visible color ; <= here we switched to e

.first_columne

	nop : nop : nop
	out(c), d
	nop

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13+4+4
	ret






;;Manual code for th S letter at the left with first column fully hidden

scroller_line_left1_0
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), e ; hidden in the left part of monitor. Encodes the 1st visible color <= here we changed the color

.first_column

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	out(c), d

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13+4
	ret

	org scroller_line_left1_0 + MAXIMUM_LINE_SIZE ;
scroller_line_left1_1
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), e ; hidden in the left part of monitor. Encodes the 1st visible color <= here we switched to e !!!

.first_column

	out(c), d
	nop:nop:nop:nop
	nop:nop:nop:nop

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13+4
	ret




	org scroller_line_left1_1 + MAXIMUM_LINE_SIZE ;
scroller_line_left1_2
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), e ; hidden in the left part of monitor. Encodes the 1st visible color <= here we switched to e !!!

.first_column

	out(c), d

	nop:nop:nop:nop
	nop:nop:nop:nop

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13+4
	ret

	org scroller_line_left1_2 + MAXIMUM_LINE_SIZE ;
scroller_line_left1_3
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), e ; hidden in the left part of monitor. Encodes the 1st visible color <= here we switched to e !!!

.first_column

	;nop
	;out(c), e
	nop

	nop : nop: nop : nop : nop : nop
	out(c), d
	nop

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13 + 4
	ret



	org scroller_line_left1_3 + MAXIMUM_LINE_SIZE ;
scroller_line_left1_4
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	nop : nop : nop : nop
	out(c), e
	out(c), d

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13+4
	ret


	org scroller_line_left1_4 + MAXIMUM_LINE_SIZE ;
scroller_line_left1_5
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	nop : nop : nop : nop
	out(c), e
	out(c), d




	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13+4
	ret


org scroller_line_left1_5 + MAXIMUM_LINE_SIZE ;
scroller_line_left1_6
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	nop : nop : nop : nop
	out(c), e
	out(c), d

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13+4
	ret



org scroller_line_left1_6 + MAXIMUM_LINE_SIZE ;
scroller_line_left1_7
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), e ; hidden in the left part of monitor. Encodes the 1st visible color ; <= here we switched to e

.first_columne

	nop : nop : nop : nop
	nop : nop : nop
	out(c), d
	nop

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13+4
	ret





;;
;; Manual code for the S letter fully at the left of the screen


scroller_line_full_left0
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	nop
	out(c), e
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	out(c), d

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13
	ret

	org scroller_line_full_left0 + MAXIMUM_LINE_SIZE ;
scroller_line_full_left1
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	out(c), e
	out(c), d
	nop:nop:nop:nop
	nop:nop:nop:nop

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13
	ret




	org scroller_line_full_left1 + MAXIMUM_LINE_SIZE ;
scroller_line_full_left2
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	out(c), e
	out(c), d

	nop:nop:nop:nop
	nop:nop:nop:nop

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13
	ret

	org scroller_line_full_left2 + MAXIMUM_LINE_SIZE ;
scroller_line_full_left3
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	nop
	out(c), e
	nop : nop: nop : nop : nop : nop
	out(c), d
	nop

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13
	ret



	org scroller_line_full_left3 + MAXIMUM_LINE_SIZE ;
scroller_line_full_left4
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	nop : nop : nop : nop
	nop : nop : nop : nop
	out(c), e
	out(c), d

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13
	ret


	org scroller_line_full_left4 + MAXIMUM_LINE_SIZE ;
scroller_line_full_left5
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	nop : nop : nop : nop
	nop : nop : nop : nop
	out(c), e
	out(c), d




	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13
	ret


org scroller_line_full_left5 + MAXIMUM_LINE_SIZE ;
scroller_line_full_left6
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	nop : nop : nop : nop
	nop : nop : nop : nop
	out(c), e
	out(c), d

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13
	ret



org scroller_line_full_left6 + MAXIMUM_LINE_SIZE ;
scroller_line_full_left7
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	out(c), e
	nop : nop : nop : nop
	nop : nop : nop
	out(c), d
	nop

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13
	ret

;;Manual code for right with last column missing

scroller_line_right1_0
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop

	out (c), d
	out (c), d
	out (c), d

	nop
	out(c), e
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	out(c), d


.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret

	org scroller_line_right1_0 + MAXIMUM_LINE_SIZE ;
scroller_line_right1_1
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop

	out (c), d
	out (c), d
	out (c), d

	out(c), e
	out(c), d
	nop:nop:nop:nop
	nop:nop:nop:nop

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret


	org scroller_line_right1_1 + MAXIMUM_LINE_SIZE ;
scroller_line_right1_2
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop

	out (c), d
	out (c), d
	out (c), d

	out(c), e
	out(c), d
	nop:nop:nop:nop
	nop:nop:nop:nop

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret


	org scroller_line_right1_2 + MAXIMUM_LINE_SIZE ;
scroller_line_right1_3
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop : nop : nop


	out (c), d
	out (c), d
	out (c), d

	nop
	out(c), e
	nop : nop: nop : nop : nop : nop
	out(c), d
	nop

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret




	org scroller_line_right1_3 + MAXIMUM_LINE_SIZE ;
scroller_line_right1_4
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop


	out (c), d
	out (c), d
	out (c), d

	nop : nop : nop : nop
	nop : nop : nop : nop
	out(c), e
	out(c), d

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret


	org scroller_line_right1_4 + MAXIMUM_LINE_SIZE ;
scroller_line_right1_5
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop

	out (c), d
	out (c), d
	out (c), d

	nop : nop : nop : nop
	nop : nop : nop : nop
	out(c), e
	out(c), d



.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret


org scroller_line_right1_5 + MAXIMUM_LINE_SIZE ;
scroller_line_right1_6
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop


	out (c), d
	out (c), d
	out (c), d

	nop : nop : nop : nop
	nop : nop : nop : nop
	out(c), e
	out(c), d

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret



org scroller_line_right1_6 + MAXIMUM_LINE_SIZE ;
scroller_line_right1_7
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop: nop :nop


	out (c), d
	out (c), d
	out (c), d

	out(c), e
	nop : nop : nop : nop
	nop : nop : nop
	out(c), d
	nop

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret





;;Manual code for right with 2 last columns missing

scroller_line_right2_0
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop

	out (c), d
	out (c), d
	out (c), d

	nop
	out(c), e
	nop
	nop
	nop
	nop
	nop
	nop
	nop


.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret

	org scroller_line_right2_0 + MAXIMUM_LINE_SIZE ;
scroller_line_right2_1
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop

	out (c), d
	out (c), d
	out (c), d

	out(c), e
	out(c), d
	nop:nop:nop:nop

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4 ; -4
	ret





	org scroller_line_right2_1 + MAXIMUM_LINE_SIZE ;
scroller_line_right2_2
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop

	out (c), d
	out (c), d
	out (c), d

	out(c), e
	out(c), d

	nop:nop:nop:nop

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret

	org scroller_line_right2_2 + MAXIMUM_LINE_SIZE ;
scroller_line_right2_3
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop : nop : nop


	out (c), d
	out (c), d
	out (c), d

	nop
	out(c), e
	nop : nop: nop : nop : nop : nop
	;out(c), d ;<= impact ?
	nop

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret




	org scroller_line_right2_3 + MAXIMUM_LINE_SIZE ;
scroller_line_right2_4
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop


	out (c), d
	out (c), d
	out (c), d

	nop : nop : nop : nop
	nop : nop : nop : nop
	out(c), e
	;out(c), d ;<= impact ?

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret


	org scroller_line_right2_4 + MAXIMUM_LINE_SIZE ;
scroller_line_right2_5
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop

	out (c), d
	out (c), d
	out (c), d

	nop : nop : nop : nop
	nop : nop : nop : nop
	out(c), e
	;out(c), d <= impact ?



.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret


org scroller_line_right2_5 + MAXIMUM_LINE_SIZE ;
scroller_line_right2_6
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop


	out (c), d
	out (c), d
	out (c), d

	nop : nop : nop : nop
	nop : nop : nop : nop
	out(c), e
	;out(c), d <= impact ?

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret



org scroller_line_right2_6 + MAXIMUM_LINE_SIZE ;
scroller_line_right2_7
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop: nop :nop


	out (c), d
	out (c), d
	out (c), d

	out(c), e
	nop : nop : nop : nop
	nop : nop : nop
	;out(c), d <= impact ?
	nop

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret






;;Manual code for right with 4 last columns missing

scroller_line_right4_0
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d
	out (c), d
	out (c), d

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop

	out (c), d
	out (c), d
	out (c), d

	nop
	nop : nop : nop

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret

	org scroller_line_right4_0 + MAXIMUM_LINE_SIZE ;
scroller_line_right4_1
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d
	out (c), d
	out (c), d

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop

	out (c), d
	out (c), d
	out (c), d

	out(c), e

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4 ; -4
	ret





	org scroller_line_right4_1 + MAXIMUM_LINE_SIZE ;
scroller_line_right4_2
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out(c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop

	out (c), d
	out (c), d
	out (c), d

	out(c), e


.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret

	org scroller_line_right4_2 + MAXIMUM_LINE_SIZE ;
scroller_line_right4_3
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop : nop : nop


	out (c), d
	out (c), d
	out (c), d

	nop
	nop : nop: nop
	;out(c), d ;<= impact ?

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret




	org scroller_line_right4_3 + MAXIMUM_LINE_SIZE ;
scroller_line_right4_4
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop


	out (c), d
	out (c), d
	out (c), d

	nop : nop : nop : nop
	;out(c), d ;<= impact ?

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret


	org scroller_line_right4_4 + MAXIMUM_LINE_SIZE ;
scroller_line_right4_5
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop

	out (c), d
	out (c), d
	out (c), d

	nop : nop : nop : nop
	;out(c), d <= impact ?



.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret




org scroller_line_right4_5 + MAXIMUM_LINE_SIZE ;
scroller_line_right4_6
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop


	out (c), d
	out (c), d
	out (c), d

	nop : nop : nop : nop
	;out(c), d <= impact ?

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret




org scroller_line_right4_6 + MAXIMUM_LINE_SIZE ;
scroller_line_right4_7
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop: nop :nop


	out (c), d
	out (c), d
	out (c), d

	out(c), e
	;out(c), d <= impact ?

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret






;;Manual code for right with 3 last columns missing

scroller_line_right3_0
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d
	out (c), d

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop

	out (c), d
	out (c), d
	out (c), d

	nop
	out(c), e
	nop
	nop
	nop


.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret

	org scroller_line_right3_0 + MAXIMUM_LINE_SIZE ;
scroller_line_right3_1
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d
	out (c), d

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop

	out (c), d
	out (c), d
	out (c), d

	out(c), e
	out(c), d

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4 ; -4
	ret





	org scroller_line_right3_1 + MAXIMUM_LINE_SIZE ;
scroller_line_right3_2
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop

	out (c), d
	out (c), d
	out (c), d

	out(c), e
	out(c), d


.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret

	org scroller_line_right3_2 + MAXIMUM_LINE_SIZE ;
scroller_line_right3_3
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop : nop : nop


	out (c), d
	out (c), d
	out (c), d

	nop
	out(c), e
	nop : nop: nop
	;out(c), d ;<= impact ?

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret




	org scroller_line_right3_3 + MAXIMUM_LINE_SIZE ;
scroller_line_right3_4
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop


	out (c), d
	out (c), d
	out (c), d

	nop : nop : nop : nop
	nop : nop : nop : nop
	;out(c), d ;<= impact ?

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret


	org scroller_line_right3_4 + MAXIMUM_LINE_SIZE ;
scroller_line_right3_5
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop

	out (c), d
	out (c), d
	out (c), d

	nop : nop : nop : nop
	nop : nop : nop : nop
	;out(c), d <= impact ?



.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret



org scroller_line_right3_5 + MAXIMUM_LINE_SIZE ;
scroller_line_right3_6
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop


	out (c), d
	out (c), d
	out (c), d

	nop : nop : nop : nop
	nop : nop : nop : nop
	;out(c), d <= impact ?

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret



org scroller_line_right3_6 + MAXIMUM_LINE_SIZE ;
scroller_line_right3_7
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop: nop :nop


	out (c), d
	out (c), d
	out (c), d

	out(c), e
	nop : nop : nop : nop
	;out(c), d <= impact ?

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1-4
	ret





;;Manual code for the completly visible at the right of the screen

scroller_line_right0
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop

	out (c), d
	out (c), d
	out (c), d

	nop
	out(c), e
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	out(c), d


.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1
	ret

	org scroller_line_right0 + MAXIMUM_LINE_SIZE ;
scroller_line_right1
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop

	out (c), d
	out (c), d
	out (c), d

	out(c), e
	out(c), d
	nop:nop:nop:nop
	nop:nop:nop:nop

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1
	ret




	org scroller_line_right1 + MAXIMUM_LINE_SIZE ;
scroller_line_right2
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop

	out (c), d
	out (c), d
	out (c), d

	out(c), e
	out(c), d

	nop:nop:nop:nop
	nop:nop:nop:nop

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1
	ret

	org scroller_line_right2 + MAXIMUM_LINE_SIZE ;
scroller_line_right3
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop : nop : nop


	out (c), d
	out (c), d
	out (c), d

	nop
	out(c), e
	nop : nop: nop : nop : nop : nop
	out(c), d
	nop

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1
	ret



	org scroller_line_right3 + MAXIMUM_LINE_SIZE ;
scroller_line_right4
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop


	out (c), d
	out (c), d
	out (c), d

	nop : nop : nop : nop
	nop : nop : nop : nop
	out(c), e
	out(c), d

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1
	ret


	org scroller_line_right4 + MAXIMUM_LINE_SIZE ;
scroller_line_right5
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop

	out (c), d
	out (c), d
	out (c), d

	nop : nop : nop : nop
	nop : nop : nop : nop
	out(c), e
	out(c), d



.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1
	ret


org scroller_line_right5 + MAXIMUM_LINE_SIZE ;
scroller_line_right6
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop:nop:nop


	out (c), d
	out (c), d
	out (c), d

	nop : nop : nop : nop
	nop : nop : nop : nop
	out(c), e
	out(c), d

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1
	ret



org scroller_line_right6 + MAXIMUM_LINE_SIZE ;
scroller_line_right7
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
	nop: nop :nop


	out (c), d
	out (c), d
	out (c), d

	out(c), e
	nop : nop : nop : nop
	nop : nop : nop
	out(c), d
	nop

.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13-4+1
	ret





;;
;; Manual code for the S letter somewhere in the middle of the screen

scroller_line_full0
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d
	out (c), d

	nop
	out(c), e
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	out(c), d

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13
	ret

	org scroller_line_full0 + MAXIMUM_LINE_SIZE ;
scroller_line_full1
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d
	out (c), d

	out(c), e
	out(c), d
	nop:nop:nop:nop
	nop:nop:nop:nop

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13
	ret




	org scroller_line_full1 + MAXIMUM_LINE_SIZE ;
scroller_line_full2
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d
	out (c), d

	out(c), e
	out(c), d

	nop:nop:nop:nop
	nop:nop:nop:nop

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13
	ret

	org scroller_line_full2 + MAXIMUM_LINE_SIZE ;
scroller_line_full3
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d
	out (c), d

	nop
	out(c), e
	nop : nop: nop : nop : nop : nop
	out(c), d
	nop

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13
	ret



	org scroller_line_full3 + MAXIMUM_LINE_SIZE ;
scroller_line_full4
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d
	out (c), d

	nop : nop : nop : nop
	nop : nop : nop : nop
	out(c), e
	out(c), d

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13
	ret


	org scroller_line_full4 + MAXIMUM_LINE_SIZE ;
scroller_line_full5
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d
	out (c), d

	nop : nop : nop : nop
	nop : nop : nop : nop
	out(c), e
	out(c), d




	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13
	ret


org scroller_line_full5 + MAXIMUM_LINE_SIZE ;
scroller_line_full6
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d
	out (c), d

	nop : nop : nop : nop
	nop : nop : nop : nop
	out(c), e
	out(c), d

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13
	ret



org scroller_line_full6 + MAXIMUM_LINE_SIZE ;
scroller_line_full7
.last_column_pos
	db .after_last_instruction-.last_column_pos ; position of the last column instruction
	     ; need to be followed by padding
.start_code
.start_color
	out(c), d ; hidden in the left part of monitor. Encodes the 1st visible color

.first_column
	out (c), d
	out (c), d
	out (c), d

	out(c), e
	nop : nop : nop : nop
	nop : nop : nop
	out(c), d
	nop

	out (c), d
	out (c), d
	out (c), d
	out (c), d
	out (c), d
.after_last_instruction

	defs 64 - duration(ret) - duration(out(c), d)*13
	ret


secure_vsync
	ld b, 0xf5
.loop
	in a, (c)
	rra
	jr c, .loop
vsync
	ld b, 0xf5
.loop
	in a, (c)
	rra
	jr nc, .loop
	ret
