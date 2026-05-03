;;
; Step 3 - Generation of scroller code from a pregenerated buffer of textures
;
; Krusty/Benediction
; May 2026
;
; The main idea is as follow:
; For a given split raster line we need to generate the display code from the split raster code of the scroller. To do so we use a ring buffer that is fed with the scroll text (here we do not try to feed it is is manually done) and read to generate the soruce code for the split raster.
; However the source code is build in a kind of destructive way at the beginning and end of a line to be sure we always scroll left of 4 nops and use 64 nops of timing
;  - out (c), e activate a split raster/border pixel
;  - out (c), d deactivate a split raster/border pixel
; By convention a letter MUST end with a space
; IDEA: by also using a ring buffer for the scroller routines, we could allow a horizontal translation of the text
; IDEA it is probably possible to have a zooming scroller too by generating zoomed version of the splits 
;
SCROLLER_NB_VERTICAL_BLOCS equ 8
;; The number of times a routine is dulicated
BLOC_HEIGHT equ 8



	org 0x4000

init
	run $
	di
		ld hl, 0xc9fb : ld (0x38), hl
		ld bc, 0xbc00 + 1 : out (c), c : ld bc, 0xbd00 + 96/2 : out (c), c
		ld bc, 0xbc00 + 2 : out (c), c : ld bc, 0xbd00 + 50 : out (c), c
		ld bc, 0xbc00 + 7 : out (c), c : ld bc, 0xbd00 : out (c), c
		ld bc, 0xbc00 + 6 : out (c), c : ld bc, 0xbd00 + 38 : out (c), c
		ld hl, 0x1000
		ld bc, 0xbc00 + 12 : out (c),c : ld bc, 0xbd00 : out (c), h
		ld bc, 0xbc00 + 13 : out (c),c : ld bc, 0xbd00 : out (c), l
		ld bc, 0x7f8c : out (c), c

		ld bc, 0x7f10 : out (c), c
		ld bc, 0x7f40 : out (c), c
		ld sp, $


		; generate 1set code
		call scroller_update_code
	ei

frame

	call secure_vsync

	halt


	halt
	di
	defs 13 ; ensure proper alignement
	call scroller_show

	ld bc, 0x7f00 : out(c), c
	ld bc, 0x7f4b : out(c), c
	call scroller_handle_scrolling
	ld bc, 0x7f54 : out(c), c

	ei
	jp frame


;; Show the split raster scroller
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

	ld sp, scroller_routine_table
.selected_jump_table equ $-2

	ret ; => execute the first line of scroller
.continue
	out (c), d

	ld sp, 0
.backup_sp equ $-2
	ret

scroller_handle_scrolling

	; make the screen shift to the left by one nop
	ld a, (scroller_show.left_shift)
	inc a
	and %11
	ld (scroller_show.left_shift), a
	; when arriving once again at 0, it means we need to move the code of 4 nops
	; and we'll try another code location

	ret nz

	call scroller_update_code
	ret

scroller_update_code
		BREAKPOINT
	repeat SCROLLER_NB_VERTICAL_BLOCS, line, 0
		ld ix, SCROLLER_CONFIG_{{line}}
		ld h, high(SCROLLER_RING_BUFFER_{{line}})
		ld de, SCROLLER_CODE_{{line}}
		call scroller_generate_line_code
	endr
	ret





scroller_routine_table
	repeat 8, line, 0
		repeat BLOC_HEIGHT
			dw SCROLLER_CODE_{{line}}
		endr
	endr
	dw scroller_show.continue

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


;; The code at the very start of the display routine.
scroller_template_start_code
SCROLLER_TEMPLATE_START_CODE_DURATION equ duration(out (c), d); The first fir opcode is always OUT


	align 256
;; The code at the very end of the display routine.
;; we must use inc l to copy it. But in fact it is not mandatory to be aligned
scroller_template_end_code
TICKER START SCROLLER_TEMPLATE_END_CODE_DURATION
.start
	ret
.end
TICKER STOP


;; The number of bytes to copy to generate the end of the display routine
SCROLLER_TEMPLATE_END_CODE_SIZE equ scroller_template_end_code.end - scroller_template_end_code.start



	struct SCROLLER_LINE_DATA
		; the position to feed the next column of char
		; XXX not used in this test file. Will be used in the real scroller scenario
		ring_buffer_write_pos db
		; the position to read the next column of char
		ring_buffer_read_pos db
		; the last start color configuration
		last_color_config db list_get(opcode(
			out (c), d
		),1)
	endstruct


	macro BUFFER_READ_BYTE
		ld a, (hl) : inc l
	endm

	macro CODE_WRITE_BYTE
		ld (de), a : inc de
	endm


