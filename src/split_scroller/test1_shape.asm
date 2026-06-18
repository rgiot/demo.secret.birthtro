;;
; first try for split scroller with a nop precision instead of a out precision
; Krusty/Benediction
; April 2026


BLOC_HEIGHT equ 8

	org 0x4000

init
	run $
	di
		ld hl, 0xc9fb : ld (0x38), hl
		ld bc, 0xbc00 + 1 : out (c), c : ld bc, 0xbd00 : out (c), c
		ld sp, $
	ei

frame

	call secure_vsync

	halt

	ld bc, 0x7f10 : out (c), c
	ld de, 0x544b
	halt
	di

	; Normal s
	repeat BLOC_HEIGHT
		out(c), e
		out(c), e
		out(c), e
		out(c), d
		defs 64 - 4*4
	endr

	repeat BLOC_HEIGHT*2
		out(c), e
		out(c), d
		out(c), d
		out(c), d
		defs 64 - 4*4
	endr

	repeat BLOC_HEIGHT
		out(c), e
		out(c), e
		out(c), e
		out(c), d
		defs 64 - 4*4
	endr

	repeat BLOC_HEIGHT * 3
		out(c), d
		out(c), d
		out(c), e
		out(c), d
		defs 64 - 4*4
	endr

	repeat BLOC_HEIGHT
		out(c), e
		out(c), e
		out(c), e
		out(c), d
		defs 64 - 4*4
	endr


	repeat BLOC_HEIGHT*4
		defs 64
	endr



	; Rounded s
	repeat BLOC_HEIGHT
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
		defs 64 - 4*4
	endr

	repeat BLOC_HEIGHT*2

		out(c), e
		out(c), d
		nop : nop : nop : nop
		nop : nop : nop : nop
		defs 64 - 4*4
	endr


	repeat BLOC_HEIGHT
		nop
		out(c), e
		nop
		nop
		nop
		nop
		nop
		nop
		out(c), d
		nop
		defs 64 - 4*4
	endr

	repeat BLOC_HEIGHT*3
		nop : nop : nop : nop
		nop : nop : nop : nop
		out(c), e
		out(c), d
		defs 64 - 4*4
	endr


	repeat BLOC_HEIGHT
		nop
		out(c), e
		nop
		nop
		nop
		nop
		nop
		nop
		out(c), d
		nop
		defs 64 - 4*4
	endr




	ei
	jp frame


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
