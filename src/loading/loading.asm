
	include "inner://ga.asm"


	BORDER_COLOR equ GA_BLACK ; GA_MAUVE
	ENABLE_SID equ true
	ENABLE_SAMPLE equ true


	;; The system is not destroyed at all
	;; so interuptions are cut all the time
	;; TODO the palette should be set right from the basic
	org LOADER_CODE_ADDRESS
MAIN_MEMORY_START
	di

	; Set the palette of the real screen
loading_set_palette
	ld hl , palette
	ld b, 0x7f: xor a
.loop
	ld c, (hl) : inc hl
	out (c), a: out (c), c
	inc a
	cp 16
	jr nz , .loop

	ld bc, 0x7f10 : out (c), c
	ld hl, BORDER_COLOR*256 + 0x8c
	out (c), h : out (c), l


	; Generate the extra palettes
	call generate_color_table ; must be done before the interrupt routine starts using the table


	call animate_start
	call animate_start


	if ENABLE_SID
		; Play the sid music
		;di ; XXX interruption are already disabled
		call Start

	call animate_start


		ld hl, demo_installer
		ld de, 0x0080
		ld bc, demo_installer_end - demo_installer
		ldir
		jp 0x0080
	else
		; stop just to get the interrupted code that handles the music
		jp $
	endif

palette
	incbin "../../data/loading.pal"
	


demo_installer
	; Located in the first page (not in the screen): this code clears the screen, and the
	; area 0x100+ is overwritten by the demo. It must stay under 0x80 bytes (the stack grows down from 0x100)
	rorg 0x0080
		di
		ld bc, 0x7fC4: out (c), c
		ld hl, 0x4000 : ld de, 0x100 : ld bc, 0x4000-0x100 : ldir
		ld bc, 0x7fC5: out (c), c
		ld hl, 0x4000 : ld de, 0x8000 : ld bc, 0x4000 : ldir
		ld bc, 0x7fC0: out (c), c
		ld hl, 0x8000 : ld de, 0x4000 : ld bc, 0x4000 : ldir
		; the demo expects an empty screen (it draws over it)
		ld hl, 0xc000 : ld de, 0xc001 : ld bc, 0x3fff : ld (hl), l : ldir
		ld sp, 0x100
		ld hl, 0xc9fb : ld (0x38), hl
		jp 0x100
	endr
demo_installer_end




; Number of precomputed palettes, played in loop. Only the colors of the pens 10 to 15 are changed
NB_COLOR_PALETTES equ 50
NB_INKS_TO_KEEP equ 10
NB_COLORS_PER_PALETTE equ 16-NB_INKS_TO_KEEP

;; Apply the next precomputed palette (no shuffle is done here, it would be too slow)
handle_color_swap
	ld hl, color_table : .ptr equ $-2
	ld b, 0x7f
	ld a, NB_INKS_TO_KEEP
	repeat NB_COLORS_PER_PALETTE
		ld c, (hl)
		out (c), a : out (c), c
		inc hl : inc a
	endrepeat


	; next palette of the table, or the first one when the end is reached
	ld bc, color_table_end
	or a : sbc hl, bc : add hl, bc ; Z if hl == color_table_end ; add does not change Z
	jr nz, .save_ptr
	ld hl, color_table
.save_ptr
	ld (.ptr), hl
	ret




	; not yet activated
	if false
		include 'loading_animate.asm'
	endif

	; include the music stuff, but we expect it to be smashed afterwhise
	include "sid_player.asm"



;; Fill color_table with NB_COLOR_PALETTES successive shuffles of ARR.
;; Only the first NB_COLORS_PER_PALETTE colors are used for each palette
generate_color_table
	; the seed must not be 0
	ld a, r : or 1 : ld (SEED), a

	ld a, NB_COLOR_PALETTES : ld (.palettes_left), a
	ld hl, color_table : ld (.dest), hl
.loop
	call SHUFFLE ; modifies AF, BC, DE, HL

	ld hl, ARR
	ld de, color_table : .dest equ $-2
	ld bc, NB_COLORS_PER_PALETTE
	ldir
	ld (.dest), de

	ld a, 0 : .palettes_left equ $-1
	dec a : ld (.palettes_left), a
	jr nz, .loop
	ret

