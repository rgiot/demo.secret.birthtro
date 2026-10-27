;;
; July 2026
; Krusty/Benediction
;
; This file holds everything that actually EMITS bytes for the spectral sprites (code + data):
; it is assembled into its own 16KB bank (demo_code_c4, mapped at 0x0000-0x3fff, see sna.asm)
; because 4 logos' worth of per-column code no longer fits alongside the rest of the demo.
; It must be entirely self-contained: while this bank is paged in, bank 0's own 0x0000-0x3fff
; (including screen_table_hi/lo and bc26_hl from lib.asm) is paged OUT, so we keep small local
; copies of the couple of helpers we need. Only the real screen (0xc000-0xffff) stays mapped
; the same in every bank, which is why writing sprite pixels still works from here.
; Reached from bank 0 exclusively through CALL_IN_BANK(routine, 0xc4), with interrupts disabled
; around the call (this bank also replaces the RST 0x38 vector, so an interrupt firing while it
; is paged in would jump into logo data instead of the real handler).


charset ; reset the charset


include "spectral_sprites_logo.asm"
NB_SPECTRAL_LOGOS equ list_len(SPECTRAL_LOGOS_MODELS)





;; Each char is duplicated to have a thinner movement
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

; local copy of lib.asm's bc26_hl (next screen line address), see there for details
spectral_bc26_hl
    ld a, h
    add 8
    ld h, a
    ret nc
    ld bc, 0xc000 + 96
    add hl, bc
    ret


    macro SPECTRAL_BC26_HL
        ld a, h
        add 8
        ld h, a
        jr nc, @leave
        ld bc, 0xc000 + 96
        add hl, bc
@leave
    endm


    align 256
spectral_screen_table_hi
    repeat 8*SCREEN_HEIGHT_CHARS, lineid, 0
        db high(compute_screen_address(0xc000, 96, 0, {lineid}))
    endr

    align 256
spectral_screen_table_lo
    repeat 8*SCREEN_HEIGHT_CHARS, lineid, 0
        db low(compute_screen_address(0xc000, 96, 0, {lineid}))
    endr



;; Address delta to move a bloc down to the next one. A bloc is SPECTRAL_BLOC_HEIGHT lines tall and
;; SPECTRAL_BLOC_HEIGHT is a multiple of 8, so moving down one bloc is (SPECTRAL_BLOC_HEIGHT/8) char rows: on the
;; CPC layout moving down 8 lines is always +SCREEN_WIDTH (the sub-line offset is unchanged),
;; so no per-line bc26_hl is needed between blocs. When SPECTRAL_BLOC_HEIGHT==8 this is a single +SCREEN_WIDTH.
SPECTRAL_BLOC_STRIDE equ (SPECTRAL_BLOC_HEIGHT/8)*SCREEN_WIDTH
    assert SPECTRAL_BLOC_HEIGHT % 8 == 0, "SPECTRAL_BLOC_HEIGHT must be a multiple of 8 for SPECTRAL_BLOC_STRIDE"




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
    ;; fixed SPECTRAL_BLOC_HEIGHT steps (see the iterate loop below). Only ONE raster line changes state
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
    assert SPECTRAL_BLOC_HEIGHT%8 == 0, "SPECTRAL_BLOC_HEIGHT must be a multiple of 8 for the spectral sprites. Otherwise the code to move up a column is not correct"
    macro SPECTRAL_SPRITE_MOVE_COLUMN_CODE_BODY, colid, column, move_direction, adjust_before

        TICKER START CURRENT_METHOD_DURATION


        CURRENT_DIRECTION = DRAW_DIRECTION_LEFT_TO_RIGHT
        NB_LINES_TO_JUMP=0

        if {adjust_before}
            db {move_direction}
        endif
        push af
        ld h, high(spectral_screen_table_hi)
        ld l, a
        ld d, (hl) ; high byte of the current line's screen address
        ld h, high(spectral_screen_table_lo)
        ld e, (hl) ; low byte of the current line's screen address (l is still the line index)
        ld hl, SPECTRAL_START_COLUMN + ({colid}*SPECTRAL_BLOC_WIDTH) ; get the screen address of the column to move
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
                    ld bc, SCREEN_WIDTH*NB_LINES_TO_JUMP*(SPECTRAL_BLOC_HEIGHT>>3) ; 1 pixel line = 1/8 of a bloc height
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
                    repeat SPECTRAL_BLOC_WIDTH, step, 1
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
                        
                        if {step} != SPECTRAL_BLOC_WIDTH
                            db CURRENT_DIRECTION
                        endif
                    endrepeat
                    break
                case SPECTRAL_SPRITE_BLOC_ACTION_ERASE
                    repeat SPECTRAL_BLOC_WIDTH, step, 1
                        ld a, (hl) : and e : ld (hl), a ; 5 nops
                        if {step} != SPECTRAL_BLOC_WIDTH
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

        TICKER STOP CURRENT_METHOD_DURATION
        SPECTRAL_MOVE_METHODS_DURATION = list_push(SPECTRAL_MOVE_METHODS_DURATION, CURRENT_METHOD_DURATION)
        ;unset CURRENT_METHOD_DURATION

        ret
    endm

    ;; v0: no de-duplication yet (see file header). Each (logo_id, colid) gets its own routine.
    ;; Input:
    ;;  - a: line of the column to move up
    ;; Ouptut
    ;;  - a = new line of the moved column
    macro SPECTRAL_SPRITE_UP_COLUMN_CODE, logo_id, colid, column
