;;
; Step 4 - Generation of the texture buffer for the scroller
;
; Krusty/Benediction
; May 2026
; July 2026 - Add raster stuff
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
; Sadly it does not work to change the color each line, it does not even work one line out of two (in fact, out itself is too much)

SNASET CRTC_SEL, 0

SCREEN_WIDTH equ 96
SCREEN_HEIGHT_CHARS equ 21

SCROLLER_NB_VERTICAL_BLOCS equ 8
;; The number of times a routine is dulicated
SPECTRAL_BLOC_HEIGHT equ 8

	include "inner://ga.asm"


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
		ld bc, 0xbc00 + 7 : out (c), c : ld bc, 0xbd00 + 29 : out (c), c
		ld bc, 0xbc00 + 6 : out (c), c : ld bc, 0xbd00 + SCREEN_HEIGHT_CHARS : out (c), c
		ld bc, 0xbc00 + 12 : out (c),c : ld bc, 0xbd00 + 0x30 : out (c), c
		ld bc, 0xbc00 + 13 : out (c),c : ld bc, 0xbd00 : out (c), c
		ld bc, 0x7f8c : out (c), c


        ; set up the BACKGROUND_IMG_PALETTE for the background
        ld bc, 0x7f00 : out (c), c : ld a, (BACKGROUND_IMG_PALETTE+0) : out (c), a
        ld bc, 0x7f01 : out (c), c : ld a, (BACKGROUND_IMG_PALETTE+1) : out (c), a
        ld bc, 0x7f02 : out (c), c : ld a, (BACKGROUND_IMG_PALETTE+2) : out (c), a
        ld bc, 0x7f03 : out (c), c : ld a, (BACKGROUND_IMG_PALETTE+3) : out (c), a

        ; set up the BACKGROUND_IMG_PALETTE for the background
		ld bc, 0x7f10 : out (c), c : ld bc, 0x7f54 : out (c), c
		ld sp, $

		call scroller_generate_initial_code

frame

	call secure_vsync

	ei : nop
	halt


	halt

	
	di
	defs 64 - (3+4+3+4+1+1) + 1 +  13 - 1  -1 -1-1; ensure proper alignement
	                                              ; Sadly, it is properly aligned on the left but not the right
	call scroller_show

	ld bc, 0x7f00 : out(c), c
	ld bc, 0x7f4b : out(c), c
	call scroller_handle_scrolling
	ld bc, 0x7f45 : out(c), c
	call scroller_handle_char_update
	ld bc, 0x7f54 : out(c), c


	jp frame


;; Show the split raster scroller
scroller_show
	ld (.backup_sp), sp

	; split raster configuration
	; XXX could be done BEFORE the di if needed
	ld bc, 0x7f10 : out (c), c
	ld hl, SCROLLER_COLORED_RASTERS_DATA
	outi : inc b
	exx
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
		repeat SPECTRAL_BLOC_HEIGHT-1
			dw SCROLLER_CODE_{{line}}_a
		endr
		dw scroller_change_color
	endr
	dw scroller_show.continue

scroller_show_routine_table_b
	repeat SCROLLER_NB_VERTICAL_BLOCS, line, 0
		repeat SPECTRAL_BLOC_HEIGHT-1
			dw SCROLLER_CODE_{{line}}_b
		endr
		dw scroller_change_color
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
scroller_template_end_code_even
TICKER START SCROLLER_TEMPLATE_END_CODE_DURATION_EVEN
.start

	ret
.end
TICKER STOP


scroller_change_color
TICKER START SCROLLER_COLOR_CHANGE_DURATION
	out (c), d
    exx
		outi 
		inc b
	exx
TICKER STOP
	defs 64 - duration(ret) - SCROLLER_COLOR_CHANGE_DURATION
	ret



;; The number of bytes to copy to generate the end of the display routine
SCROLLER_TEMPLATE_END_CODE_EVEN_SIZE equ scroller_template_end_code_even.end - scroller_template_end_code_even.start

