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
SPECTRAL_SPRITE_WIDTH equ 22 ; more columns is too slow
SPECTRAL_SPRITE_HEIGHT equ 5

BLOC_HEIGHT equ 16
BLOC_WIDTH equ 4


SPECTRAL_DELTA_CURVE equ [4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 2, 4, 4, 4, 2, 4, 2, 4, 4, 2, 4, 2, 4, 2, 4, 2, 4, 2, 2, 4, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 0, 2, 2, 2, 2, 2, 2, 2, 0, 2, 2, 2, 0, 2, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 0, 2, 0, 2, 0, 0, 0, 2, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 2, 0, 2, 0, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 2, 0, 2, 2, 2, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 4, 2, 2, 4, 2, 4, 2, 4, 2, 4, 2, 4, 4, 2, 4, 2, 4, 4, 4, 2, 4, 4, 4, 4, 2, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4]
SPECTRAL_CURVE_STEPX equ 3


SPECTRAL_START_LINE equ SCREEN_HEIGHT_CHARS*8/2 - BLOC_HEIGHT*SPECTRAL_SPRITE_HEIGHT/2 
SPECTRAL_START_COLUMN equ 4


;; XXX not used anumore, cannot handle so much columns
;; Each char is duplicated
function double_columns column
    return {column}
    duplicated = ""
   ; iterate value in {column} ; BUG does not assemble
   repeat string_len({column}), i, 0
        value = string_get({column}, {i})
        duplicated = string_concat(duplicated, value, value)
    endrepeat
    ;enditerate
    return duplicated
endfunction

;; Texture in the background
spectral_sprites_model equ [
    double_columns("####    ####    ####  "),
    double_columns("##  ##  ##  #   ##  ##"),
    double_columns("####    ##  ##  ##  ##"),
    double_columns("##  ##  ##  ##  ##  ##"),
    double_columns("####    ##  ##  ####  ")
]


    ;; The action to execute when updating the screen to make move the sprites
    enum SPECTRAL_SPRITE_BLOC_ACTION
        NONE    ; No change
        ERASE   ; Current line has to be erased
        DRAW    ; Current line has to be drawned
    endenum


;; XXX Written by claude !
;; Compute the action (NONE/DRAW/ERASE) needed at a boundary where the fill-state goes
;; from {previous_filled} to {filled}. When {invert} is true, DRAW and ERASE are swapped:
;; this is exactly what moving down needs at that very same boundary, since going down is
;; the time-mirror of going up (whatever slides into view when scrolling one way slides
;; out when scrolling the other way).
function spectral_sprites_boundary_action, previous_filled, filled, invert
    if {previous_filled} == {filled}
        return SPECTRAL_SPRITE_BLOC_ACTION_NONE
    endif

    becomes_filled = {filled}
    if {invert}
        becomes_filled = !becomes_filled
    endif

    if becomes_filled
        return SPECTRAL_SPRITE_BLOC_ACTION_DRAW
    endif
    return SPECTRAL_SPRITE_BLOC_ACTION_ERASE
endfunction

;; Compute the up_actions/down_actions table (one entry per column of {model}) so the
;; assembler can recompute it automatically whenever the graphist edits spectral_sprites_model.
;; {model} is a list of same-length strings using '#' for a filled pixel and ' ' for an empty one.
;;
;; For a given column, each action tells what happens to the fill-state at a boundary
;; between one model row and the next (an implicit blank row is assumed above the first
;; and below the last row, since the sprite keeps scrolling through emptiness above/below it).
;; So a column of {model} with H rows produces H+1 actions.
;; {down} selects the direction: false computes the up_actions table, true computes the
;; down_actions table (see spectral_sprites_boundary_action).
function spectral_sprites_compute_actions, model, down
    width = string_len(list_get({model}, 0))
    height = list_len({model})

    columns = []
    repeat width, col, 0
        actions = []
        previous_filled = false
        repeat height, row, 0
            filled = string_get(list_get({model}, {row}), {col}) == "#"
            actions = list_push(actions, spectral_sprites_boundary_action(previous_filled, filled, {down}))
            previous_filled = filled
        endrepeat

        actions = list_push(actions, spectral_sprites_boundary_action(previous_filled, false, {down}))
        columns = list_push(columns, actions)
    endrepeat

    return columns