spectral_sprite_up_column_{logo_id}_{colid}
        SPECTRAL_SPRITE_MOVE_COLUMN_CODE_BODY({colid}, {eval}{column}, opcode(dec a), true)
    endm

    ;; v0: no de-duplication yet (see SPECTRAL_SPRITE_UP_COLUMN_CODE)
    ;; Input:
    ;;  - a: line of the column to move down
    ;; Ouptut
    ;;  - a = new line of the moved column
    macro SPECTRAL_SPRITE_DOWN_COLUMN_CODE, logo_id, colid, column
spectral_sprite_down_column_{logo_id}_{colid}
        SPECTRAL_SPRITE_MOVE_COLUMN_CODE_BODY({colid}, {eval}{column}, opcode(inc a), false)
    endm


    ;; noop routines are still shared by duration (a plain macro parameter, not a bare
    ;; "=" variable), so this dedup is unaffected by the v0 simplification below.
    ;; The `ret` MUST stay inside the ifndef: once a given duration already has a routine,
    ;; this macro must emit NO bytes at all (only the alias below), otherwise a stray `ret`
    ;; gets injected into whatever code follows every time two columns share a duration.
    macro SPECTRAL_SPRITE_NOOP_CODE, logo_id, colid, duration
        ifndef spectral_column_noop_{duration}
spectral_column_noop_{duration}
    nop {duration}
    ret
        endif

spectral_sprite_noop_column_{logo_id}_{colid} equ spectral_column_noop_{duration}
    endm

    ;; The jump table dispatched by spectral_sprite_move_along_curve for one column.
    macro SPECTRAL_SPRITE_COLUMN_TABLE, logo_id, colid
spectral_sprite_column{logo_id}_{colid}_table
    dw spectral_sprite_down_column_{logo_id}_{colid}
    dw spectral_sprite_noop_column_{logo_id}_{colid}
    dw spectral_sprite_up_column_{logo_id}_{colid}
    endm

    ;; Instantiates one logo: {logo_id} is its number (0, 1, ...) and {model} its ASCII-art shape
    ;; (see spectral_sprites_logo.asm). Generates spectral_sprites_matrix_{logo_id},
    ;; spectral_column_top_line_{logo_id} and spectral_sprite_move_along_curve_{logo_id}.
    ;; v0: NO de-duplication of per-column code across columns/logos yet (each (logo_id, colid)
    ;; is generated unconditionally); this is intentionally simplified to get a working baseline
    ;; before re-introducing the ifndef-based sharing.
    macro SPECTRAL_SPRITE_GENERATE_LOGO, logo_id, model
        assert list_len({model}) = SPECTRAL_SPRITE_HEIGHT, "spectral logo {logo_id}: model must have {SPECTRAL_SPRITE_HEIGHT} lines"
        assert string_len(list_get({model}, 0)) = SPECTRAL_SPRITE_WIDTH, "spectral logo {logo_id}: model first line must have {SPECTRAL_SPRITE_WIDTH} characters"

        SPECTRAL_LOGO_UP_ACTIONS = spectral_sprites_compute_up_actions({model})
        SPECTRAL_LOGO_DOWN_ACTIONS = spectral_sprites_compute_down_actions({model})

        ; Generate the code to move up/down all NON-BLANK columns of this logo. Blank columns
        ; (no '#' anywhere in {model} for that column) never draw anything, so there's no point
        ; generating a move routine, a jump table, or dispatching to them at runtime.
        repeat SPECTRAL_SPRITE_WIDTH, colid, 0
            if !spectral_sprites_column_is_blank(list_get(SPECTRAL_LOGO_UP_ACTIONS, {colid}))
                ; this is an accumulator for the duration of the move methods, it helps stabilize timing
                SPECTRAL_MOVE_METHODS_DURATION = []

                SPECTRAL_SPRITE_UP_COLUMN_CODE(
                    {logo_id}, {colid},
                    {eval}list_get(SPECTRAL_LOGO_UP_ACTIONS, {colid})
                )
                SPECTRAL_SPRITE_DOWN_COLUMN_CODE(
                    {logo_id}, {colid},
                    {eval}list_get(SPECTRAL_LOGO_DOWN_ACTIONS, {colid})
                )

                assert list_get(SPECTRAL_MOVE_METHODS_DURATION, 0) == list_get(SPECTRAL_MOVE_METHODS_DURATION, 1), "Move up and down must have the same duration for column {colid}"

                SPECTRAL_SPRITE_NOOP_CODE({logo_id}, {colid}, {eval}list_get(SPECTRAL_MOVE_METHODS_DURATION, 0))
                SPECTRAL_SPRITE_COLUMN_TABLE({logo_id}, {colid})
            endif
        endrepeat

