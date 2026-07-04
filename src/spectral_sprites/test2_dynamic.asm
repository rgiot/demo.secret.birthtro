;; June 2026
;; Krusty/Benediction
;; Start to work on the background display.
;; Nothing fancy here : there is a 4 colors background.
;;                      idealy it will have some animated parts



SPECTRAL_PLAIN = true ; Voxy's choice, but I'm sure it is a mistake

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

SCREEN_HEIGHT_CHARS equ 21
SPECTRAL_SPRITE_WIDTH equ 11
SPECTRAL_SPRITE_HEIGHT equ 5

BLOC_HEIGHT equ 16
BLOC_WIDTH equ 8

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
		ld bc, 0xbc00 + 6 : out (c), c : ld bc, 0xbd00 + SCREEN_HEIGHT_CHARS : out (c), c
		ld bc, 0xbc00 + 12 : out (c),c : ld bc, 0xbd00 + 0x30 : out (c), c
		ld bc, 0xbc00 + 13 : out (c),c : ld bc, 0xbd00 : out (c), c
		ld bc, 0x7f8c : out (c), c


        ; set up the background_palette for the background
        ld bc, 0x7f00 : out (c), c : ld a, (background_palette+0) : out (c), a
        ld bc, 0x7f01 : out (c), c : ld a, (background_palette+1) : out (c), a
        ld bc, 0x7f02 : out (c), c : ld a, (background_palette+2) : out (c), a
        ld bc, 0x7f03 : out (c), c : ld a, (background_palette+3) : out (c), a
        ld bc, 0x7f00 + 4 : out (c), c : ld a, (spectral_palette+0) : out (c), a
        ld bc, 0x7f01 + 4 : out (c), c : ld a, (spectral_palette+1) : out (c), a
        ld bc, 0x7f02 + 4 : out (c), c : ld a, (spectral_palette+2) : out (c), a
        ld bc, 0x7f03 + 4 : out (c), c : ld a, (spectral_palette+3) : out (c), a

        ; TODO setup the background_palette for the extra layers

        ; set up the background_palette for the background
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
            repeat BLOC_WIDTH
                inc hl
            endrepeat

            pop bc
        djnz .loopx

        pop hl
        repeat BLOC_HEIGHT
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
    ld b, BLOC_HEIGHT/2
    assert BLOC_WIDTH % 2 = 0, "BLOC_WIDTH must be even "
.yloop
    push bc

        repeat BLOC_WIDTH
            if SPECTRAL_PLAIN
                set SPECTRAL_SPRITE_RIGHT_BIT_POS, (hl)
            endif
            set SPECTRAL_SPRITE_LEFT_BIT_POS, (hl) : inc hl
        endrepeat
        call bc26_hl
        repeat BLOC_WIDTH
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


    ;; The action to execute when updating the screen to make move the sprites
    enum SPECTRAL_SPRITE_BLOC_ACTION
        NONE    ; No change
        ERASE   ; Current line has to be erased
        DRAW    ; Current line has to be drawned
    endenum

;; The list of actions to execute for each column of the picture to make move it up
spectral_sprites_up_actions equ [
    [
        SPECTRAL_SPRITE_BLOC_ACTION_DRAW,
        SPECTRAL_SPRITE_BLOC_ACTION_NONE,
        SPECTRAL_SPRITE_BLOC_ACTION_NONE,
        SPECTRAL_SPRITE_BLOC_ACTION_NONE,
        SPECTRAL_SPRITE_BLOC_ACTION_NONE,
        SPECTRAL_SPRITE_BLOC_ACTION_ERASE
    ],
    [
        SPECTRAL_SPRITE_BLOC_ACTION_DRAW,
        SPECTRAL_SPRITE_BLOC_ACTION_ERASE,
        SPECTRAL_SPRITE_BLOC_ACTION_DRAW,
        SPECTRAL_SPRITE_BLOC_ACTION_ERASE,
        SPECTRAL_SPRITE_BLOC_ACTION_DRAW,
        SPECTRAL_SPRITE_BLOC_ACTION_ERASE
    ],
    [ 
        SPECTRAL_SPRITE_BLOC_ACTION_NONE,
        SPECTRAL_SPRITE_BLOC_ACTION_DRAW,
        SPECTRAL_SPRITE_BLOC_ACTION_ERASE,
        SPECTRAL_SPRITE_BLOC_ACTION_DRAW,
        SPECTRAL_SPRITE_BLOC_ACTION_ERASE,
        SPECTRAL_SPRITE_BLOC_ACTION_NONE
    ]
]

print spectral_sprites_up_actions


    enum DRAW_DIRECTION
        LEFT_TO_RIGHT
        RIGHT_TO_LEFT
    endenum


    ;; Generate the code to move up a column of the picture.
    ;; A column spans on several bytes. So when there is a modification, it has to be done on all bytes of the column.
    ;; Modifications are done from left to right then right to left at the next line. This allows to reduce the number of instructions.
    ;; As we work with block of height 8 to move to the next line consist in adding screen width to the screen address
    ;; Parameters:
    ;;  - label: the label to use for the generated code
    ;;  - column: the list of actions to execute for each line of the column
    assert BLOC_HEIGHT == 8, "BLOC_HEIGHT must be 8 for the spectral sprites. Otherwise the code to move up a column is not correct"
    macro SPECTRAL_SPRITE_UP_COLUMN_CODE, label, column
        CURRENT_DIRECTION = DRAW_DIRECTION_LEFT_TO_RIGHT
        NB_LINES_TO_JUMP=0
    ;; Make move the column of one pixel
    ;; Input:
    ;;  - HL: screen adresse where to to write (1 pixel line upper than before)
{label}
        iterate action in {column}
            NB_LINES_TO_JUMP = NB_LINES_TO_JUMP + 1
            
        enditerate


    endm


    repeat /*SPECTRAL_SPRITE_WIDTH*/3, colid, 0
spectral_sprite_up_column_{colid}
    CURRENT_COLUMN = list_get(spectral_sprites_up_actions, {colid})

    endrepeat


    assert list_len(spectral_sprites_model) = SPECTRAL_SPRITE_HEIGHT, "spectral_sprites_model must have {SPECTRAL_SPRITE_HEIGHT} lines"
    assert list_len(list_get(spectral_sprites_model, 0)) = SPECTRAL_SPRITE_WIDTH, "spectral_sprites_model first line must have {SPECTRAL_SPRITE_WIDTH} characters"

spectral_sprites_matrix db spectral_sprites_model



    ; background_palette
background_palette
    incbin "../../data/face0_cpc.pal"

spectral_palette
    db 0x58, 0x45, 0x4d, 0x4f 


    ;; BUG: there are bug in the computation when using {var} instead of var.
    ;;      needto find why
    function compute_screen_address base, width, char_x, line_y
        pixel_y = {line_y}%8
        ;char_y = {line_y}/8 ; BUG => result is a float !!!
        char_y = {line_y}>>3 ; OK => real /8 ...

        address = {base} + char_y*{width} + pixel_y*0x800 + {char_x}
        return address
    endfunction

;;
;; Generate the screen table
screen_table
    repeat 8*SCREEN_HEIGHT_CHARS, lineid, 0
        dw compute_screen_address(0xc000, 96, 0, {lineid})
    endr

    assert peek(screen_table + 0) == 0x00
    assert peek(screen_table + 1) == 0xc0
    assert peek(screen_table + 2) == 0x00
    assert peek(screen_table + 3) == 0xc8
    ; screen
    org 0xc000
    incbin "../../data/face0_cpc.scr"