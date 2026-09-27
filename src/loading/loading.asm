
	include "inner://ga.asm"

	org 0x4000
	run $

	ld hl, 0xc9fb : ld (0x38), hl


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
	ld hl, GA_MAUVE*256 + 0x8c
	out (c), h : out (c), l


	BREAKPOINT
	di
		ld hl, interrupt_routine
		ld a, list_get(assemble("jp 0"), 0)
		ld (0x38), a
		ld (0x39), hl
	ei

	jp $

palette
	incbin "../data/loading.pal"
	





interrupt_routine

	push af
	.counter+*: ld a, 0
	inc a : and %11111 : ld (.counter), a
	jr nz, .cont

	push hl, bc, de

	call SHUFFLE

	ld b, 0x7f
	ld a, 10
	ld hl, ARR
.loop
	ld c, (HL)
	out (c), a
	out (c), c

	inc hl
	inc a
	cp 16
	jr nz, .loop

	pop de, bc, hl

.cont
	pop af

	ei
	ret



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



	org 0xc000
	incbin "../data/loading.scr"