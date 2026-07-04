;; June 2026
;; Krusty/Benediction
;; Start to work on the background display.
;; Nothing fancy here : there is a 4 colors background.
;;                      ideally it will have some animated parts



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

SPECTRAL_SPRITE_DRAW_MASK_BOTH_POS equ (1 << SPECTRAL_SPRITE_LEFT_BIT_POS) | (1 << SPECTRAL_SPRITE_RIGHT_BIT_POS)
SPECTRAL_SPRITE_ERASE_MASK_BOTH_POS equ (~(SPECTRAL_SPRITE_DRAW_MASK_BOTH_POS)) & 0xff

SCREEN_WIDTH equ 96
SCREEN_HEIGHT_CHARS equ 21
SPECTRAL_SPRITE_WIDTH equ 11
SPECTRAL_SPRITE_HEIGHT equ 5

BLOC_HEIGHT equ 16
BLOC_WIDTH equ 8



SPECTRAL_START_LINE equ 5*8+3
SPECTRAL_START_COLUMN equ 4


	org 0x4000

init
	run $
	di

        ; setup the screen

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

    ; Test move of the 1st column of the picture
    ld a, SPECTRAL_START_LINE
    repeat 16
        call spectral_sprite_up_column_0
    endr
    

    ld a, SPECTRAL_START_LINE
    repeat 12
        call spectral_sprite_up_column_1
    endr
    


    ld a, SPECTRAL_START_LINE
    repeat 8
        call spectral_sprite_up_column_2
    endr
    

frame
    jp frame


show_static_sprite
    ; compute the start line to display the logo
    ld hl, screen_table
    ld de, SPECTRAL_START_LINE*2
    add hl, de
    ld e, (hl) : inc hl
    ld d, (hl) : inc hl
    ld hl, SPECTRAL_START_COLUMN
    add hl, de

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


    ;; Enumeration that encodes the drawing movement.
    ;; the associated value is the corresponding opcode
    enum DRAW_DIRECTION
        LEFT_TO_RIGHT = opcode(inc hl)
        RIGHT_TO_LEFT = opcode(dec hl)
    endenum


    ;; Generate the code to move up a column of the picture.
    ;; A column spans on several bytes. So when there is a modification, it has to be done on all bytes of the column.
    ;; Modifications are done from left to right then right to left at the next line. This allows to reduce the number of instructions.
    ;; As we work with block of height 8 to move to the next line consist in adding screen width to the screen address
    ;; Parameters:
    ;;  - label: the label to use for the generated code
    ;;  - column: the list of actions to execute for each line of the column
    ;; TODO remove the zigazag is serves for nothing as the line change can handle that. It would crunch better for the same executaion time
    assert BLOC_HEIGHT%8 == 0, "BLOC_HEIGHT must be a multiple of 8 for the spectral sprites. Otherwise the code to move up a column is not correct"
    macro SPECTRAL_SPRITE_UP_COLUMN_CODE, colid, column
        CURRENT_DIRECTION = DRAW_DIRECTION_LEFT_TO_RIGHT
        NB_LINES_TO_JUMP=0
    ;; Make move the column of one pixel
    ;; Input:
    ;;  - a: line of the column to move up
    ;; Ouptut
    ;;  - a = new line of the moved column