spectral_sprites_matrix_{logo_id} db {model}

        ;; Top raster line of each column of this logo: SPECTRAL_START_LINE plus the curve
        ;; integral up to that column's phase (blank columns draw nothing, so their entry is a
        ;; harmless placeholder). Consumed by show_static_sprite via spectral_column_top_line_table.
spectral_column_top_line_{logo_id}
        SPECTRAL_TOP_K = 0
        repeat SPECTRAL_SPRITE_WIDTH, colid, 0
            if spectral_sprites_column_is_blank(list_get(SPECTRAL_LOGO_UP_ACTIONS, {colid}))
                db SPECTRAL_START_LINE ; blank column: value unused
            else
                db SPECTRAL_START_LINE + spectral_curve_integral(SPECTRAL_DELTA_CURVE, SPECTRAL_TOP_K*SPECTRAL_CURVE_STEPX)
                SPECTRAL_TOP_K = SPECTRAL_TOP_K + 1
            endif
        endrepeat

        ;; Runtime move dispatch for this logo (see the single, model-agnostic implementation
        ;; the original single-logo code used to have).
spectral_sprite_move_along_curve_{logo_id}
        ld hl, delta_x_curve
.curve_pos equ $-2

        ; TODO optimize there it is stupid tio incremnt this way
        ; Scroll the curve read position by ONE entry for the next frame (the wave travels one
        ; curve entry per frame). delta_x_curve is page-aligned, so only the low byte moves and it
        ; wraps within the 256-entry table. hl itself is left on this frame's start position.
        ld a, l : inc a: ld (.curve_pos), a

        ; Walk the non-blank columns. Each consecutive one samples the curve SPECTRAL_CURVE_STEPX
        ; entries further along (a uniform phase stride) and starts pre-biased by the curve
        ; integral up to its own phase, so they all oscillate around SPECTRAL_START_LINE.
        SPECTRAL_MOVE_K = 0
        repeat SPECTRAL_SPRITE_WIDTH, colid, 0
            if !spectral_sprites_column_is_blank(list_get(SPECTRAL_LOGO_UP_ACTIONS, {colid}))
    ld a, (hl) ; curve value that drives this column this frame
    push hl
        ld hl, spectral_sprite_column{logo_id}_{colid}_table
        ld d, 0 : ld e, a
        add hl, de
        ld e, (hl) : inc hl : ld d, (hl)
        ex de, hl
        ld a, SPECTRAL_START_LINE + spectral_curve_integral(SPECTRAL_DELTA_CURVE, SPECTRAL_MOVE_K*SPECTRAL_CURVE_STEPX)
.col{{colid}}_pos equ $-1
        call call_hl
        ld (.col{{colid}}_pos), a
    pop hl
    repeat SPECTRAL_CURVE_STEPX
        inc l ; advance to the next column's curve phase
    endr
    SPECTRAL_MOVE_K = SPECTRAL_MOVE_K + 1
            endif
        endrepeat

        ret
    endm

    ;; Instantiate every logo listed in SPECTRAL_LOGOS_MODELS: logo 0 uses entry 0, etc.
    repeat NB_SPECTRAL_LOGOS, SPECTRAL_LOGO_ID, 0
        SPECTRAL_SPRITE_GENERATE_LOGO({SPECTRAL_LOGO_ID}, {eval}list_get(SPECTRAL_LOGOS_MODELS, {SPECTRAL_LOGO_ID}))
    endrepeat