;assert SCROLLER_TEMPLATE_END_CODE_DURATION_ODD == SCROLLER_TEMPLATE_END_CODE_DURATION_EVEN, "the duration of the end code must be the same for odd and even lines"
SCROLLER_TEMPLATE_END_CODE_DURATION equ SCROLLER_TEMPLATE_END_CODE_DURATION_EVEN

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

	;; Read a byte in the selected ring buffer and move the read head forward
	macro BUFFER_READ_BYTE
		ld a, (hl) : inc l ; this is an aligned 256 bytes ring buffer
	endm

	;; Write a byte in the generated code and move the write head forward
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

	; The nop budget of the middle section is a compile-time constant:
	; it is loaded directly in C at .add_instructions instead of transiting through af'

	; Get the true start of the split raster code
	ld l, (ix + SCROLLER_LINE_DATA.ring_buffer_read_pos) ; => HL=buffer location to read


	; Handle first out and first 4 nops column
	ld b, 0 ; counter number of nops met before out
	        ; (the out-presence counter that was in C was never read: removed)

	; Duplicate this code for the potential 4 nops positions
	repeat 4, nb_nops, 0
		BUFFER_READ_BYTE()
		or a
		jr z, .has_nops{{nb_nops}}
	.no_nops{{nb_nops}}
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
.add_instructions
	; C = nop budget of the middle section: on the 64 available nops, remove
	;     the duration of the first out and of the end code
	; B = first byte of any out (c), e|d opcode, kept there for the whole loop
	ld bc, list_get(opcode(out (c), d), 0)*256 + 64 - (SCROLLER_TEMPLATE_START_CODE_DURATION + SCROLLER_TEMPLATE_END_CODE_DURATION)

.add_instruction_loop

	BUFFER_READ_BYTE() ; get the first byte of the next instruction to add
	or a
	jr z, .start_nop_run

.try_handle_out
	ld a, c : sub duration(out (c), d) ; carry if we do not have enough time to inject the out instruction
	jr c, .unable_to_handle_out
