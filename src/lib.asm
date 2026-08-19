
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

bc26_de
    ld a, d
    add 8
    ld d, a
    ret nc
    ld bc, 0xc000 + 96
    ex de, hl
        add hl, bc
    ex de, hl
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


    ;; BUG: there are bug in the computation when using {var} instead of var.
    ;;      needto find why
    function compute_screen_address base, width, char_x, line_y
        pixel_y = {line_y}%8
        ;char_y = {line_y}/8 ; BUG => result is a float !!!
        char_y = {line_y}>>3 ; OK => real /8 ...

        address = {base} + char_y*{width} + pixel_y*0x800 + {char_x}
        return address
    endfunction



	align 256
;;
;; Generate the screen table
;; TODO align on 256 bytes to avoid 16 bits manipulations when reading
screen_table
    repeat 8*SCREEN_HEIGHT_CHARS, lineid, 0
        dw compute_screen_address(0xc000, 96, 0, {lineid})
    endr

    assert peek(screen_table + 0) == 0x00
    assert peek(screen_table + 1) == 0xc0
    assert peek(screen_table + 2) == 0x00
    assert peek(screen_table + 3) == 0xc8

;;
;; Same data as screen_table, but split into two page-aligned byte tables indexed
;; directly by the (un-doubled) raster-line number. This lets the hot per-column move
;; routine fetch a screen address in 2 loads (ld l,a : ld r,(hl) twice) instead of
;; doubling the index and walking a word table, which is measurably cheaper (see
;; SPECTRAL_SPRITE_MOVE_COLUMN_CODE_BODY).
    align 256
screen_table_hi
    repeat 8*SCREEN_HEIGHT_CHARS, lineid, 0
        db high(compute_screen_address(0xc000, 96, 0, {lineid}))
    endr

    align 256
screen_table_lo
    repeat 8*SCREEN_HEIGHT_CHARS, lineid, 0
        db low(compute_screen_address(0xc000, 96, 0, {lineid}))
    endr

    ; sanity: the split tables must describe exactly the same addresses as screen_table
    repeat 8*SCREEN_HEIGHT_CHARS, lineid, 0
        assert peek(screen_table_lo + {lineid}) == peek(screen_table + 2*{lineid} + 0), "screen_table_lo mismatch at line {lineid}"
        assert peek(screen_table_hi + {lineid}) == peek(screen_table + 2*{lineid} + 1), "screen_table_hi mismatch at line {lineid}"
    endr


;;
;; Generate the screen table for the second screen as we are using a double buffer
screen_table2
    repeat 8*SCREEN_HEIGHT_CHARS, lineid, 0
        current_low = peek(screen_table + 2*{lineid}+0)
        current_high = peek(screen_table + 2*{lineid}+1)

        db current_low
        db current_high - 0x40 ; shit from 0xC000 to 0x8000
    endr