;; Per-logo data pointers, indexed by logo number: what makes show_static_sprite work for any
;; logo without a dedicated routine per logo.
spectral_sprites_matrix_table
    repeat NB_SPECTRAL_LOGOS, SPECTRAL_LOGO_ID, 0
        dw spectral_sprites_matrix_{SPECTRAL_LOGO_ID}
    endrepeat

spectral_column_top_line_table
    repeat NB_SPECTRAL_LOGOS, SPECTRAL_LOGO_ID, 0
        dw spectral_column_top_line_{SPECTRAL_LOGO_ID}
    endrepeat




enum SPECTRAL_SPRITE_STATE
    DISPLAYING_START
    DISPLAYING_CONTINUE
    DISPLAYING_CONTINUE2
    ERASING
    ERASING_CONTINUE
    WAVING
endenum


spectral_sprite_handle
    ld a, SPECTRAL_SPRITE_STATE_DISPLAYING_START : .state equ $-1
    cp SPECTRAL_SPRITE_STATE_DISPLAYING_START : jq z, .displaying_start
    cp SPECTRAL_SPRITE_STATE_DISPLAYING_CONTINUE : jq z, show_static_sprite_continue_0
    cp SPECTRAL_SPRITE_STATE_DISPLAYING_CONTINUE2 : jq z, show_static_sprite_continue_1
    cp SPECTRAL_SPRITE_STATE_ERASING : jq z, .erasing
    cp SPECTRAL_SPRITE_STATE_ERASING_CONTINUE  : jq z, .erasing_continue
    ;cp SPECTRAL_SPRITE_STATE_WAVING : jq z, .waving
    jq spectral_sprite_move_along_curve


.displaying_start
    ; next state will be display continuation
    ld a, SPECTRAL_SPRITE_STATE_DISPLAYING_CONTINUE : ld (.state), a


    ; reset the logo to display
    ld a, -1 : .selected_logo equ $-1 ; we want the very first value to be 0
    inc a
    cp NB_SPECTRAL_LOGOS : jr nz, .no_reset_animation
    xor a
.no_reset_animation
    ld (.selected_logo), a

    ; get the correct information
    ; iy = spectral_sprites_matrix_<logo>, ix = spectral_column_top_line_<logo>
    add a : ld l, a : ld h, 0

    push hl
        ld de, spectral_sprite_move_along_curve.table
        add hl, de
        ld e, (hl) : inc hl : ld d, (hl)
        ld (spectral_sprite_move_along_curve.routine), de
    pop hl


    push hl
        ld de, spectral_sprites_matrix_table : add hl, de
        ld e, (hl) : inc hl : ld d, (hl)
        ld (show_static_sprite_continue_0.iy_value), de
        ld (show_static_sprite_continue_1.iy_value), de ; xxx ok to keep the same
    pop hl
    ld de, spectral_column_top_line_table : add hl, de
    ld e, (hl) : inc hl : ld d, (hl)
    ld (show_static_sprite_continue_0.ix_value), de
    ld (show_static_sprite_continue_1.ix_value), de ; XXX ok to keep the same

    ; reset the display routine
    ld a, SPECTRAL_SPRITE_WIDTH
    ld (show_static_sprite_continue_0.col_counter), a
    ld (show_static_sprite_continue_1.col_counter), a

    ld a, SPECTRAL_START_COLUMN
    ld (show_static_sprite_continue_0.column_start), a
    ld (show_static_sprite_continue_1.column_start), a

    ; start to display the logo
    jp show_static_sprite_continue_0


.erasing
    ; continue as soon as we do not reach the starting configuration
    repeat NB_SPECTRAL_LOGOS, logo_id, 0
        ld a, (spectral_sprite_move_along_curve_{{logo_id}}.curve_pos)
        or a
        jq nz, .continue_movement
    endrepeat


.really_start_erasing
    ld hl, 0xc000 : ld (.erasing_start_address), hl
    xor a : ld (.erase_counter), a

    ld a, SPECTRAL_SPRITE_STATE_ERASING_CONTINUE : ld (.state), a
    ld hl, palette_all_but_spectral : ld (demo_frame_init.selected_palette), hl
    ret


