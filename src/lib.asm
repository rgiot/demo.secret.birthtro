
; compute next line address.
; input: hl screen address in 0xc000-0xffff
; output: hl next line screen address in 0xc000-0xffff
; modified:  A, BC
bc26_hl
    ld a, h
    add 8
    ld h, a
    ret nc
    ld bc, 0xc000 + 96
    add hl, bc
    ret

; wait the BEGINNING of vsync
; modified: A, B
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
