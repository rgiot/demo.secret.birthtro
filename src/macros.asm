;;
; Change the border color
macro DEBUG col
	if SHOW_DEBUG
    ld bc, 0x7f10 : out (c), c
    ld a, {col} : out (c), a
	endif
endm


;;
; Exchange 2 16bits values in memory
; Modified: HL, DE
macro SWITCH_VALUES addr1, addr2
	ld hl, ({addr1}) : ld de, ({addr2})
	ld ({addr1}), de : ld ({addr2}), hl
endm


; Some extra code is in extra bank. To access it safely we need 
; to not be in 0x4000 space
macro CALL_IN_BANK routine, bank
	assert $<0x4000
	assert {bank} == 0xc5, "bank must be 0xc5; just need to handle the others, no worries ;)"
	ld bc, 0x7f00 + {bank} : out (c), c
	call {routine}
	ld bc, 0x7f00 + 0xc0 : out (c), c
	assert $<=0x4000
endm