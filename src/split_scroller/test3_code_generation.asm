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

SNASET CRTC_SEL, 0

SCROLLER_NB_VERTICAL_BLOCS equ 8
;; The number of times a routine is dulicated
BLOC_HEIGHT equ 8


;;
; Exchange 2 16bits values in memory
; Modified: HL, DE
macro SWITCH_VALUES addr1, addr2
	ld hl, ({addr1}) : ld de, ({addr2})
	ld ({addr1}), de : ld ({addr2}), hl
endm


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

		call scroller_generate_initial_code
	ei

frame

	call secure_vsync

	halt


	halt
	di
	defs 13 - 1 ; ensure proper alignement
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
	ld bc, 0xbc00+8 : out (c), c ; CRTC 0
	ld de, 0x0000 + %110000     ; CRTC0
	;ld bc, 0xbc00+6 : out (c), c ; CRTC 1
	;ld de, 0x0000 + 38 ; CRTC 0 (screen height)
	inc b

	; Handle the 4 x 1 nop left shift
	jr .wait1
.left_shift equ $-1
.wait4
	nop
.wait3
	nop
.wait2
	nop
.wait1

	ld sp, (scroller_configuration_table.current_executing_table) ; get the table for the fram
	                                                              ; it contains the list of routines to call
	ret ; => execute the first line of scroller
.continue ; while the very last one ends here
	out (c), d ; ensure the split is deactivated

	ld sp, 0. ; restore the stack
.backup_sp equ $-2
	ret

scroller_handle_scrolling
	call scroller_update_code_partially
	ret



scroller_generate_initial_code
	; generate 2 batches of routines to be able to setup the double buffering system
	; each batch generates 2 routines to handle the 4 nops shift
	ld b, 2*SCROLLER_NB_VERTICAL_BLOCS/(SCROLLER_NB_VERTICAL_BLOCS/4)
.loop
	push bc
		call scroller_update_code_partially ; SCROLLER_NB_VERTICAL_BLOCS/4 lines are generated at each call (2 in our case)
	pop bc
	djnz .loop
	ret

;; update 1/4 of the code
scroller_update_code_partially
	; handle the scroll position
	ld a, (scroller_show.left_shift)
	BREAKPOINT
	inc a
	and %11
	ld (scroller_show.left_shift), a
	cp 0
	jr nz, .compute_delta

	; Every 4 updates, switch the buffers
.switch_everything

	; XXX A is not modified and is 0
	SWITCH_VALUES(
		scroller_configuration_table.current_generating_code_table, 
		scroller_configuration_table.next_generating_code_table
	)
	SWITCH_VALUES(
		scroller_configuration_table.current_executing_table,
		scroller_configuration_table.next_executing_table
	)

	jr .get_position

	; get the appropriate location in the table
.compute_delta
	add a, a ; x2. we need to double because we handle 2 lines per 2 lines
	assert SCROLLER_NB_VERTICAL_BLOCS/4 == 2, "the former code relies on the fact that we handle 2 lines per 2 lines"


	ld e, a ; save a
	add a ; x2
	add a ; x4
	add e ; x5
	assert SCROLLER_ROUTINE_GENERATION_TABLE_ENTRY == 5, "the following code relies on the fact that the entry is 5 bytes long"
.get_position
	ld hl, (scroller_configuration_table.current_generating_code_table) ; Get the table
	ld d, 0 : ld e, a
	add hl, de ; Get the right line in the table from 0 to 3


	; HL = address of the current entry that contains a SCROLLER_ROUTINE_GENERATION_TABLE_ENTRY
	; get the two routines to update
	repeat SCROLLER_NB_VERTICAL_BLOCS/4
		ld e, (hl) : inc hl : ld d, (hl) : inc hl ; get the config address
		ld ix, de                                 ; and store it in ix

		ld e, (hl) : inc hl : ld d, (hl) : inc hl ; get the routine address

		ld a, (hl) : inc hl                       ; get the high byte of the ring buffer
		push hl
			call scroller_generate_line_code
		pop hl
	endr


	;	BREAKPOINT
	; XXX this commented code was building all routines in a row
	;repeat SCROLLER_NB_VERTICAL_BLOCS, line, 0
	;	ld ix, SCROLLER_CONFIG_{{line}}
	;	ld h, high(SCROLLER_RING_BUFFER_{{line}})
	;	ld de, SCROLLER_CODE_{{line}}
	;	call scroller_generate_line_code
	;endr
	ret