endfunction

function spectral_sprites_compute_up_actions, model
    return spectral_sprites_compute_actions({model}, false)
endfunction

function spectral_sprites_compute_down_actions, model
    return spectral_sprites_compute_actions({model}, true)
endfunction

;; True if the column never needs drawing (every boundary action is NONE), i.e. the
;; corresponding column of spectral_sprites_model has no '#' in any row. Blank-ness is
;; direction-invariant (NONE stays NONE whether derived as up or down actions), so it's
;; enough to check against a single direction's action list.
function spectral_sprites_column_is_blank, actions
    repeat list_len({actions}), i, 0
        if list_get({actions}, {i}) != SPECTRAL_SPRITE_BLOC_ACTION_NONE
            return false
        endif
    endrepeat
    return true
endfunction

;; XXX Copilot edited
;; Compile-time running integral of the delta curve, from entry 0 up to (but excluding)
;; {offset}. Curve values encode a per-frame vertical move: 0 => down (+1 line), 2 => nothing,
;; 4 => up (-1 line), so each entry contributes (2 - value)/2 lines.
;; This is C(offset): the vertical bias that a column sampling the curve at phase {offset}
;; accumulates relative to a column sampling at phase 0. Consecutive non-blank columns are
;; SPECTRAL_CURVE_STEPX entries apart, so column k (in non-blank order) needs the bias
;; spectral_curve_integral(SPECTRAL_DELTA_CURVE, k*SPECTRAL_CURVE_STEPX). Pre-shifting every
;; column by its own bias (both when drawn statically and when moved) makes them all oscillate
;; around SPECTRAL_START_LINE instead of drifting into a per-column tilt.
function spectral_curve_integral, curve, offset
    acc = 0
    repeat {offset}, i, 0
        acc = acc + (2 - list_get({curve}, {i})) / 2
    endrepeat
    return acc
endfunction

;; The list of actions to execute for each column of the picture to make it move up/down
spectral_sprites_up_actions equ spectral_sprites_compute_up_actions(spectral_sprites_model)
spectral_sprites_down_actions equ spectral_sprites_compute_down_actions(spectral_sprites_model)

print spectral_sprites_up_actions
print spectral_sprites_down_actions


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

/*
    repeat SPECTRAL_SPRITE_WIDTH, colid, 0

        ; Test move of the 1st column of the picture
        ld a, SPECTRAL_START_LINE
        repeat {colid}*2+1
            call spectral_sprite_down_column_{colid}
        endr

    endr
*/


    ei

frame
    ld b, 0xf5
    in a, (c)
    RRA
    jr nc, frame



    halt
    ld bc, 0x7f00 + 0x10 : out (c), c : ld bc, 0x7f00 + 0x40 : out (c), c
    call spectral_sprite_move_along_curve
    ld bc, 0x7f00 + 0x10 : out (c), c : ld bc, 0x7f00 + 0x45 : out (c), c
    halt
    ld bc, 0x7f00 + 0x10 : out (c), c : ld bc, 0x7f00 + 0x54 : out (c), c



    jp frame

spectral_sprite_move_along_curve
    ld hl, delta_x_curve