;;
; Generate the code for a split raster line.
; The code must be at 64 nops of course and must be generated from the ring buffer of the line data.
; Start and end code cannot be exactly the same of the ring buffer to respect nop alignment and 64 nops duration
; Input: 
;  - IX: address of the configuration of the line
;  - H: high byte of the ring buffer
;  - DE: address of the line code to generate 
; Side effect:
;  - Alter the ring buffer at the beginning to properly handle the 4 nops shift
;  - alter ring_buffer_read_pos to be at the next 4 nops position
scroller_generate_line_code
	ld a, list_get(opcode(out (c), d), 0) ; set the first byte of out
	CODE_WRITE_BYTE()

	; set up a nop counter
	ld a, 64 - SCROLLER_TEMPLATE_START_CODE_DURATION - SCROLLER_TEMPLATE_END_CODE_DURATION
	ex af, af'


	; Get the true start of the split raster code
	ld l, (ix + SCROLLER_LINE_DATA.ring_buffer_read_pos) ; => HL=buffer location to read


	; Handle first out and first 4 nops coloumn
	ld b, 0 ; counter number of nops met before out
	ld c, 0 ;presence of out. is it usefull ?

	; Duplicate this code for the potential 4 nops positions
	repeat 4, nb_nops, 0
		BUFFER_READ_BYTE()
		or a
		jr z, .has_nops{{nb_nops}}
	.no_nops{{nb_nops}}
		inc c
; XXX I comment the code because I do not understand why I handled 2 cases
;		if {nb_nops} == 0
;			; there was no nop at all
;			; we decrement L to move back before the out code
;			dec l
;		else
			; there was at least one nop
			; here we have a out (c), e|d and we want to update the last color configuration with it and then continue
			; the code generation
			BUFFER_READ_BYTE() ; get the register of out (c), e|d
			ld (ix + SCROLLER_LINE_DATA.last_color_config), a ; store it for the next code generation
;		endif
		jr .generate_first_color_from_a
	.has_nops{{nb_nops}}
		inc b  ; we will have one nop to add
	endr

	; if we arrive here, it is because there was 4 sucessive nops.
	; it is the easy case. But still we need to read the saved 1st colot

.generate_first_color_from_ix
	ld a, (ix + SCROLLER_LINE_DATA.last_color_config)
.generate_first_color_from_a
	; generate the first instruction that selects the appropriate color
	; its duration is already stored in af'
	CODE_WRITE_BYTE()


	; patch the ring buffer to handle the 4 nops shift
	; as well as the construction of the first instructions
	; patch the ring buffer to handle the 4 nops shift
	; as well as the construction of the first instructions
.patch_ring_buffer_start_and_scroll_buffer_index
	; Here HL points to the next instruction
	; B contains the number of nops to inject in replacement of the moved out (c), e|d

	ld a, b
.test_zero_nop
	or a : jr nz, .handle_nops
.handle_no_nops
	; B=0 => nothing to modify in the configuration or the buffer
	;        l contains the position of the next instruction
	;        and the current color has already been copied
	ld (ix + SCROLLER_LINE_DATA.ring_buffer_read_pos), l
	jr .add_instructions


   ; To keep the code simple we repeat the same thing for B=1,B=2,B=3, B=4
   ; in fact B=4 does not need at all all steps
.handle_nops
	; B=1 C=1 +2
	;          *nop : out (1) : out (2) :< next  <= buffer before
	;           nop :  nop    : *nop    : <next   <= buffer after
	; B=2 C=1 +2
	;          *nop : nop : out (1) : out (2) :< next  <= buffer before
	;           nop : nop : *nop    : nop     : <next   <= buffer after
	; B=3 C=1 +2
	;          *nop : nop : nop : out (1) : out (2) :< next  <= buffer before
	;           nop : nop : *nop: nop     : nop     :< next   <= buffer after
    ; B=4 C=0 +4
	;          *nop : nop : nop : nop :< next  <= buffer before
	;           nop : nop : nop : nop :< next   <= buffer after
	cp 4 : jr nz, .inject_nops

.handle_4_nops
	; we already move l after the 4 nops, so we just store its value
	ld (ix + SCROLLER_LINE_DATA.ring_buffer_read_pos), l
	jr .add_instructions



	; really does the nops injection in the read buffer
.inject_nops
	xor a ; NOP instruction
.inject_nops_loop
	dec l ; (was pointing on the next instruction to execute)
	ld (hl), a
	djnz .inject_nops_loop

	ld (ix + SCROLLER_LINE_DATA.ring_buffer_read_pos), l ; update the new ring buffer read
	jr .add_instructions





	; HL points on the buffer start
	; af' contains the number of remaining nops
.add_instructions
	ex af, af'
	ld c, a
	ex af, af'

.add_instruction_loop
	BUFFER_READ_BYTE() ; get the first byte of the next instruction to add
	or a
	jr z, .try_handle_nop
.try_handle_out
	ld a, c : cp 4 ; check if we have enough time to inject the out instruction
	jr nc, .really_handle_out
.unable_to_handle_out
	dec l ; move back to the previous instruction
	jr .stabilize_code