spectral_sprite_up_column_{colid}

        print "Handle spectral_sprite_up_column_", {colid}

        dec a : push af
        add a
        ; TODO use 8bits manipulations with a modified table
        ld d, 0 : ld e, a
        ld hl, screen_table
        add hl, de
        ld e, (hl) : inc hl : ld d, (hl) ; get the current line of the column to move up
        ld hl, SPECTRAL_START_COLUMN + ({colid}*BLOC_WIDTH) ; get the screen address of the column to move up
        add hl, de

        ld de, SPECTRAL_SPRITE_DRAW_MASK_BOTH_POS*256 + SPECTRAL_SPRITE_ERASE_MASK_BOTH_POS

        ld d, SPECTRAL_SPRITE_DRAW_MASK_BOTH_POS


    BREAKPOINT
        FIRST_ROW = true
        iterate action in {column}

            print "action = ", {action}


            NB_LINES_TO_JUMP = NB_LINES_TO_JUMP + 1

            ; Change of line because we will draw
            if {action} != SPECTRAL_SPRITE_BLOC_ACTION_NONE
                if FIRST_ROW
                    NB_LINES_TO_JUMP = 0
                    FIRST_ROW = false
                else
                    print "Jump ", NB_LINES_TO_JUMP, " blocs"
                    ; we have to jump to the next line of the column
                    ld bc, SCREEN_WIDTH*NB_LINES_TO_JUMP*(BLOC_HEIGHT>>3) ; 1 pixel line = 1/8 of a bloc height
                    add hl, bc
                    NB_LINES_TO_JUMP = 0
                endif
                HAS_DRAWN = true
            else
                if FIRST_ROW
                    NB_LINES_TO_JUMP = 0
                    FIRST_ROW = false
                endif
                HAS_DRAWN = false
            endif

            ; Generate the code if any
            switch {action}
                case SPECTRAL_SPRITE_BLOC_ACTION_NONE
                    break
                case SPECTRAL_SPRITE_BLOC_ACTION_DRAW
                    repeat BLOC_WIDTH, step, 1
                        ; ok but too slow, not retained (8 nops)
                        ;set SPECTRAL_SPRITE_LEFT_BIT_POS, (hl) ; 4 nops
                        ;set SPECTRAL_SPRITE_RIGHT_BIT_POS, (hl) ; 4 nops

                        ; ok but too slow, not retained (8 nops)
                        ;ld a, (hl) ; 2nops
                        ;set SPECTRAL_SPRITE_LEFT_BIT_POS, a ; 2 nops
                        ;set SPECTRAL_SPRITE_RIGHT_BIT_POS, a ; 2nops
                        ;ld (hl), a ; 2 nops

                        ; ok, but too slow (6nops)
                        ;ld a, (hl) : or %00110000 : ld (hl), a 

                        ld a, (hl) : or d : ld (hl), a ; 5 nops
                        
                        if {step} != BLOC_WIDTH
                            db CURRENT_DIRECTION
                        endif
                    endrepeat
                    break
                case SPECTRAL_SPRITE_BLOC_ACTION_ERASE
                    repeat BLOC_WIDTH, step, 1
                        ld a, (hl) : and e : ld (hl), a ; 5 nops
                        if {step} != BLOC_WIDTH
                           db CURRENT_DIRECTION
                        endif
                    endrepeat
                    break
            endswitch


            ; direction changes only if there was drawing or erasing
            if HAS_DRAWN
                ; we change of direction for next drawing
                if DRAW_DIRECTION_LEFT_TO_RIGHT == CURRENT_DIRECTION
                    CURRENT_DIRECTION = DRAW_DIRECTION_RIGHT_TO_LEFT
                else
                    CURRENT_DIRECTION = DRAW_DIRECTION_LEFT_TO_RIGHT
                endif
            endif

        enditerate
        pop af ; restore the new line of the moved column
        ret
    endm



    ; Generate the code to move up all columns of the picture.
    repeat /*SPECTRAL_SPRITE_WIDTH*/3, colid, 0
    SPECTRAL_SPRITE_UP_COLUMN_CODE(
        {colid},
        {eval}list_get(spectral_sprites_up_actions, {colid})
    )

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
;; TODO align on 256 bytes to avoif 16 bits manpuations when reading
screen_table
    repeat 8*SCREEN_HEIGHT_CHARS, lineid, 0
        dw compute_screen_address(0xc000, 96, 0, {lineid})
    endr

    assert peek(screen_table + 0) == 0x00
    assert peek(screen_table + 1) == 0xc0
    assert peek(screen_table + 2) == 0x00
    assert peek(screen_table + 3) == 0xc8


;SPECTRAL_START_ADDRESS equ peek(screen_table + 2*SPECTRAL_START_LINE + 0) \
;                        + (peek(screen_table + 2*SPECTRAL_START_LINE + 1) << 8);\
;                        + SPECTRAL_START_COLUMN

 ;   print {hex}SPECTRAL_START_ADDRESS
    ; screen
    org 0xc000
    incbin "../../data/face0_cpc.scr"