color_table
	defs NB_COLOR_PALETTES * NB_COLORS_PER_PALETTE
color_table_end

; claude generated code

; ============================================================
; Z80: Fisher-Yates shuffle of a 27-element byte array
; ============================================================
;
; Algorithm: classic Fisher-Yates, for i = 26 downto 1:
;   j = random integer in [0, i]
;   swap ARR[i], ARR[j]
;
; Random number generation: an 8-bit Galois LFSR (4 instructions,
; no multiply/divide) produces a fast pseudo-random byte on each
; call. To turn that byte into a value in [0, i] without a slow
; 8x8 multiply or a divide, it is masked to 5 bits (0-31, the
; smallest power of two above the max index 26) and rejected /
; retried if the result is greater than i. Since i <= 26 < 32,
; the acceptance probability is always >= 27/32 (~84%), so
; retries are rare and cheap (one AND, one CP, two jumps).
;
; Register usage: B holds the outer loop counter / current bound
; i for the whole routine, so RAND8 must never touch B.
; ============================================================
 
 
ARR:                   ; the 27 bytes to shuffle (fill before calling)
	repeat 27,col,0
		db GA_COL_{{col}}
	endr

SEED:   DEFB    $A5               ; PRNG seed - must never be 0; reseed before use
                                  ; (e.g. from the R register or a frame counter)
 
; ------------------------------------------------------------
; SHUFFLE - shuffles ARR[0..26] in place. Trashes AF, BC, DE, HL.
; ------------------------------------------------------------
SHUFFLE:
        LD      B,26              ; i = 26 downto 1
SH_LOOP:
        CALL    RANDJ             ; A = random j in [0,i]  (i is in B)
        LD      C,A               ; C = j
 
        LD      HL,ARR
        LD      D,0
        LD      E,B
        ADD     HL,DE             ; HL = &ARR[i]
        PUSH    HL
 
        LD      HL,ARR
        LD      E,C
        ADD     HL,DE             ; HL = &ARR[j]   (D is still 0)
        POP     DE                ; DE = &ARR[i]
 
        LD      A,(DE)
        LD      C,(HL)
        LD      (HL),A
        LD      A,C
        LD      (DE),A
 
        DEC     B
        JR      NZ,SH_LOOP
        RET



	ret

; ------------------------------------------------------------
; RANDJ - returns, in A, a random value in [0,B] (B = current i).
; Never modifies B.
; ------------------------------------------------------------
RANDJ:
        CALL    RAND8
        AND     $1F               ; 0-31
        CP      B
        JR      Z,RJ_OK
        JR      C,RJ_OK
        JR      RANDJ             ; > i : reject, retry
RJ_OK:
        RET
 
; ------------------------------------------------------------
; RAND8 - 8-bit Galois LFSR, one pseudo-random byte in A per call.
; Only touches A and SEED - safe to call with any other registers live.
; ------------------------------------------------------------
RAND8:
        LD      A,(SEED)
        SLA     A                 ; bit7 -> carry, bit0 <- 0
        JR      NC,RAND8_NOXOR
        XOR     $1D               ; feedback taps (maximal-length polynomial)
RAND8_NOXOR:
        LD      (SEED),A
        RET


	assert $<0x9000


	; we do not care if they are smashed by the sid player
	include 'loading_animate.asm'

animate_start
	ld a, ANIMATION_STATE_PLAYING
	ld (animation_state), a
	ld hl, animate_sprite_2.table
	ld (animate_sprite_2.ptr), hl
animate_loop
	ld b, 0xf5
	in a, (c)
	rra
	jr nc, animate_loop


	call animate_sprite_2


swap_wait+*: ld a, 0
	inc a
	and 0b111
	ld (swap_wait), a
	call z, handle_color_swap


	ld a, (animation_state)
	cp ANIMATION_STATE_FINISHED
	ret z
	jp animate_loop

	assert $< 0xa000; 'demossystem area. but we should target less
MAIN_MEMORY_STOP



	org 0xc000
SCREEN_MEMORY_START
	incbin "../../data/loading.scr"
SCREEN_MEMORY_STOP



save "C0.2000", MAIN_MEMORY_START, MAIN_MEMORY_STOP-MAIN_MEMORY_START
save "C0.C000", SCREEN_MEMORY_START, 0x4000