.erasing_continue

    ASSERT SCREEN_HEIGHT_LINES % 3 == 0, "SCREEN_HEIGHT_LINES must be a multiple of 3 for the spectral sprites"
    ld b,3
.erase_loop


    ; XXX write a statefull erase
    ld hl, 0xc000 : .erasing_start_address equ $-2
    ; erase one char line in a row
    push hl
        call .erase_row
    pop hl
    push bc
        call spectral_bc26_hl
    pop bc
    ld (.erasing_start_address), hl


    djnz .erase_loop


    ld a, 0 : .erase_counter equ $-1
    inc a : ld (.erase_counter), a

    cp SCREEN_HEIGHT_LINES/3 - (4*3)  ; thanks to the curve we do not have to erase the whole screen
    ret nz


.erasing_end
    ld a, SPECTRAL_SPRITE_STATE_DISPLAYING_START : ld (.state), a
    ret


; Input
; HL: row of the column to erase
.erase_row
    repeat SCREEN_WIDTH
        ld a, (hl) : and SPECTRAL_SPRITE_ERASE_MASK_BOTH_POS: ld (hl), a : inc hl
    endr
    ret



.continue_movement
    jp spectral_sprite_move_along_curve ; continue to move

;; Draw the requested logo, statically, in the middle of the screen (see
;; spectral_sprite_move_along_curve_{logo_id} for the per-logo animated counterpart). Drawn
;; COLUMN by column: each column starts at its own line spectral_column_top_line_<logo>[col].
;; The model is read from spectral_sprites_matrix_<logo> (row-major, so a column is walked with
;; stride SPECTRAL_SPRITE_WIDTH).
;; Display is done now in several steps


assert SPECTRAL_SPRITE_HEIGHT == 5
SPECTRAL_SPRITE_HEIGHT_HALF1 equ 3
SPECTRAL_SPRITE_HEIGHT_HALF2 equ 2


repeat 2, LOGO_DISPLAY_PART, 0
show_static_sprite_continue_{{LOGO_DISPLAY_PART}}

    if {LOGO_DISPLAY_PART} == 0
        CURRENT_SPECTRAL_SPRITE_HEIGHT = SPECTRAL_SPRITE_HEIGHT_HALF1
    else
        CURRENT_SPECTRAL_SPRITE_HEIGHT = SPECTRAL_SPRITE_HEIGHT_HALF2
    endif

    OTHER_SPECTRAL_SPRITE_HEIGHT = SPECTRAL_SPRITE_HEIGHT - CURRENT_SPECTRAL_SPRITE_HEIGHT


    ld bc, 0 : .ix_value equ $-2 ; top_line_table
    ld hl, 0 : .iy_value equ $-2 ; matrix
    exx


    ld c, SPECTRAL_START_COLUMN : .column_start equ $-1        ; byte x of the current column within a line
  ;  ld b, SPECTRAL_SPRITE_WIDTH         ; number of columns to walk
.col_loop
    push bc
        ; screen address of this column's top = base(top line) + x
        exx :
          ld a, (bc)
          inc bc
          ld (.ix_value), bc

            ; Ensure 2nd half is displayed after first half
            ; so we shift it
            if {LOGO_DISPLAY_PART} == 1
                add SPECTRAL_BLOC_HEIGHT*OTHER_SPECTRAL_SPRITE_HEIGHT
            endif



          push hl

            if {LOGO_DISPLAY_PART} == 1
                ld de, OTHER_SPECTRAL_SPRITE_HEIGHT*SPECTRAL_SPRITE_WIDTH
                add hl, de
            endif
            ld de, SPECTRAL_SPRITE_WIDTH

        exx
        ld h, high(spectral_screen_table_hi) : ld l, a : ld d, (hl) ; d = high byte of the line base
        ld h, high(spectral_screen_table_lo)             : ld e, (hl) ; e = low  byte of the line base
        ld l, c : ld h, 0 : add hl, de          ; hl = column top screen address

        ; walk the column's model rows, drawing a bloc wherever there is a '#'
            ld b, CURRENT_SPECTRAL_SPRITE_HEIGHT ; XXX we only draw half of the sprite because it is too costly. We'll draw the other half after
.row_loop
            push bc
                exx : ld a, (hl) : exx : cp '#'
                jp nz, .empty
               push hl 
                
                