.really_handle_out
	ld a, list_get(opcode(out (c), d), 0) ; set the first byte of out (we've lost this value previouslly read)
	CODE_WRITE_BYTE() ; write the out instruction
	BUFFER_READ_BYTE() ; get the register of out (c), e|d
	CODE_WRITE_BYTE() ; write the out register
	ld a, -4 : add c : ld c, a ; update the number of nops left
	jr .add_instruction_loop

.try_handle_nop
	ld a, c : cp 1 ; check if we have enough time to inject nop instruction
	jr nc, .really_handle_nop
.unable_to_handle_nop
	dec l ; move back to the previous instruction
	jr .stabilize_code
.really_handle_nop
	xor a ; NOP instruction
	CODE_WRITE_BYTE() ; write the nop
	dec c
	jr .add_instruction_loop


	jr .add_instructions

	; Stabilize the code to be sure it takes exactly 64 nops
	; af' is not up to date, the real value is in c
.stabilize_code
	ex af, af'
	ld a, c ; restore the real value
	or a : jr z, .finalize_code
	ld b, a
	xor a ; NOP
.stabilize_loop
		CODE_WRITE_BYTE() ; write nop
	djnz .stabilize_loop

	; Here we want to add the instructions at the end of the line
	; at least a nop, but maybe something to play with rasters too
.finalize_code
	ld hl, scroller_template_end_code
	ld b, SCROLLER_TEMPLATE_END_CODE_SIZE
.finalize_loop
		BUFFER_READ_BYTE()
		CODE_WRITE_BYTE()
	djnz .finalize_loop

	ret



	; reserve the space for the scroller routines
	repeat SCROLLER_NB_VERTICAL_BLOCS, line, 0
SCROLLER_CONFIG_{{line}}
	SCROLLER_LINE_DATA(SCROLLER_RING_BUFFER_{{line}}.test_write, SCROLLER_RING_BUFFER_{{line}}.test_read)

SCROLLER_CODE_{{line}}
.first_color out (c), d ; Always starts with no pixel, will be updated by the code generation
	defs 64
	endr






	macro BUFFER_FILLER pos


	out(c), e: out(c), d
	out(c), e: out (c), e : out(c), d
	out(c), e: out(c), d
	out(c), e: out (c), e  :out(c), d

	out(c), e: out(c), d
	out(c), e: out(c), d
	out(c), e: out(c), d
	out(c), e: nop: out(c), d
	out(c), e: nop: nop: out(c), d
	out(c), e: nop: nop: nop : out(c), d

	out (c), e
	repeat {pos}
		nop
	endr
	out (c), d
	endm



;; Manually made scroller ring buffer for testing.
;; should be generated programmatically in a real world scenario.
;; Here we have a bit of empty data, then 5 repetitions of S letter
;; To ease the writting of the routines, the ring buffer is read destructively: the reading head of the buffer may modify the code to handle properly 4 nops scroll and split/pixel start

	align 256
SCROLLER_RING_BUFFER_0
.test_read
	defs 10*4
	repeat 10
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
	endr
	BUFFER_FILLER(0)
.test_write

	align 256
SCROLLER_RING_BUFFER_1
.test_read
	defs 10*4
	repeat 10
		out(c), e
		out(c), d
		nop:nop:nop:nop
		nop:nop:nop:nop
	endr
	BUFFER_FILLER(1)
.test_write

	align 256
SCROLLER_RING_BUFFER_2
.test_read
	defs 10*4
	repeat 10
		out(c), e
		out(c), d
		nop:nop:nop:nop
		nop:nop:nop:nop
	endr
	BUFFER_FILLER(2)
.test_write

	align 256
SCROLLER_RING_BUFFER_3
.test_read
	defs 10*4
	repeat 10
		nop
		out(c), e
		nop : nop: nop : nop : nop : nop
		out(c), d
		nop
	endr
	BUFFER_FILLER(3)
.test_write

	align 256
SCROLLER_RING_BUFFER_4
.test_read
	defs 10*4
	repeat 10
		nop : nop : nop : nop 
		nop : nop : nop : nop 
		out(c), e
		out(c), d
	endr
	BUFFER_FILLER(3)
.test_write

	align 256
SCROLLER_RING_BUFFER_5
.test_read
	defs 10*4
	repeat 10
		nop : nop : nop : nop 
		nop : nop : nop : nop 
		out(c), e
		out(c), d
	endr
	BUFFER_FILLER(2)
.test_write

	align 256
SCROLLER_RING_BUFFER_6
.test_read
	defs 10*4
	repeat 10
		nop : nop : nop : nop 
		nop : nop : nop : nop 
		out(c), e
		out(c), d
	endr
	BUFFER_FILLER(1)
.test_write

	align 256
SCROLLER_RING_BUFFER_7
.test_read
	defs 10*4
	repeat 10
		out(c), e
		nop : nop : nop : nop
		nop : nop : nop
		out(c), d
		nop
	endr
	BUFFER_FILLER(0)
.test_write