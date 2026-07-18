;; June 2026
;; Krusty/Benediction
;; Start to work on the background display.
;; Nothing fancy here : there is a 4 colors background.
;;                      idealy it will have some animated parts




	org 0x4000

init
	run $
	di

        ; set up the screen

		ld hl, 0xc9fb : ld (0x38), hl
		ld bc, 0xbc00 + 1 : out (c), c : ld bc, 0xbd00 + 96/2 : out (c), c
		ld bc, 0xbc00 + 2 : out (c), c : ld bc, 0xbd00 + 50 : out (c), c
		ld bc, 0xbc00 + 7 : out (c), c : ld bc, 0xbd00 + 29 : out (c), c
		ld bc, 0xbc00 + 6 : out (c), c : ld bc, 0xbd00 + 21 : out (c), c
		ld bc, 0xbc00 + 12 : out (c),c : ld bc, 0xbd00 + 0x30 : out (c), c
		ld bc, 0xbc00 + 13 : out (c),c : ld bc, 0xbd00 : out (c), c
		ld bc, 0x7f8c : out (c), c


        ; set up the palette for the background
        ld bc, 0x7f00 : out (c), c : ld a, (palette+0) : out (c), a
        ld bc, 0x7f01 : out (c), c : ld a, (palette+1) : out (c), a
        ld bc, 0x7f02 : out (c), c : ld a, (palette+2) : out (c), a
        ld bc, 0x7f03 : out (c), c : ld a, (palette+3) : out (c), a

        ; TODO setup the palette for the extra layers

        ; set up the palette for the background
		ld bc, 0x7f10 : out (c), c : ld bc, 0x7f54 : out (c), c
		ld sp, $



frame
    jp frame

    ; palette
palette
    incbin "../../data/face0_cpc.pal"

    ; screen
    org 0xc000
    incbin "../../data/face0_cpc.scr"