.show_bloc
                    ;ld b, SPECTRAL_BLOC_HEIGHT/2
                    ;assert SPECTRAL_BLOC_WIDTH % 2 = 0, "SPECTRAL_BLOC_WIDTH must be even "

                    push bc
    ;                repeat SPECTRAL_BLOC_HEIGHT/2
                    ld b, SPECTRAL_BLOC_HEIGHT/2
.yloop
                        push bc

                            repeat SPECTRAL_BLOC_WIDTH
                                if SPECTRAL_PLAIN
                                    set SPECTRAL_SPRITE_RIGHT_BIT_POS, (hl)
                                endif
                                set SPECTRAL_SPRITE_LEFT_BIT_POS, (hl) : inc hl
                            endrepeat
                            SPECTRAL_BC26_HL()
                            repeat SPECTRAL_BLOC_WIDTH
                                dec hl : set SPECTRAL_SPRITE_RIGHT_BIT_POS, (hl)
                                if SPECTRAL_PLAIN
                                    set SPECTRAL_SPRITE_LEFT_BIT_POS, (hl)
                                endif
                            endrepeat
                            SPECTRAL_BC26_HL()
                        pop bc
                    djnz .yloop
;                    endrepeat
                    pop bc

                pop hl   ; draw; keep hl on this bloc's top
.empty
                ld de, SPECTRAL_BLOC_STRIDE  : add hl, de  ; down to the next bloc
                exx
                    add hl, de  ; next model row of this column
                exx
            pop bc
            ;ld a, c : dec a : ld c,a 
            dec b
            jp nz, .row_loop
        exx
            pop hl
            inc hl                                  ; next model column
        exx
    pop bc
    ld a, c : add SPECTRAL_BLOC_WIDTH : ld (.column_start), a         ; next column x
  
    
    ; check if it is finished
    ld a, 0 : .col_counter equ $-1
    dec a
    jr z, .done

    ld (.col_counter), a
    exx
        ld (.iy_value), hl
    exx
    
    ;djnz .col_loop
    ret

.done

   if {LOGO_DISPLAY_PART} == 0
        ld a, SPECTRAL_SPRITE_STATE_DISPLAYING_CONTINUE2
    else

        ld a, 1 : .color_wait equ $-1
        or a
        jr z, .change_color
        dec a : ld (.color_wait), a
        jr .after_change_color


.change_color
.change_color_ptr+*:
        ld hl, joint_palette_spectral_writter_set
        ld e, (hl) : inc hl
        ld d, (hl)
        ld a, d : or e : jr nz, .really_change_color
.reset_change_color_table
        ld hl, joint_palette_spectral_writter_set
        ld e, (hl) : inc hl
        ld d, (hl)
.really_change_color
        inc hl
        ld (demo_frame_init.selected_palette), de

        ; get the spectral disabled palette
        ld e, (hl) : inc hl
        ld d, (hl) : inc hl

        ld (.change_color_ptr), hl

        ; when spectral are disabled, we must keep the rest
        ld hl, palette_all_but_spectral
        ex hl, de
        ld bc, 16
        ldir

.after_change_color
        ld a, SPECTRAL_SPRITE_STATE_WAVING : 
    endif
    
    ld (spectral_sprite_handle.state), a
    

    ret
endr

spectral_sprite_move_along_curve

    ld a, 0 : .activate_select_next_logo equ $-1
    or a
    jr z, .continue

    ; handle potential logo change

    ld hl, 1 : .change_counter equ $-2
    dec hl
    ld (.change_counter), hl
    ld a, h : or l
    jr nz, .continue

    ld hl, SPECTRAL_SPRITE_DISPLAY_DURATION_LOGO
    ld (.change_counter), hl

    ; change the logo state to erase current logo and replace it
    ld a, SPECTRAL_SPRITE_STATE_ERASING
    ld (spectral_sprite_handle.state), a

.continue



    jp spectral_sprite_move_along_curve_0 : .routine equ $-2

.table
    repeat NB_SPECTRAL_LOGOS, SPECTRAL_LOGO_ID, 0
        dw spectral_sprite_move_along_curve_{SPECTRAL_LOGO_ID}
    endrepeat

    align 256
; spectral curve
; 0 => decrease
; 2=> nothing
;  4=> increase
; XXX limitation Needs to be setup in memory BEF
delta_x_curve db SPECTRAL_DELTA_CURVE