.really_handle_out
	ld c, a ; consume the out from the nop counter
	ld a, b ; set the first byte of out (we've lost this value previouslly read)
	CODE_WRITE_BYTE() ; write the 1srt byte of the out instruction
	BUFFER_READ_BYTE() ; get the register of out (c), e|d
	CODE_WRITE_BYTE() ; write the out register
	jr .add_instruction_loop

	; nops are the most frequent content: once one is met, stay in a
	; tight loop as long as nops follow and the counter allows it
.start_nop_run
	; A is already 0, ie a NOP instruction
	inc c : dec c ; check the nop counter without destroying A
	jr z, .unable_to_handle_nop
.nop_run
	CODE_WRITE_BYTE() ; write the nop
	dec c ; we consume one nop from the counter
	jr z, .finalize_code ; counter exhausted: nothing else can fit and there
	                     ; is no nop left for the stabilization
	                     ; (L already points on the next unread instruction)
	BUFFER_READ_BYTE() ; get the first byte of the next instruction to add
	or a
	jr z, .nop_run
	jr .try_handle_out ; a non null byte is a out to handle (or to postpone)

.unable_to_handle_nop
	dec l ; move back to the nop to treat it later
	jr .finalize_code ; the counter is 0: no stabilization nop to write

.unable_to_handle_out
	dec l ; move back to the start of instruction to treat it later
	; and fall through the stabilization

	; Stabilize the code to be sure it takes exactly 64 nops.
	; Here C < duration(out (c), d): there are 0 to 3 nops to write
.stabilize_code
	xor a ; NOP instruction
	inc c : dec c : jr z, .finalize_code
	CODE_WRITE_BYTE() ; write nop
	dec c : jr z, .finalize_code
	CODE_WRITE_BYTE() ; write nop
	dec c : jr z, .finalize_code
	CODE_WRITE_BYTE() ; write nop
	; C cannot exceed 3 here: fall through

	; Here we want to add the instructions at the end of the line
	; at least a nop, but maybe something to play with rasters too
.finalize_code
	ld hl, scroller_template_end_code_even
	repeat SCROLLER_TEMPLATE_END_CODE_EVEN_SIZE
		BUFFER_READ_BYTE()
		CODE_WRITE_BYTE()
	endr

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
	SCROLLER_LINE_DATA(
		SCROLLER_RING_BUFFER_{{line}}.test_write, 
		SCROLLER_RING_BUFFER_{{line}}.test_read
	)

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



;;
; Write the line of a given character in the ring buffer of a given line.
; Input:
;  - HL: address of the line data
;  - DE: address of the ring buffer write position
; Output:
;  - HL: address of the next line data
;  - DE: address of the next ring buffer write position
scroller_write_char_line
	ld b, (hl) : inc hl ; get the number of bytes to write for this line
.write_loop
		ld a, (hl) : inc hl
		ld (de), a : inc e
	djnz .write_loop
	ret


;; State of the progressive (8 frames) character drawing
scroller_pending_char
.line_data dw 0 ; pointer to the data of the next char line to write
.next_line db 8 ; next line to write (0-7); 8 = nothing pending

;;
; Write at most ONE line of the pending char per frame (instead of all 8 in
; a burst). Selection guarantees >= 8 frames between two chars (min char =
; 4 nops of a single out + 4 frames of 1-nop-precision scroll), so the 8
; steps always complete before the next char is selected.
scroller_write_char_step
	ld a, (scroller_pending_char.next_line)
	cp 8 : ret nc ; nothing (left) to draw
	inc a : ld (scroller_pending_char.next_line), a
	dec a
	; jump to the unrolled writer for this line
	add a : ld e, a : ld d, 0
	ld hl, .jump_table
	add hl, de
	ld a, (hl) : inc hl : ld h, (hl) : ld l, a
	jp (hl)

.jump_table
	repeat 8, line, 0
		dw .write_line_{{line}}
	endr

	repeat 8, line, 0
.write_line_{{line}}
	ld hl, (scroller_pending_char.line_data)
	; Get the buffer write position for this line in DE
	ld a, (SCROLLER_CONFIG_{{line}} + SCROLLER_LINE_DATA.ring_buffer_write_pos) : ld e, a
	ld d, high(SCROLLER_RING_BUFFER_{{line}})
	call scroller_write_char_line
	ld a, e : ld (SCROLLER_CONFIG_{{line}} + SCROLLER_LINE_DATA.ring_buffer_write_pos), a ; save the write position in the ring buffer for this line
	ld (scroller_pending_char.line_data), hl ; HL was advanced to the next line data
	ret
	endr


;;
;; Orchestrate the update of the char.
;; This has to be done every N nops, with N depending on the previous char
;; by construction N cannot be smaller than 4, so we can update each char in 4 frames. Also each char has a displacement of 4 nops, so with still have this securoty with chars of width 0

scroller_handle_char_update
	ld a, 1
.previous_char_duration equ $-1

	dec a : ld (.previous_char_duration), a
	call z, scroller_select_new_char ; time to select a new char (sets the pending drawing state)
	jp scroller_write_char_step      ; and each frame, write at most one pending line

scroller_select_new_char

	BREAKPOINT

	; Read the char code
	ld hl, scroller_text
.text_location equ $-2
	ld a, (hl)

	cp 255 : jr nz, .save_next_char_position

	ld hl, scroller_text
	ld a,(hl)
	

.save_next_char_position

	inc hl
	ld (.text_location), hl



	; read the char data
.read_char_data
	add a
	ld e, a : ld d, 0
	ld hl, FONT_CHAR_TABLE
	add hl, de
	ld e, (hl) : inc hl : ld d, (hl) ; get char font address

	; handle the char duration
	ld a, (de) : ld (scroller_handle_char_update.previous_char_duration), a
	add 3 ; add the 3 extra steps for a nop precise scroller
	inc de 

	; defer the actual writing: one line per frame via scroller_write_char_step
	ld (scroller_pending_char.line_data), de ; DE already points to the first line data
	xor a : ld (scroller_pending_char.next_line), a
	ret

;;
; Each letter has a variable number of bytes to represent a line.
; So we need to encode the number of bytes to write in the ring buffer for each line of the letter.
; db <nb nops to draw the letter> 
; db <nb bytes of line 0>, <the bytes> ...
; db <nb vytes of line 1>, <the bytes> ...
; ...


; Constraints
; - the duration of each line of a char must be the same
; - each char can have a various duration
; - each line must finish in off mode


	;; set the pixel for the font
	macro FONT_ON extra
		assert {extra} >= 0
		out (c), e
		if {extra} > 0
			FONT_WAIT({extra})
		endif
	endm

	;; reset the pixel for the font
	macro FONT_OFF extra
		assert {extra} >= 0
		out (c), d
		if {extra} > 0
			FONT_WAIT({extra})
		endif
	endm

	;; Set waiting time
	macro FONT_WAIT duration
		; TODO use out (c), d|e when possible to be more efficient
		if {duration} > 0
		;	repeat {duration}
		;		nop
		;	endr
			defs {duration}
		endif
	endm

	macro FONT_START_LINE
letter_{SELECTED_FONT_LETTER}_line_{CURRENT_FONT_LINE}
	db letter_{SELECTED_FONT_LETTER}_line_{CURRENT_FONT_LINE}_size  ; the number of bytes to write for this line
	
	TICKER START CHAR_{SELECTED_FONT_LETTER}_LINE_{CURRENT_FONT_LINE}_NOPS_COUNTER
	endm
	
	macro FONT_FINISH_LINE
		TICKER STOP
letter_{SELECTED_FONT_LETTER}_line_{CURRENT_FONT_LINE}_size equ $ - letter_{SELECTED_FONT_LETTER}_line_{CURRENT_FONT_LINE} - 1

		CURRENT_FONT_LINE = CURRENT_FONT_LINE + 1
	endm
	
	macro FONT_START_LETTER name
		SELECTED_FONT_LETTER = "{name}"
		CURRENT_FONT_LINE = 0

letter_{SELECTED_FONT_LETTER}
letter_{SELECTED_FONT_LETTER}_nb_nops db CHAR_{SELECTED_FONT_LETTER}_LINE_{CURRENT_FONT_LINE}_NOPS_COUNTER ; same value for each line of the letter to ease the code generation
	endm

	macro FONT_STOP_LETTER
		; we want each line to strictly use the same number of nops 
		assert CHAR_{SELECTED_FONT_LETTER}_LINE_0_NOPS_COUNTER == CHAR_{SELECTED_FONT_LETTER}_LINE_1_NOPS_COUNTER, SELECTED_FONT_LETTER, ": each line of the character must use the same number of nops"
		assert CHAR_{SELECTED_FONT_LETTER}_LINE_0_NOPS_COUNTER == CHAR_{SELECTED_FONT_LETTER}_LINE_2_NOPS_COUNTER, SELECTED_FONT_LETTER, ": each line of the character must use the same number of nops"
		assert CHAR_{SELECTED_FONT_LETTER}_LINE_0_NOPS_COUNTER == CHAR_{SELECTED_FONT_LETTER}_LINE_3_NOPS_COUNTER, SELECTED_FONT_LETTER, ": each line of the character must use the same number of nops"
		assert CHAR_{SELECTED_FONT_LETTER}_LINE_0_NOPS_COUNTER == CHAR_{SELECTED_FONT_LETTER}_LINE_4_NOPS_COUNTER, SELECTED_FONT_LETTER, ": each line of the character must use the same number of nops"
		assert CHAR_{SELECTED_FONT_LETTER}_LINE_0_NOPS_COUNTER == CHAR_{SELECTED_FONT_LETTER}_LINE_5_NOPS_COUNTER, SELECTED_FONT_LETTER, ": each line of the character must use the same number of nops"
		assert CHAR_{SELECTED_FONT_LETTER}_LINE_0_NOPS_COUNTER == CHAR_{SELECTED_FONT_LETTER}_LINE_6_NOPS_COUNTER, SELECTED_FONT_LETTER, ": each line of the character must use the same number of nops"
		assert CHAR_{SELECTED_FONT_LETTER}_LINE_0_NOPS_COUNTER == CHAR_{SELECTED_FONT_LETTER}_LINE_7_NOPS_COUNTER, SELECTED_FONT_LETTER, ": each line of the character must use the same number of nops"
		; the progressive drawing writes one line per frame, so a char must last at least 8 frames
		assert CHAR_{SELECTED_FONT_LETTER}_LINE_0_NOPS_COUNTER >= 8, SELECTED_FONT_LETTER, ": chars must be at least 8 nops wide so the 8-step drawing finishes before the next char"
	endm


	;; Generate the necessary code for a line stored within an array of ' ' and '.'
	macro FONT_CREATE_LINE line
		FONT_START_LINE()
		
		PREVIOUS_PIXEL = '.'
		PREVIOUS_PIXEL_COUNT = 0
		CURRENT_LINE = {line}
		CURRENT_LINE_SIZE = list_len(CURRENT_LINE)
		CURRENT_PIXEL_INDEX = 0
		FIRST_OPCODE_EMITTED = false

		while CURRENT_PIXEL_INDEX < CURRENT_LINE_SIZE
			CURRENT_PIXEL = list_get(CURRENT_LINE, CURRENT_PIXEL_INDEX)

			if CURRENT_PIXEL != '.' && CURRENT_PIXEL != '#'
				fail "Invalid pixel value. Only ' ' and '#' are allowed"
			endif

			if CURRENT_PIXEL == PREVIOUS_PIXEL
				; we have the same pixel as before, we just need to increase the counter
				PREVIOUS_PIXEL_COUNT = PREVIOUS_PIXEL_COUNT + 1
			else
				if !FIRST_OPCODE_EMITTED
					; here we can safely emit the wait
					FONT_WAIT(PREVIOUS_PIXEL_COUNT)
				else
					if PREVIOUS_PIXEL_COUNT < 4
						fail "We need at least 4 pixels. The minimum handled by OUT"
					endif
					if PREVIOUS_PIXEL = '.'
						FONT_OFF(PREVIOUS_PIXEL_COUNT - 4) ; we handle the first 4 nops with the previous out (c), e|d
					else
						FONT_ON(PREVIOUS_PIXEL_COUNT - 4) ; we handle the first 4 nops with the previous out (c), e|d
					endif
				endif


				PREVIOUS_PIXEL_COUNT = 1
				PREVIOUS_PIXEL = CURRENT_PIXEL
				FIRST_OPCODE_EMITTED = true

			endif


			CURRENT_PIXEL_INDEX = CURRENT_PIXEL_INDEX + 1
		wend

		if PREVIOUS_PIXEL_COUNT < 4
			fail "We need at least 4 pixels. The minimum handled by OUT"
		endif
		if PREVIOUS_PIXEL = '.'
			FONT_OFF(PREVIOUS_PIXEL_COUNT - 4) ; we handle the first 4 nops with the previous out (c), e|d
		else
			fail "the line must end without pixels"
		endif

		FONT_FINISH_LINE()
	endm

	macro FONT_CREATE_CHAR char, line1, line2, line3, line4, line5, line6, line7, line8
		FONT_START_LETTER({char})

		FONT_CREATE_LINE({line1})
		FONT_CREATE_LINE({line2})
		FONT_CREATE_LINE({line3})
		FONT_CREATE_LINE({line4})
		FONT_CREATE_LINE({line5})
		FONT_CREATE_LINE({line6})
		FONT_CREATE_LINE({line7})
		FONT_CREATE_LINE({line8})

		FONT_STOP_LETTER()

	endm

	macro FONT_CREATE_IPM_LINE line

		IPM_LINE_PIXEL_0 = list_get({line}, 0)
		IPM_LINE_PIXEL_1 = list_get({line}, 1)
		IPM_LINE_PIXEL_2 = list_get({line}, 2)
		IPM_LINE_PIXEL_3 = list_get({line}, 3)

		FONT_CREATE_LINE([
			IPM_LINE_PIXEL_0, IPM_LINE_PIXEL_0, IPM_LINE_PIXEL_0, IPM_LINE_PIXEL_0,
			IPM_LINE_PIXEL_1, IPM_LINE_PIXEL_1, IPM_LINE_PIXEL_1, IPM_LINE_PIXEL_1,
			IPM_LINE_PIXEL_2, IPM_LINE_PIXEL_2, IPM_LINE_PIXEL_2, IPM_LINE_PIXEL_2,
			IPM_LINE_PIXEL_3, IPM_LINE_PIXEL_3, IPM_LINE_PIXEL_3, IPM_LINE_PIXEL_3
		])

	endm

	macro FONT_CREATE_IPM_CHAR char, line1, line2, line3, line4, line5, line6, line7, line8
		FONT_START_LETTER(ipm{char})

		FONT_CREATE_IPM_LINE({line1})
		FONT_CREATE_IPM_LINE({line2})
		FONT_CREATE_IPM_LINE({line3})
		FONT_CREATE_IPM_LINE({line4})
		FONT_CREATE_IPM_LINE({line5})
		FONT_CREATE_IPM_LINE({line6})
		FONT_CREATE_IPM_LINE({line7})
		FONT_CREATE_IPM_LINE({line8})

		FONT_STOP_LETTER()
	endm

	macro NOP_FONT_SAME_AS_IPM char
letter_{char} equ letter_ipm{char}
letter_{char}_line_0 equ letter_ipm{char}_line_0
	endm


SCROLLER_FONTS

		; Space has a width that corresponds to the duration of a out
		FONT_CREATE_CHAR( sp,
			".........",
			".........",
			".........",
			".........",
			".........",
			".........",
			".........",
			"........."
		)
letter_impsp equ letter_sp


		FONT_CREATE_IPM_CHAR( a,
			".#..",
			"#.#.",
			"#.#.",
			"###.",
			"#.#.",
			"#.#.",
			"#.#.",
			"#.#."
		)
		; our nop resolution font
		FONT_CREATE_CHAR( a,
			"....####........",
			".##########.....",
			"####....####....",
			"####....####....",
			"############....",
			"####....####....",
			"####....####....",
			"####....####...."
		)


		FONT_CREATE_IPM_CHAR( h,
			"#.#.",
			"#.#.",
			"#.#.",
			"###.",
			"#.#.",
			"#.#.",
			"#.#.",
			"#.#."
		)
		NOP_FONT_SAME_AS_IPM(h)


		FONT_CREATE_IPM_CHAR( i,
			"###.",
			".#..",
			".#..",
			".#..",
			".#..",
			".#..",
			".#..",
			"###."
		)
		FONT_CREATE_CHAR( i,  /*Here we use only one out column instead of 3 in the origial font*/
			"####.....",
			"####.....",
			"####.....",
			"####.....",
			"####.....",
			"####.....",
			"####.....",
			"####....."
		)


		FONT_CREATE_IPM_CHAR( r,
			"###.",
			"#.#.",
			"#.#.",
			"##..",
			"#.#.",
			"#.#.",
			"#.#.",
			"#.#."
		)

		FONT_CREATE_CHAR( r,
			"###########.....",
			"####....####....",
			"####....####....",
			"#########.......",
			"####....####....",
			"####....####....",
			"####....####....",
			"####....####...."
		)




		; our nop resolution font
		FONT_CREATE_CHAR( s,
			".###########....",
			"####............",
			"####............",
			".##########.....",
			"........####....",
			"........####....",
			"........####....",
			"###########....."
		)

		; ipm cult out resolution font
		FONT_CREATE_IPM_CHAR( s,
			"###.",
			"#...",
			"#...",
			"###.",
			"..#.",
			"..#.",
			"..#.",
			"###."
		)

		FONT_CREATE_IPM_CHAR( t,
			"###.",
            ".#..",
            ".#..",
            ".#..",
            ".#..",
            ".#..",
            ".#..",
            ".#.."
		)
		NOP_FONT_SAME_AS_IPM(t)





	macro FONT_MAPPING_ENTRY(char)
		@letter={char}
		dw letter_ipm{@letter}
		dw letter_{@letter} ; XXX we cannot directly use {char} because it is replaced with surroundings ''
	endm

	;; Macro to generate the table that maps chars to their font data
	;; take as input a lowercase string and generate the charset command and the table with the mapping for each char to its font data
	;; Generation order space, lower1, upper1, lower2, upper2, ...
	macro FONT_MAPPING_GENERATE lowercase_chars
complete_charset = " " ; very first char is space

		; generate the string to provide to charset directive
		repeat string_len({lowercase_chars}), i, 0
			complete_charset = string_concat(complete_charset, list_get({lowercase_chars}, {i}))
			complete_charset = string_concat(complete_charset, char(int(list_get({lowercase_chars}, {i}))+('A'-'a'))) ; add the upper case version of the char to the charset
		endr

		; really execute charset_directive
		charset complete_charset, 0

		; generate the table of correspondance of each char
FONT_CHAR_TABLE
		dw letter_sp
		repeat string_len({lowercase_chars}), i, 0
			FONT_MAPPING_ENTRY({eval}list_get({lowercase_chars}, {i}))
		endr
	endm


; Generate the data for the mapping beteen a char and its code
FONT_MAPPING
	FONT_MAPPING_GENERATE("ahirst")


; Scroller text data : lower case correspond to IPM font and upper case to the nop resolution font
scroller_text
	db "this is art "
scroller_text2
	db "THIS IS ART "

	repeat 10
		db "this is art "
		db "THIS IS ART "
	endr


	db "tTtTtTtTtTtTtTtTtTtTt" 
	db "hHhHhHhHhHhHhHhHhHhHhH"
	db "iIiIiIiIiIiIiIiIiIiIiI"
	db "sSsSsSsSsSsSsSsSsSsSsS"
	db " "
	db "iIiIiIiIiIiIiIiIiIiIiI"
	db "sSsSsSsSsSsSsSsSsSsSsS"
	db " "
	db "aAaAaAaAaAaAaAaAaAaAaA"
	db "rRrRrRrRrRrRrRrRrRrRrR"
	db "tTtTtTtTtTtTtTtTtTtTtT"
	db "  "
	db 255



	align 256
SCROLLER_COLORED_RASTERS_DATA
.start
	; TODO write the real values of interest for the scroller raster

		db GA_COL_09
		db GA_COL_10
		db GA_COL_18
		db GA_COL_20
		db GA_COL_20
		db GA_COL_18
		db GA_COL_10
		db GA_COL_09
.stop
	db GA_BLACK ; The very last one is black to hide everything




    ; BACKGROUND_IMG_PALETTE
BACKGROUND_IMG_PALETTE
    incbin "../../data/face0_cpc.pal"

; Generate the buffers
; Buffers start empty.
; they are programmatically filled

	repeat SCROLLER_NB_VERTICAL_BLOCS, line, 0
	align 256
SCROLLER_RING_BUFFER_{{line}}
.test_read
	defs 200
.test_write
	endr

    ; screen
    org 0xc000
    incbin "../../data/face0_cpc.scr"