scroller_configuration_table
.current_generating_code_table dw scroller_routine_generation_table_a
.next_generating_code_table dw scroller_routine_generation_table_b
.current_executing_table dw scroller_show_routine_table_b
.next_executing_table dw scroller_show_routine_table_a




scroller_show_routine_table_a
	repeat SCROLLER_NB_VERTICAL_BLOCS, line, 0
		repeat BLOC_HEIGHT
			dw SCROLLER_CODE_{{line}}_a
		endr
	endr
	dw scroller_show.continue

scroller_show_routine_table_b
	repeat SCROLLER_NB_VERTICAL_BLOCS, line, 0
		repeat BLOC_HEIGHT
			dw SCROLLER_CODE_{{line}}_b
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
		color_config db list_get(opcode(
			out (c), d
		),1)
	endstruct

		assert SCROLLER_LINE_DATA == 3
		assert SCROLLER_LINE_DATA.ring_buffer_write_pos == 0
		assert SCROLLER_LINE_DATA.ring_buffer_read_pos == 1
		assert SCROLLER_LINE_DATA.color_config == 2

	macro BUFFER_READ_BYTE
		ld a, (hl) : inc l ; this is an aligned 256 bytes ring buffer
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
;  - A: high byte of the ring buffer
;  - DE: address of the line code to generate 
; Side effect:
;  - Alter the ring buffer at the beginning to properly handle the 4 nops shift
;  - alter ring_buffer_read_pos to be at the next 4 nops position
scroller_generate_line_code
	ld h, a ; H = high byte of the ring buffer
	ld a, list_get(opcode(out (c), d), 0) ; set the first byte of any out
	CODE_WRITE_BYTE() ; and write it to the generated code

	; set up a nop counter in af'
	; on the 64 available nops, remove duration of first out and the end code to know how many nops we can have in the middle to handle the scroll and the split start
	ld a, 64 - (SCROLLER_TEMPLATE_START_CODE_DURATION + SCROLLER_TEMPLATE_END_CODE_DURATION)
	ex af, af'


	; Get the true start of the split raster code
	ld l, (ix + SCROLLER_LINE_DATA.ring_buffer_read_pos) ; => HL=buffer location to read


	; Handle first out and first 4 nops column
	ld b, 0 ; counter number of nops met before out
	ld c, 0 ; presence of out. is it usefull ? remove ?

	; Duplicate this code for the potential 4 nops positions
	repeat 4, nb_nops, 0
		BUFFER_READ_BYTE()
		or a
		jr z, .has_nops{{nb_nops}}
	.no_nops{{nb_nops}}
		inc c ; we have a out, so increase the counter
; XXX I comment the code because I do not understand why I handled 2 cases
;		if {nb_nops} == 0
;			; there was no nop at all
;			; we decrement L to move back before the out code
;			dec l
;		else
			; there was at least one nop
			; here we have a out (c), e|d and we want to update the last color configuration with it and then continue
			; the code generation
			BUFFER_READ_BYTE() ; get the byte that encode the register of out (c), e|d
			ld (ix + SCROLLER_LINE_DATA.color_config), a ; store it for the next code generation
;		endif
		jr .generate_first_color_from_a
	.has_nops{{nb_nops}}
		inc b  ; we will have one nop to add
		       ; and continue with next loop iteration
	endr

	; if we arrive here, it is because there were 4 sucessive nops.
	; it is the easy case. But still we need to read the saved 1st color

.generate_first_color_from_ix
	ld a, (ix + SCROLLER_LINE_DATA.color_config) ;get the color from config
