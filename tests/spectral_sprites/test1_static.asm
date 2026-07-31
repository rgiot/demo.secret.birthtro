;; June 2026
;; Krusty/Benediction
;; Start to work on the background display.
;; Nothing fancy here : there is a 4 colors background.
;;                      idealy it will have some animated parts



SPECTRAL_PLAIN = false


MODE0_LEFT_PIXEL_BIT0_POS equ 7
MODE0_LEFT_PIXEL_BIT1_POS equ 3
MODE0_LEFT_PIXEL_BIT2_POS equ 5
MODE0_LEFT_PIXEL_BIT3_POS equ 1

MODE0_RIGHT_PIXEL_BIT0_POS equ 6
MODE0_RIGHT_PIXEL_BIT1_POS equ 2
MODE0_RIGHT_PIXEL_BIT2_POS equ 4
MODE0_RIGHT_PIXEL_BIT3_POS equ 0

; spectral sprites uses bit 2
SPECTRAL_SPRITE_LEFT_BIT_POS equ  MODE0_LEFT_PIXEL_BIT2_POS      ; used for even lines
SPECTRAL_SPRITE_RIGHT_BIT_POS equ  MODE0_RIGHT_PIXEL_BIT2_POS    ; used for odd lines


SPECTRAL_SPRITE_WIDTH equ 11
SPECTRAL_SPRITE_HEIGHT equ 5

SPECTRAL_BLOC_HEIGHT equ 16
SPECTRAL_BLOC_WIDTH equ 8

SPECTRAL_START_ADDRESS equ 0xc000 + 3 + 96*5


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


        ; set up the BACKGROUND_IMG_PALETTE for the background
        ld bc, 0x7f00 : out (c), c : ld a, (BACKGROUND_IMG_PALETTE+0) : out (c), a
        ld bc, 0x7f01 : out (c), c : ld a, (BACKGROUND_IMG_PALETTE+1) : out (c), a
        ld bc, 0x7f02 : out (c), c : ld a, (BACKGROUND_IMG_PALETTE+2) : out (c), a
        ld bc, 0x7f03 : out (c), c : ld a, (BACKGROUND_IMG_PALETTE+3) : out (c), a
        ld bc, 0x7f00 + 4 : out (c), c : ld a, (spectral_palette+0) : out (c), a
        ld bc, 0x7f01 + 4 : out (c), c : ld a, (spectral_palette+1) : out (c), a
        ld bc, 0x7f02 + 4 : out (c), c : ld a, (spectral_palette+2) : out (c), a
        ld bc, 0x7f03 + 4 : out (c), c : ld a, (spectral_palette+3) : out (c), a

        ; TODO setup the BACKGROUND_IMG_PALETTE for the extra layers

        ; set up the BACKGROUND_IMG_PALETTE for the background
		ld bc, 0x7f10 : out (c), c : ld bc, 0x7f54 : out (c), c
		ld sp, $


    call show_static_sprite

frame
    jp frame


show_static_sprite
    ld hl, SPECTRAL_START_ADDRESS
    ld de, spectral_sprites_matrix

    ld b, SPECTRAL_SPRITE_HEIGHT
.loopy
    push bc, hl

        ld b, SPECTRAL_SPRITE_WIDTH
.loopx
        push bc
            ld a, (de) : inc de
            cp '#'
            jp nz, .skip
            push de, hl : call show_bloc : pop hl, de
.skip
            repeat SPECTRAL_BLOC_WIDTH
                inc hl
            endrepeat

            pop bc
        djnz .loopx

        pop hl
        repeat SPECTRAL_BLOC_HEIGHT
            call bc26_hl
        endrepeat
        pop bc
    djnz .loopy
    ret


;;
;; Show a complete bloc to build the background.
;; We don't care if it is slow. This is executed only once time
;; Input:
;;   - HL: screen address
show_bloc
    ld b, SPECTRAL_BLOC_HEIGHT/2
    assert SPECTRAL_BLOC_WIDTH % 2 = 0, "SPECTRAL_BLOC_WIDTH must be even "
.yloop
    push bc

        repeat SPECTRAL_BLOC_WIDTH
            if SPECTRAL_PLAIN
                set SPECTRAL_SPRITE_RIGHT_BIT_POS, (hl)
            endif
            set SPECTRAL_SPRITE_LEFT_BIT_POS, (hl) : inc hl
        endrepeat
        call bc26_hl
        repeat SPECTRAL_BLOC_WIDTH
            dec hl : set SPECTRAL_SPRITE_RIGHT_BIT_POS, (hl)
            if SPECTRAL_PLAIN
                set SPECTRAL_SPRITE_LEFT_BIT_POS, (hl)
            endif
        endrepeat
        call bc26_hl
    pop bc
    djnz .yloop

    ret



; input: hl screen address
; modified:  A, BC
bc26_hl
    ld a, h
    add 8
    ld h, a
    ret nc
    ld bc, 0xc000 + 96
    add hl, bc
    ret

;; Texture in the background
spectral_sprites_model equ [
    "##  ##  ## ",
    "# # # # # #",
    "##  # # # #",
    "# # # # # #",
    "##  # # ## "
]


    assert list_len(spectral_sprites_model) = SPECTRAL_SPRITE_HEIGHT, "spectral_sprites_model must have {SPECTRAL_SPRITE_HEIGHT} lines"
    assert list_len(list_get(spectral_sprites_model, 0)) = SPECTRAL_SPRITE_WIDTH, "spectral_sprites_model first line must have {SPECTRAL_SPRITE_WIDTH} characters"

spectral_sprites_matrix db spectral_sprites_model



    ; BACKGROUND_IMG_PALETTE
BACKGROUND_IMG_PALETTE
    incbin "../../data/face0_cpc.pal"

spectral_palette
    db 0x58, 0x45, 0x4d, 0x4f 


    ; screen
    org 0xc000
    incbin "../../data/face0_cpc.scr"