.curve_pos equ $-2

    ; Scroll the curve read position by ONE entry for the next frame (the wave travels one
    ; curve entry per frame). delta_x_curve is page-aligned, so only the low byte moves and it
    ; wraps within the 256-entry table. hl itself is left on this frame's start position.
    ld a, l : inc a: ld (.curve_pos), a ; XXX why not inc l : ld (.curve_pos), hl ?

    ; Walk the non-blank columns. Each consecutive one samples the curve SPECTRAL_CURVE_STEPX
    ; entries further along (a uniform phase stride) and starts pre-biased by the curve integral
    ; up to its own phase, so they all oscillate around SPECTRAL_START_LINE (no per-column tilt).
    SPECTRAL_MOVE_K = 0
    repeat SPECTRAL_SPRITE_WIDTH, colid, 0
        ; Blank columns (see spectral_sprites_column_is_blank) have no move routine, no jump
        ; table, and nothing to draw: skip both the dispatch AND their curve phase entirely.
        if !spectral_sprites_column_is_blank(list_get(spectral_sprites_up_actions, {colid}))
    ld a, (hl) ; curve value that drives this column this frame
    push hl
        ld hl, spectral_sprite_column{colid}_table
        ld d, 0 : ld e, a
        add hl, de
        ld e, (hl) : inc hl : ld d, (hl)
        ex de, hl
        ld a, SPECTRAL_START_LINE + spectral_curve_integral(SPECTRAL_DELTA_CURVE, SPECTRAL_MOVE_K*SPECTRAL_CURVE_STEPX)
.col{colid}_pos equ $-1
        call call_hl
        ld (.col{colid}_pos), a
    pop hl
    repeat SPECTRAL_CURVE_STEPX
        inc l ; advance to the next column's curve phase
    endr
    SPECTRAL_MOVE_K = SPECTRAL_MOVE_K + 1
        endif
    endrepeat

    ret

call_hl jp hl


;; Address delta to move a bloc down to the next one. A bloc is BLOC_HEIGHT lines tall and
;; BLOC_HEIGHT is a multiple of 8, so moving down one bloc is (BLOC_HEIGHT/8) char rows: on the
;; CPC layout moving down 8 lines is always +SCREEN_WIDTH (the sub-line offset is unchanged),
;; so no per-line bc26_hl is needed between blocs. When BLOC_HEIGHT==8 this is a single +SCREEN_WIDTH.
SPECTRAL_BLOC_STRIDE equ (BLOC_HEIGHT/8)*SCREEN_WIDTH
    assert BLOC_HEIGHT % 8 == 0, "BLOC_HEIGHT must be a multiple of 8 for SPECTRAL_BLOC_STRIDE"

;; XXX Claude written from initial handwritten done
;; Draw the static sprite in the middle of the screen.
;; Drawn COLUMN by column (runtime loop, kept compact rather than unrolled): each column starts
;; at its own line spectral_column_top_line[col] = SPECTRAL_START_LINE + curve bias, the very same
;; pre-shift the move routine applies, so the static picture already matches the animated baseline.
;; The model is read from spectral_sprites_matrix (row-major, so a column is walked with stride
;; SPECTRAL_SPRITE_WIDTH).
show_static_sprite
    ld ix, spectral_column_top_line     ; per-column top raster line (START + curve bias)
    ld iy, spectral_sprites_matrix      ; model, base cell of the current column
    ld c, SPECTRAL_START_COLUMN         ; byte x of the current column within a line
    ld b, SPECTRAL_SPRITE_WIDTH         ; number of columns to walk
.col_loop
    push bc
        ; screen address of this column's top = base(top line) + x
        ld a, (ix + 0)
        ld h, high(screen_table_hi) : ld l, a : ld d, (hl) ; d = high byte of the line base
        ld h, high(screen_table_lo)             : ld e, (hl) ; e = low  byte of the line base
        ld l, c : ld h, 0 : add hl, de          ; hl = column top screen address

        ; walk the column's model rows, drawing a bloc wherever there is a '#'
        push iy
        ld b, SPECTRAL_SPRITE_HEIGHT
.row_loop
        push bc
            ld a, (iy + 0) : cp '#'
            jr nz, .empty
            push hl : call show_bloc : pop hl   ; draw; keep hl on this bloc's top