.generate_first_color_from_a
	; generate the first instruction that selects the appropriate color
	; its duration is already stored in af'
	CODE_WRITE_BYTE()


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
	ld (hl), a ; ensure we really have a nop in the buffer
	djnz .inject_nops_loop

	ld (ix + SCROLLER_LINE_DATA.ring_buffer_read_pos), l ; update the new ring buffer read
	;jr .add_instructions ; this is already the next instruction

	; HL points on the buffer start
	; af' contains the number of remaining nops
.add_instructions
	ex af, af'
	ld c, a
	ex af, af'
	; c is used a nop counter to avoid switching with af' in the loop

.add_instruction_loop

	BUFFER_READ_BYTE() ; get the first byte of the next instruction to add
	or a
	jr z, .try_handle_nop

.try_handle_out
	ld a, c : cp duration(out (c), d) ; check if we have enough time to inject the out instruction
	jr nc, .really_handle_out
.unable_to_handle_out
	dec l ; move back to the start of instruction to treat it later
	jr .stabilize_code
.really_handle_out
	ld a, list_get(opcode(out (c), d), 0) ; set the first byte of out (we've lost this value previouslly read)
	CODE_WRITE_BYTE() ; write the 1srt byte of the out instruction
	BUFFER_READ_BYTE() ; get the register of out (c), e|d
	CODE_WRITE_BYTE() ; write the out register
	ld a, 0-duration(out (c), d) : add c : ld c, a ; consume out
	jr .add_instruction_loop

.try_handle_nop
	ld a, c : cp 1 ;duration(nop) ; check if we have enough time to inject nop instruction
	jr nc, .really_handle_nop
.unable_to_handle_nop
	dec l ; move back to the nop to treat it later
	jr .stabilize_code
.really_handle_nop
	xor a ; NOP instruction
	CODE_WRITE_BYTE() ; write the nop
	dec c ; we consume one nop from the counter
	jr .add_instruction_loop

	; Stabilize the code to be sure it takes exactly 64 nops
	; af' is not up to date, the real value is in c
.stabilize_code
	ex af, af'
	ld a, c ; restore the real value that was in c
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



struct SCROLLER_ROUTINE_GENERATION_TABLE_ENTRY
	config_address dw ; The adress of the line configuration to use for the generation of the routine
	code_address dw ; The adresse of the routine to generate
	ring_buffer_high_byte db ; The high byte address of the ring buffer to use for this line
endstruct




scroller_routine_generation_table_a
	repeat SCROLLER_NB_VERTICAL_BLOCS, line, 0
		SCROLLER_ROUTINE_GENERATION_TABLE_ENTRY(
			SCROLLER_CONFIG_{{line}},
			SCROLLER_CODE_{{line}}_a, 
			high(SCROLLER_RING_BUFFER_{{line}})
		)
	endr

scroller_routine_generation_table_b
	repeat SCROLLER_NB_VERTICAL_BLOCS, line, 0
		SCROLLER_ROUTINE_GENERATION_TABLE_ENTRY(
			SCROLLER_CONFIG_{{line}},
			SCROLLER_CODE_{{line}}_b, 
			high(SCROLLER_RING_BUFFER_{{line}})
		)
	endr


	; reserve the space for the scroller routines
	; we use a double buffering system to be able to write one routine while executing another
	; this allows to also divide the workload by 4
	repeat SCROLLER_NB_VERTICAL_BLOCS, line, 0
SCROLLER_CONFIG_{{line}}
	SCROLLER_LINE_DATA(SCROLLER_RING_BUFFER_{{line}}.test_write, SCROLLER_RING_BUFFER_{{line}}.test_read)

SCROLLER_CODE_{{line}}_a
.first_color out (c), d ; Always starts with no pixel, will be updated by the code generation
	repeat 64
		db 0xDE, 0xAD ; canari value to be sure it is completly replaced
	endr

SCROLLER_CODE_{{line}}_b
.first_color out (c), d ; Always starts with no pixel, will be updated by the code generation
	repeat 64
		db 0xBE, 0xEF ; canari value to be sure it is completly replaced
	endr
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