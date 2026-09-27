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
; noop if requested bank is 0xc0 because we assume we come from 0xc0
macro CALL_IN_BANK routine, bank
	if {bank} != 0xc0
		assert $<0x4000
		assert {bank} == 0xc5 || {bank} == 0xc4, "bank must be 0xc5 or 0xc4; just need to handle the others, no worries ;)"
		ld bc, 0x7f00 + {bank} : out (c), c
		call {routine}
		ld bc, 0x7f00 + 0xc0 : out (c), c
		assert $<=0x4000
	endif
endm


macro SELECT_BANK, bank
	assert $<0x4000 || $>=0x8000
	ld bc, 0x7f00 + {bank} : out (c), c
	assert $<0x4000 || $>=0x8000
endm

macro RESTORE_BANK
	assert $<0x4000 || $>=0x8000
	ld bc, 0x7f00 + 0xc0 : out (c), c
	assert $<0x4000 || $>=0x8000
endm