.empty
            ld de, SPECTRAL_BLOC_STRIDE  : add hl, de  ; down to the next bloc
            ld de, SPECTRAL_SPRITE_WIDTH : add iy, de  ; next model row of this column
            pop bc
        djnz .row_loop
        pop iy
        inc iy                                  ; next model column
        pop bc
    ld a, c : add BLOC_WIDTH : ld c, a          ; next column x
    inc ix                                      ; next column top line
    djnz .col_loop
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



    ;; Enumeration that encodes the drawing movement.
    ;; the associated value is the corresponding opcode
    enum DRAW_DIRECTION
        LEFT_TO_RIGHT = opcode(inc hl)
        RIGHT_TO_LEFT = opcode(dec hl)
    endenum


    ;; Generate the code that moves a column of the picture by one pixel, up or down.
    ;; A column spans on several bytes. So when there is a modification, it has to be done on all bytes of the column.
    ;; Modifications are done from left to right then right to left at the next line. This allows to reduce the number of instructions.
    ;; As we work with block of height 8 to move to the next line consist in adding screen width to the screen address
    ;;
    ;; The boundary actions are drawn relative to a single anchor address, walked downward in
    ;; fixed BLOC_HEIGHT steps (see the iterate loop below). Only ONE raster line changes state
    ;; at each boundary when the sprite shifts by 1 pixel, and it must always be the one at the
    ;; TOPMOST of the "current line" (a) and "new line" (a+/-1): moving up, that's the new
    ;; (decremented) line, so we must decrement BEFORE computing the anchor; moving down, that's
    ;; still the current (not yet incremented) line, so we must only increment AFTER drawing, once
    ;; the anchor has already been used. Hence "adjust_before" below picks when the single
    ;; {move_direction} opcode (dec a / inc a) is applied.
    ;; Parameters:
    ;;  - colid: the column index (used to compute the column's screen address)
    ;;  - column: the list of actions to execute for each boundary of the column, as produced by
    ;;            spectral_sprites_compute_up_actions/spectral_sprites_compute_down_actions
    ;;  - move_direction: opcode (via `opcode(...)`) that adjusts the "current line" register (a):
    ;;            dec a to move up, inc a to move down
    ;;  - adjust_before: true applies {move_direction} before the anchor address is computed
    ;;            (moving up), false applies it after drawing, right before "a" is returned to the
    ;;            caller (moving down)
    ;; TODO remove the zigazag is serves for nothing as the line change can handle that. It would crunch better for the same executaion time
    assert BLOC_HEIGHT%8 == 0, "BLOC_HEIGHT must be a multiple of 8 for the spectral sprites. Otherwise the code to move up a column is not correct"
    macro SPECTRAL_SPRITE_MOVE_COLUMN_CODE_BODY, colid, column, move_direction, adjust_before
        CURRENT_DIRECTION = DRAW_DIRECTION_LEFT_TO_RIGHT
        NB_LINES_TO_JUMP=0

        if {adjust_before}
            db {move_direction}
        endif
        push af
        ld h, high(screen_table_hi)
        ld l, a
        ld d, (hl) ; high byte of the current line's screen address
        ld h, high(screen_table_lo)
        ld e, (hl) ; low byte of the current line's screen address (l is still the line index)
        ld hl, SPECTRAL_START_COLUMN + ({colid}*BLOC_WIDTH) ; get the screen address of the column to move
        add hl, de

        ld de, SPECTRAL_SPRITE_DRAW_MASK_BOTH_POS*256 + SPECTRAL_SPRITE_ERASE_MASK_BOTH_POS

        ld d, SPECTRAL_SPRITE_DRAW_MASK_BOTH_POS

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
        pop af ; restore the line used as anchor
        if !{adjust_before}
            db {move_direction} ; turn it into the new line of the moved column
        endif
        ret
    endm

    ;; Make move up the column of one pixel
    ;; Input:
    ;;  - a: line of the column to move up
    ;; Ouptut
    ;;  - a = new line of the moved column
    macro SPECTRAL_SPRITE_UP_COLUMN_CODE, colid, column
spectral_sprite_up_column_{colid}
        print "Handle spectral_sprite_up_column_", {colid}
        SPECTRAL_SPRITE_MOVE_COLUMN_CODE_BODY({colid}, {eval}{column}, opcode(dec a), true)
    endm

    ;; Make move down the column of one pixel
    ;; Input:
    ;;  - a: line of the column to move down
    ;; Ouptut
    ;;  - a = new line of the moved column
    macro SPECTRAL_SPRITE_DOWN_COLUMN_CODE, colid, column
spectral_sprite_down_column_{colid}
        print "Handle spectral_sprite_down_column_", {colid}
        SPECTRAL_SPRITE_MOVE_COLUMN_CODE_BODY({colid}, {eval}{column}, opcode(inc a), false)
    endm



    ; Generate the code to move up/down all NON-BLANK columns of the picture. Blank columns
    ; (no '#' anywhere in spectral_sprites_model for that column) never draw anything, so
    ; there's no point generating a move routine, a jump table, or dispatching to them at
    ; runtime (see spectral_sprite_move_along_curve).
    repeat SPECTRAL_SPRITE_WIDTH, colid, 0
        if !spectral_sprites_column_is_blank(list_get(spectral_sprites_up_actions, {colid}))
            SPECTRAL_SPRITE_UP_COLUMN_CODE(
                {colid},
                {eval}list_get(spectral_sprites_up_actions, {colid})
            )
            SPECTRAL_SPRITE_DOWN_COLUMN_CODE(
                {colid},
                {eval}list_get(spectral_sprites_down_actions, {colid})
            )
        endif

    endrepeat
spectral_sprite_any_column_do_nothing
    ret


    repeat SPECTRAL_SPRITE_WIDTH, colid, 0
        if !spectral_sprites_column_is_blank(list_get(spectral_sprites_up_actions, {colid}))
spectral_sprite_column{colid}_table
    dw spectral_sprite_down_column_{colid}
    dw spectral_sprite_any_column_do_nothing
    dw spectral_sprite_up_column_{colid}
        endif
    endrepeat



    assert list_len(spectral_sprites_model) = SPECTRAL_SPRITE_HEIGHT, "spectral_sprites_model must have {SPECTRAL_SPRITE_HEIGHT} lines"
    assert list_len(list_get(spectral_sprites_model, 0)) = SPECTRAL_SPRITE_WIDTH, "spectral_sprites_model first line must have {SPECTRAL_SPRITE_WIDTH} characters"

spectral_sprites_matrix db spectral_sprites_model

;; Top raster line of each column of the sprite: SPECTRAL_START_LINE plus the curve integral up
;; to that column's phase (blank columns draw nothing, so their entry is a harmless placeholder).
;; Consumed by show_static_sprite; kept in step with the move routine's per-column init.
spectral_column_top_line
    SPECTRAL_TOP_K = 0
    repeat SPECTRAL_SPRITE_WIDTH, colid, 0
        if spectral_sprites_column_is_blank(list_get(spectral_sprites_up_actions, {colid}))
            db SPECTRAL_START_LINE ; blank column: value unused
        else
            db SPECTRAL_START_LINE + spectral_curve_integral(SPECTRAL_DELTA_CURVE, SPECTRAL_TOP_K*SPECTRAL_CURVE_STEPX)
            SPECTRAL_TOP_K = SPECTRAL_TOP_K + 1
        endif
    endrepeat



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


    align 256
; spectra lcurve
; 0 => decrease
; 2=> nothing
;  4=> increase
; XXX limitation Needs to be setup in memory BEF
delta_x_curve db SPECTRAL_DELTA_CURVE

;SPECTRAL_START_ADDRESS equ peek(screen_table + 2*SPECTRAL_START_LINE + 0) \
;                        + (peek(screen_table + 2*SPECTRAL_START_LINE + 1) << 8);\
;                        + SPECTRAL_START_COLUMN

 ;   print {hex}SPECTRAL_START_ADDRESS
    ; screen
    org 0xc000
    incbin "../../data/face0_cpc.scr"