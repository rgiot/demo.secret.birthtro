
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
