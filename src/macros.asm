;;
; Change the border color
macro DEBUG col
    ld bc, 0x7f10 : out (c), c
    ld a, {col} : out (c), a
endm


;;
; Exchange 2 16bits values in memory
; Modified: HL, DE
macro SWITCH_VALUES addr1, addr2
	ld hl, ({addr1}) : ld de, ({addr2})
	ld ({addr1}), de : ld ({addr2}), hl
endm
