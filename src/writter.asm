

;; Drawing a whole page in one go (clearing + every line + every char) is far too
;; slow to fit in a frame, so the page draw is implemented as a state machine:
;; writter_draw_page_start (re)starts it, and writter_draw_page_step performs a
;; single bounded unit of work (clear one scanline, or draw one char) each time
;; it is called. Call writter_draw_page_step as many times as needed (e.g. once
;; per frame). Once a page is fully drawn, it is left on screen for
;; WRITTER_PAGE_WAIT_FRAMES calls, then the next page (from WRITTER_PAGES,
;; wrapping around at its 0 terminator) starts being drawn automatically.
    enum WRITTER_STATE
        CLEAR  ; clear the buffer
        DRAW   ; draw in the buffer
        COPY   ; copy the buffer to visible screen space
        WAIT   ; wait before switching to the next page
    endenum

; drawing phase, between lines
writter_current_page dw WRITTER_PAGE0    ; page selected by the last writter_draw_page_start call
writter_page_line_ptr dw 0                ; current line record in the page
writter_char_ptr dw 0                       ; pointer to the next char code to draw in the current line
writter_cursor dw 0                           ; screen address of the next char to draw

; wait phase, between pages
writter_next_page_ptr dw WRITTER_PAGES+2      ; WRITTER_PAGES entry to load once the wait is over

;; Prepares the state machine to (re)draw the given page from scratch.
;; Input: hl = address of the page to draw (e.g. one of the WRITTER_PAGES entries)
;; Must be called once before writter_draw_page_step is called repeatedly.
writter_draw_page_start
    ld (writter_current_page), hl
    ld hl, screen_table2 + WRITTER_GRID_START_ROW*16
    ld (writter_clear_ptr), hl
    ld a, WRITTER_GRID_HEIGHT*8
    ld (writter_clear_left), a
    ld a, WRITTER_STATE_CLEAR
    ld (writter_state), a
    ret

;; Performs one bounded unit of work towards drawing the page (clearing one
;; scanline, or drawing one char). Call repeatedly (e.g. once per frame)
;;
;; NB: most of the counters/pointers below are read through self modifying
;; code (an "ld a/hl, 0" whose immediate operand IS the variable, addressed
;; via "label equ $-1/$-2") instead of a plain "ld a/hl, (label)". This avoids
;; an extra memory access on the hottest read of each variable (speed matters
;; more than readability in this per-frame code); every other read/write of
;; the same variable still goes through the label normally, there is only
;; ever one physical storage location.
writter_draw_page_step
    ld a, WRITTER_STATE_CLEAR : writter_state equ $-1
    cp WRITTER_STATE_CLEAR
    jr z, .clear_step
    cp WRITTER_STATE_DRAW
    jp z, .draw_step                     ; jp: the unrolled clear pushes the target out of jr range
    cp WRITTER_STATE_COPY
    jp z, .copy_step
    cp WRITTER_STATE_WAIT
    jr z, .wait_step
    ret                                  ; nothing to do (done, or not started)

.wait_step



    ld a, 0 : writter_wait_left equ $-1
    dec a
    ld (writter_wait_left), a
    ret nz                                  ; still waiting, nothing else to do this call

    ld a, 1 : ld (writter_wait_left), a ; for an extra round

    ; there is no copy while the background animation is playing, as it would overwrite the background sprite
    ld a, (animation_state)
    cp ANIMATION_STATE_PLAYING
    
    ret z


    ; deactivate background stuff
    xor a : ld (demo_frame_run.animated_background_activated), a


    ; the wait is over: fetch the next page from WRITTER_PAGES, wrapping back
    ; to its start once the 0 terminator is reached
    ld hl, (writter_next_page_ptr)
    ld a, (hl) : ld e, a
    inc hl
    ld a, (hl) : ld d, a                    ; de = next page address (0 if the terminator was reached)
    inc hl
    ld a, d : or e
    jr nz, .next_page_found
        ld hl, WRITTER_PAGES
        ld a, (hl) : ld e, a
        inc hl
        ld a, (hl) : ld d, a
        inc hl
.next_page_found
    ld (writter_next_page_ptr), hl
    ex de, hl
    jp writter_draw_page_start                ; hl = next page address ; also returns to our caller

.clear_step
    ld hl, (screen_table2 + WRITTER_GRID_START_ROW*16) : writter_clear_ptr equ $-2   ; hl = scanline address to clear (dereferenced directly)
    ; fully unrolled (no counter, no djnz); inc hl and not inc l as a buffer
    ; line can cross a 256 bytes boundary
    repeat SCREEN_WIDTH, clearid, 0
        ld a, (hl)
        and WRITTER_CLEAR_MASK
        ld (hl), a
        if {clearid} != SCREEN_WIDTH-1
            inc hl
        endif
    endr

    ld hl, (writter_clear_ptr)
    inc hl : inc hl
    ld (writter_clear_ptr), hl               ; advance to the next screen_table2 entry

    ld a, 0 : writter_clear_left equ $-1
    dec a
    ld (writter_clear_left), a
    ret nz                                  ; more scanlines to clear on later calls

    ; clearing is done: set up the drawing phase, starting at the first line
    ld hl, (writter_current_page)
    ld (writter_page_line_ptr), hl
    ld hl, screen_table2 + WRITTER_GRID_START_ROW*16
    ld (writter_page_table_ptr), hl
    ld a, WRITTER_GRID_HEIGHT
    ld (writter_page_rows_left), a
    call writter_start_line
    ld a, WRITTER_STATE_DRAW
    ld (writter_state), a
    ret

.draw_step
    ld a, 0 : writter_chars_left equ $-1
    or a
    jp nz, .draw_one_char

        ; the current line is fully drawn: move to the next row (if any)
        call writter_advance_to_next_row
        ret z                                ; the whole page is now drawn
        call writter_start_line
        ret                                    ; the new line's first char is drawn on a later call

.copy_step
/*
    ; the transition tables contain the addresses of the blocks in the VISIBLE
    ; screen (0xC000); the source address in the buffer is obtained by
    ; resetting bit 6 of the high byte.
    ; Each stage call handles WRITTER_TRANSITION_NB_PARALLEL blocks; the stages
    ; are staggered by a few frames (the .delay_* counters) to obtain the
    ; dissolve effect: half-erase, other half-erase, half-copy, other half-copy.

    call copy_blocks_erase1

    ld a, WRITTER_COPY_DELAY_STEPS : .delay_erase2 equ $-1
    or a : jr z, .delay_erase2_done
    dec a : ld (.delay_erase2), a
    ret

.delay_erase2_done
    call copy_blocks_erase2

    ld a, WRITTER_COPY_DELAY_STEPS : .delay_step1 equ $-1
    or a : jr z, .delay_step1_done
    dec a : ld (.delay_step1), a
    ret
*/
.delay_step1_done
    call copy_blocks_step1

    ld a, WRITTER_COPY_DELAY_STEPS : .delay_step2 equ $-1
    or a : jr z, .delay_step2_done
    dec a : ld (.delay_step2), a
    ret

.delay_step2_done
    call copy_blocks_step2

    ; once the last copy stage has consumed its last call, the transition is
    ; over: keep the page on screen for a while before the next one
.install_wait_state
    ld a, (copy_blocks_step2.count)
    or a : ret nz
    ld a, WRITTER_PAGE_WAIT_FRAMES
    ld (writter_wait_left), a
    ld a, WRITTER_STATE_WAIT
    ld (writter_state), a
    ; background animation is activated when we can wait
    ld a, 1 : ld (demo_frame_run.animated_background_activated), a
    ld a, 1 : ld (demo_frame_run.reset_animation), a
    ret



.draw_one_char
    ld hl, (writter_char_ptr)
    ld a, (hl) : inc hl
    ld (writter_char_ptr), hl                  ; a = char code of the next char

    add a, a                                     ; *2: each WRITTER_MAPPING entry is a word
    ld l, a : ld h, 0
    ld bc, WRITTER_MAPPING
    add hl, bc
    ld e, (hl) : inc hl : ld d, (hl)              ; de = char record (nb pixels + the 2 sprite pointers)

    ld a, (de) : inc de                             ; a = nb of pixels of the char
    ld (writter_pixels_pending), a

    ld a, 0 : writter_side equ $-1
    or a : jr z, .use_even_sprite
    inc de : inc de                                  ; the char starts mid-byte: use the odd-aligned sprite
.use_even_sprite
    ex de, hl
    ld e, (hl) : inc hl : ld d, (hl)                  ; de = sprite (routine address + pixel data)
    ex de, hl
    ld c, (hl) : inc hl
    ld b, (hl) : inc hl                                 ; bc = drawing routine for this sprite width
    ex de, hl                                            ; de = sprite pixel data
    ld (.or_routine+1), bc
    ld hl, (writter_cursor)                              ; hl = buffer address to draw the char
.or_routine
    call writter_or_sprite_w1                             ; SMC: actually the routine matching the sprite width

    ; move the cursor past the char and update the current side
    ; total = side + nb_pixels ; bytes advanced = total>>1 ; new side = total&1
    ld a, (writter_side)
    ld b, a
    ld a, 0 : writter_pixels_pending equ $-1
    add a, b
    srl a                                            ; a = bytes to advance ; carry = new side
    ld c, a : ld b, 0
    push af                                          ; save the new-side carry: "add hl, bc" below also sets carry, it would clobber it
    ld hl, (writter_cursor)
    add hl, bc
    ld (writter_cursor), hl
    pop af
    ld a, 0 : adc a, 0
    ld (writter_side), a

    ld a, (writter_chars_left)
    dec a
    ld (writter_chars_left), a
    ret


;; Advances writter_page_line_ptr/writter_page_table_ptr/writter_page_rows_left past
;; the line that was just drawn. Returns Z (and switches writter_state to
;; WRITTER_STATE_WAIT, to pause on the finished page for a while before the
;; next one starts) when the whole page has been drawn, NZ otherwise.
writter_advance_to_next_row
    ld hl, (writter_page_line_ptr)
    inc hl : inc hl
    ld a, (hl)                         ; a = nb chars of the line just drawn
    dec hl : dec hl
    add a, 3
    ld c, a : ld b, 0
    add hl, bc
    ld (writter_page_line_ptr), hl

    ld hl, (writter_page_table_ptr)
    ld bc, 16
    add hl, bc
    ld (writter_page_table_ptr), hl

    ld a, 0 : writter_page_rows_left equ $-1
    dec a
    ld (writter_page_rows_left), a
    ret nz


    ld a, WRITTER_STATE_COPY
    ld (writter_state), a
    ld a, WRITTER_TRANSITION_NB_CALLS_FULL : .nb_calls equ $-1
    ld (copy_blocks_erase1.count), a
    ld (copy_blocks_erase2.count), a
    ld (copy_blocks_step1.count), a
    ld (copy_blocks_step2.count), a

    ; the first execution draws the full image. The others only the writter
    ld a, WRITTER_TRANSITION_NB_CALLS : ld (.nb_calls), a


    ld hl, transition_tables : .transtion_ptr equ $-2
.restart_transition_tables
    ld c, (hl) : inc hl : ld b, (hl) : inc hl
    ld a, b : or c : jr nz, .setup_transition_tables
    ld hl, transition_tables.restart : jr .restart_transition_tables
    
.setup_transition_tables
    ld (.transtion_ptr), hl
    ld (copy_blocks_erase1.copy_table_position), bc
    ld (copy_blocks_erase2.copy_table_position), bc
    ld (copy_blocks_step1.copy_table_position), bc
    ld (copy_blocks_step2.copy_table_position), bc
    
    ld a, WRITTER_COPY_DELAY_STEPS
    ;ld (writter_draw_page_step.delay_step1), a
    ;ld (writter_draw_page_step.delay_erase2), a
    ld (writter_draw_page_step.delay_step2), a
    xor a                                    ; ensure Z is set for the caller (WRITTER_STATE_WAIT is nonzero)
    ret


;; Reads the line pointed to by writter_page_line_ptr/writter_page_table_ptr and sets
;; up writter_cursor/writter_side/writter_chars_left/writter_char_ptr to (re)start
;; drawing it one char at a time.
writter_start_line
    ; we read from screen_table2 as we use a double buffer
    ld hl, (screen_table2 + WRITTER_GRID_START_ROW*16) : writter_page_table_ptr equ $-2   ; bc = resolved row screen address (dereferenced directly)
    ld b, h : ld c, l

    ld hl, (writter_page_line_ptr)
    ld a, (hl) : inc hl                    ; a = nb bytes to skip
    add a, c : ld c, a
    ld a, 0 : adc a, b : ld b, a              ; bc = resolved row address + nb bytes to skip (no hl needed)
    ld (writter_cursor), bc

    ld a, (hl) : inc hl                    ; a = nb pixels to skip (0 or 1)
    ld (writter_side), a

    ld a, (hl) : inc hl                      ; a = nb chars in the line
    ld (writter_chars_left), a

    ld (writter_char_ptr), hl                   ; hl now points at the first char code
    ret

    ;; Walks the 8 bytes of one transition block (2 bytes x 8 scanlines) in a
    ;; checkerboard pattern and clears their right-pixel writter bit, directly
    ;; on the visible screen.
    ;; The walk is column-major (the 4 bytes of one column with +2 scanline
    ;; steps, then the 4 bytes of the other column) so moving around only
    ;; costs 8 bit operations on h/l instead of 16 bits ones on hl.
    ;; Input:
    ;; - hl = block address on the visible screen
    ;; - c  = 0x10 (2 scanlines step)
    ;; - start_col = column handled on the even lines (0 or 1); the other
    ;;   column is handled on the odd lines
    ;; Corrupts a, hl
    macro TRANSITION_ERASE_WALK start_col
        assert WRITTER_TRANSITION_ATOMIC_UNIT_WIDTH_IN_PIXELS == 4
        assert WRITTER_TRANSITION_ATOMIC_UNIT_HEIGHT_IN_PIXELS == 8

        if {start_col} == 1
            inc l                                ; NB: block low bytes never reach 0xFF (x is even <= 94), so inc l/dec l cannot wrap
        endif
        repeat 4, i, 0
            res WRITTER_RIGHT_BIT_POS, (hl)
            if {i} != 3
                ld a, c : add h : ld h, a
            endif
        endr
        ; move from the last even line back to line 1, on the other column
        ld a, h : sub 5*8 : ld h, a
        if {start_col} == 1
            dec l
        else
            inc l
        endif
        repeat 4, i, 0
            res WRITTER_RIGHT_BIT_POS, (hl)
            if {i} != 3
                ld a, c : add h : ld h, a
            endif
        endr
    endm

    ;; Same walk as TRANSITION_ERASE_WALK, but copies the bytes from the
    ;; buffer to the visible screen instead of erasing them.
    ;; Input:
    ;; - hl = block address in the buffer
    ;; - de = block address on the visible screen (d = h + 0x40, e = l)
    ;; - b  = 0x40 (buffer -> screen high byte offset)
    ;; - c  = 0x10 (2 scanlines step)
    ;; Corrupts a, hl, de
    macro TRANSITION_COPY_WALK start_col
        assert WRITTER_TRANSITION_ATOMIC_UNIT_WIDTH_IN_PIXELS == 4
        assert WRITTER_TRANSITION_ATOMIC_UNIT_HEIGHT_IN_PIXELS == 8

        if {start_col} == 1
            inc l : inc e
        endif
        repeat 4, i, 0
            ld a, (de) : and SPECTRAL_SPRITE_DRAW_MASK_BOTH_POS  ; keep the spectral sprite data
            or (hl) : ld (de), a; mix with drawned stuff           
            if {i} != 3
                ld a, c : add h : ld h, a : add b : ld d, a
            endif
        endr
        ; move from the last even line back to line 1, on the other column
        ld a, h : sub 5*8 : ld h, a : add b : ld d, a
        if {start_col} == 1
            dec l : dec e
        else
            inc l : inc e
        endif
        repeat 4, i, 0
            ld a, (de) : and SPECTRAL_SPRITE_DRAW_MASK_BOTH_POS  ; keep the spectral sprite data
            or (hl) : ld (de), a; mix with drawned stuff  
            if {i} != 3
                ld a, c : add h : ld h, a : add b : ld d, a
            endif
        endr
    endm

    ;; Generates one erase stage routine: each call clears half of the writter
    ;; pixels (checkerboard given by start_col) of the next
    ;; WRITTER_TRANSITION_NB_PARALLEL blocks of the transition table.
    macro TRANSITION_ERASE_STAGE stage_name, start_col
copy_blocks_{stage_name}
    ld a, WRITTER_TRANSITION_NB_CALLS_FULL : .count equ $-1
    or a : ret z
    dec a : ld (.count), a

    ld c, 0x10
    ld hl, writter_transition_table0 : .copy_table_position equ $-2
    repeat WRITTER_TRANSITION_NB_PARALLEL
        ld e, (hl) : inc hl
        ld d, (hl) : inc hl
        ex de, hl                    ; hl = block address on screen ; de = table ptr (untouched by the walk)
        TRANSITION_ERASE_WALK({start_col})
        ex de, hl                    ; hl = table ptr back
    endr
    ld (.copy_table_position), hl
    ret
    endm

    ;; Generates one copy stage routine: each call copies half of the bytes
    ;; (checkerboard given by start_col) of the next
    ;; WRITTER_TRANSITION_NB_PARALLEL blocks from the buffer to the screen.
    macro TRANSITION_COPY_STAGE stage_name, start_col
copy_blocks_{stage_name}
    ld a, WRITTER_TRANSITION_NB_CALLS_FULL : .count equ $-1
    or a : ret z
    dec a : ld (.count), a

    ld bc, 0x40*256 + 0x10
    ld hl, writter_transition_table0 : .copy_table_position equ $-2
    repeat WRITTER_TRANSITION_NB_PARALLEL
        ld e, (hl) : inc hl
        ld d, (hl) : inc hl          ; de = block address on the visible screen
        push hl                       ; the copy walk needs both hl and de
            ld h, d : ld l, e
            res 6, h                  ; hl = block address in the buffer
            TRANSITION_COPY_WALK({start_col})
        pop hl
    endr
    ld (.copy_table_position), hl
    ret
    endm


    

;; Erase previous page, half of the pixels...
    TRANSITION_ERASE_STAGE(erase1, 0)
;; ... then the other half
    TRANSITION_ERASE_STAGE(erase2, 1)
;; Copy the new page from the buffer, half of the bytes...
    TRANSITION_COPY_STAGE(step1, 0)
;; ... then the other half; this stage ends the transition
    TRANSITION_COPY_STAGE(step2, 1)




    ;; Generate a char drawing routine specialized for one byte width: it ORs
    ;; the pre-rendered sprite into the buffer, fully unrolled (no counters,
    ;; no push/pop, no per-pixel work).
    ;; Input
    ;; - hl = address of the buffer to draw the char
    ;; - de = address of the sprite pixel data (8 lines x width bytes, line-major)
    ;; Corrupts a, bc, de, hl
    macro WRITTER_OR_SPRITE_ROUTINE w
writter_or_sprite_w{w}
        ld bc, 0x800 - ({w}-1)          ; from the last byte of a line to the first byte of the next one
        repeat 8, lineid, 0
            repeat {w}, colid, 0
                ld a, (de) : or (hl) : ld (hl), a : inc de
                if {colid} != {w}-1
                    inc hl               ; NB: inc hl and not inc l, a buffer line can cross a 256 bytes boundary
                endif
            endr
            if {lineid} != 7
                add hl, bc
            endif
        endr
        ret
    endm

    WRITTER_OR_SPRITE_ROUTINE(1)
    WRITTER_OR_SPRITE_ROUTINE(2)
    WRITTER_OR_SPRITE_ROUTINE(3)
    WRITTER_OR_SPRITE_ROUTINE(4)
    WRITTER_OR_SPRITE_ROUTINE(5)



    ;; The pixels drawned from left to right are produced from a byte from right to left
    function writter_string_to_bitvalues content 
    ;function writter_string_to_bitvalues(conten). ; BUG assembler does not accept it 
        assert string_len({content}) <= 8

        content={content}
        value = 0
        ;iter pixel in {content} ; BUG Function writter_string_to_bitvalues error: error: REPEAT issue: {content} is not a list or a matrix but a label
        repeat string_len({content}), pos, 0
            pos = {pos}
            pixel = string_get({content}, pos)
            if pixel == '#'
                value = value | (1 << pos)
            endif
        endrepeat
        ;enditer

        print {content}, "->", {bin8}value
        return value
    endfunction

    ;; Compute the mode0 byte (restricted to the writter bits) of column j of
    ;; a char line drawn at an EVEN pixel position: the byte holds
    ;; pixels 2j (left slot) and 2j+1 (right slot)
    function writter_even_sprite_byte v, j
        v = {v}
        j = {j}
        r = 0
        if ((v >> (2*j)) & 1) != 0
            r = r | WRITTER_LEFT_DRAW_MASK
        endif
        if ((v >> (2*j+1)) & 1) != 0
            r = r | WRITTER_RIGHT_DRAW_MASK
        endif
        return r
    endfunction

    ;; Same for a char line drawn at an ODD pixel position: the first byte
    ;; only holds pixel 0 (right slot, the left slot belongs to the previous
    ;; char), byte j>=1 holds pixels 2j-1 (left slot) and 2j (right slot)
    function writter_odd_sprite_byte v, j
        v = {v}
        j = {j}
        r = 0
        if j != 0
            if ((v >> (2*j-1)) & 1) != 0
                r = r | WRITTER_LEFT_DRAW_MASK
            endif
        endif
        if ((v >> (2*j)) & 1) != 0
            r = r | WRITTER_RIGHT_DRAW_MASK
        endif
        return r
    endfunction

    ;; Emit the address of the sprite drawing routine specialised for the
    ;; given byte width (1 to 5)
    macro WRITTER_SPRITE_ROUTINE_PTR w
        assert {w} >= 1 && {w} <= 5
        if {w} == 1
            dw writter_or_sprite_w1
        endif
        if {w} == 2
            dw writter_or_sprite_w2
        endif
        if {w} == 3
            dw writter_or_sprite_w3
        endif
        if {w} == 4
            dw writter_or_sprite_w4
        endif
        if {w} == 5
            dw writter_or_sprite_w5
        endif
    endm

    ;; Emit one pre-rendered sprite: the routine address followed by the
    ;; 8 lines x width bytes, line-major (the drawing routines walk the data
    ;; with a simple inc de)
    macro WRITTER_EMIT_SPRITE width, parity
        WRITTER_SPRITE_ROUTINE_PTR({width})
        repeat 8, lineid, 0
            repeat {width}, colid, 0
                db writter_{parity}_sprite_byte(list_get(current_char_lines, {lineid}), {colid})
            endr
        endr
    endm


    ; TODO update when a new char is used
    function writter_char_to_code char
        if {char} == " "
            return "sp"
        elseif {char} == ":"
            return "column"
        elseif {char} == "."
            return "dot"
        elseif {char} == "'"
            return "acute"
        elseif {char} == ","
            return "comma"
        elseif {char} == "!"
            return "exclam"
        else
            return {char}
        endif
    endfunction

    ; TODO update when a new char is used
    function writter_code_to_char code
        if {code} == "sp"
            return " "
        elseif {code} == "column"
            return ":"
        elseif {code} == "dot"
            return "."
        elseif {code} == "exclam"
            return "!"
        elseif {code} == "acute"
            return "'"
        elseif {code} == "comma"
            return ","
        else
            return {code}
        endif
    endfunction

    ; collect the chars of the font
    writter_complete_charset = ""
    ;;
    ;; Generate the data for the given char for the writter.
    ;; The number of columns can be different for each char, but the same for all the lines of the current char.
    ;; The last line is probably empty for most of the chars, but it is not mandatory.
    ;; The last column is probably empty for most of the chars, but it is not mandatory.
    ;; Each char has 8 pixels columns maximum:
    ;;   - we can fill it in a byte
    ;;   - therre is no reason to have chars too much wide especially in mode 0 resolution
    ;; '#' represents a pixel on
    ;; ' ' represents a pixel off
    ;;
    ;; The char is stored pre-rendered (writter bits only) in its two possible
    ;; mode0 alignments (start on an even or an odd pixel), so drawing it is a
    ;; simple OR of the sprite into the buffer: the buffer clearing phase has
    ;; already removed every writter bit, and ORing preserves both the
    ;; background bits and the right pixel of the previous char in a shared byte.
    macro WRITTER_CREATE_CHAR(symb, line0, line1, line2, line3, line4, line5, line6, line7)

        current_code="{symb}"
        current_char = writter_code_to_char(current_code)
        writter_complete_charset = string_concat(writter_complete_charset, current_char)

        CURRENT_CHAR_LENGTH = string_len({line0})

        ; ensure the line is not > 8
        assert CURRENT_CHAR_LENGTH <= 8

        ; Ensure the lines have the same length
        assert CURRENT_CHAR_LENGTH == string_len({line1}), "All lines must have the same length"
        assert CURRENT_CHAR_LENGTH == string_len({line2}), "All lines must have the same length"
        assert CURRENT_CHAR_LENGTH == string_len({line3}), "All lines must have the same length"
        assert CURRENT_CHAR_LENGTH == string_len({line4}), "All lines must have the same length"
        assert CURRENT_CHAR_LENGTH == string_len({line5}), "All lines must have the same length"
        assert CURRENT_CHAR_LENGTH == string_len({line6}), "All lines must have the same length"
        assert CURRENT_CHAR_LENGTH == string_len({line7}), "All lines must have the same length"

        current_char_lines = []
        current_char_lines = list_push(current_char_lines, writter_string_to_bitvalues({line0}))
        current_char_lines = list_push(current_char_lines, writter_string_to_bitvalues({line1}))
        current_char_lines = list_push(current_char_lines, writter_string_to_bitvalues({line2}))
        current_char_lines = list_push(current_char_lines, writter_string_to_bitvalues({line3}))
        current_char_lines = list_push(current_char_lines, writter_string_to_bitvalues({line4}))
        current_char_lines = list_push(current_char_lines, writter_string_to_bitvalues({line5}))
        current_char_lines = list_push(current_char_lines, writter_string_to_bitvalues({line6}))
        current_char_lines = list_push(current_char_lines, writter_string_to_bitvalues({line7}))

        CURRENT_EVEN_WIDTH = (CURRENT_CHAR_LENGTH+1)>>1
        CURRENT_ODD_WIDTH = (CURRENT_CHAR_LENGTH+2)>>1


        print "WRITTER_CREATE_CHAR: ", current_code, " ", CURRENT_CHAR_LENGTH, " pixels, even width=", CURRENT_EVEN_WIDTH, ", odd width=", CURRENT_ODD_WIDTH

writter_char_{symb}:
.nb_pixels db CURRENT_CHAR_LENGTH
        dw .even_sprite
        dw .odd_sprite
.even_sprite
        WRITTER_EMIT_SPRITE CURRENT_EVEN_WIDTH, even
.odd_sprite
        WRITTER_EMIT_SPRITE CURRENT_ODD_WIDTH, odd

writter_char_{symb}_length equ CURRENT_CHAR_LENGTH
    endm


    ;; Generate the entry table for the given letter
    macro WRITTER_MAPPING_ENTRY char
        @letter={char}
        dw writter_char_{@letter}
    endm


    ;; Macro to generate the table that maps the writter chars to their data.
    macro WRITTER_MAPPING_GENERATE 
   
        print "WRITTER CHARSET", writter_complete_charset
        charset writter_complete_charset, 0


        repeat string_len(writter_complete_charset), i, 0 ; we skip sp
            current_char = string_get(writter_complete_charset, {i})
            current_code = writter_char_to_code(current_char)
            
            print current_char, "->", current_code
            WRITTER_MAPPING_ENTRY({eval}current_code) 
        endrepeat
    endm

 

    ;; A line is shown horizontally centered and is encoded this way
    ;; - Number of bytes to skip in the line (1 byte)
    ;; - Number of pixels to skip in the line (0 or 1) (1 byte)
    ;; - Number of chars in the line (1 byte)
    ;; - For each char its code (1 byte/char, mapped through the writter charset, see WRITTER_MAPPING_GENERATE)
    macro WRITTER_ENCODE_LINE content
        print "{content}"
        if string_len({content}) == 0
            ; do not do nothing, but emit a line with a single space char (the first char of the writter charset)
            db 0 ; nb bytes to skip
            db 0 ; nb pixels to skip
            db 1 ; nb chars
            db ' '
        else
            ; Compute the total number of pixels in the string
            CURRENT_TOTAL_PIXELS_SIZE = 0
            repeat string_len({content}), i, 0
                current_char = string_get({content}, {i})
                current_code = writter_char_to_code(current_char)
                print current_char
                print current_code
                assert  writter_char_{current_code}_length <= 8
                CURRENT_TOTAL_PIXELS_SIZE += writter_char_{current_code}_length
            endrepeat

            assert CURRENT_TOTAL_PIXELS_SIZE <= WRITTER_GRID_WIDTH_PIXELS, "Line ", {content}, "  is too long for the writter grid"
            ; centering offset: half of the unused pixels of the grid
            CURRENT_SKIP_PIXELS_SIZE = (WRITTER_GRID_WIDTH_PIXELS - CURRENT_TOTAL_PIXELS_SIZE) / 2
            db CURRENT_SKIP_PIXELS_SIZE>>1 ; nb bytes to skip
            db CURRENT_SKIP_PIXELS_SIZE&1  ; nb pixels to skip
            db string_len({content})       ; nb chars
            db {content}                    ; char codes, mapped through the currently active charset
        endif





        print "WRITTER_ENCODE_LINE: ", peek($-4), ", ", peek($-3), ", ", peek($-2), ", ", peek($-1), ", ", {content}
    endm

    ;; A page is build with 10 lines.
    ;; Lines can be empty, but they must be present.
    ;; Each line is encoded with WRITTER_ENCODE_LINE
    ;; TODO here it would be better to modify basm to work with unamed arguments.
    ;;       this way we could work with a loop instead of hardcoding all cases
    macro WRITTER_ENCODE_PAGE line0, line1, line2, line3, line4, line5, line6, line7, line8, line9
        print "WRITTER_ENCODE_PAGE ", {line0}, ", ", {line1}, ", ", {line2}, ", ", {line3}, ", ", {line4}, ", ", {line5}, ", ", {line6}, ", ", {line7}, ", ", {line8}, ", ", {line9}
.line0
        WRITTER_ENCODE_LINE({line0})
.line1      
        WRITTER_ENCODE_LINE({line1})
.line2      
        WRITTER_ENCODE_LINE({line2})
.line3
        WRITTER_ENCODE_LINE({line3})
.line4
        WRITTER_ENCODE_LINE({line4})
.line5
        WRITTER_ENCODE_LINE({line5})
.line6
        WRITTER_ENCODE_LINE({line6})
.line7
        WRITTER_ENCODE_LINE({line7})
.line8
        WRITTER_ENCODE_LINE({line8})
.line9
        WRITTER_ENCODE_LINE({line9})
    endm




function IS_NOT_CRLF char
    return {char} != 10 && {char} != 13
endfunction

    CURRENT_PAGE_NUMBER = 0

    macro WRITTER_ADD_PAGE_FROM_FILE file_name
WRITTER_PAGE{CURRENT_PAGE_NUMBER}
    CURRENT_PAGE_NUMBER += 1
    CURRENT_PAGE_CONTENT = load({file_name})
    CURRENT_PAGE_LINES = list_split_by_value(CURRENT_PAGE_CONTENT, "\n")

    if list_len(CURRENT_PAGE_LINES) != WRITTER_GRID_HEIGHT
        fail "Page must have exactly ", WRITTER_GRID_HEIGHT, " lines. Here you have", list_len(CURRENT_PAGE_LINES)
    endif


    line0 = string_from_list(list_filter(list_get(CURRENT_PAGE_LINES, 0), "IS_NOT_CRLF"))
    line1 = string_from_list(list_filter(list_get(CURRENT_PAGE_LINES, 1), "IS_NOT_CRLF"))
    line2 = string_from_list(list_filter(list_get(CURRENT_PAGE_LINES, 2), "IS_NOT_CRLF"))
    line3 = string_from_list(list_filter(list_get(CURRENT_PAGE_LINES, 3), "IS_NOT_CRLF"))
    line4 = string_from_list(list_filter(list_get(CURRENT_PAGE_LINES, 4), "IS_NOT_CRLF"))
    line5 = string_from_list(list_filter(list_get(CURRENT_PAGE_LINES, 5), "IS_NOT_CRLF"))
    line6 = string_from_list(list_filter(list_get(CURRENT_PAGE_LINES, 6), "IS_NOT_CRLF"))
    line7 = string_from_list(list_filter(list_get(CURRENT_PAGE_LINES, 7), "IS_NOT_CRLF"))
    line8 = string_from_list(list_filter(list_get(CURRENT_PAGE_LINES, 8), "IS_NOT_CRLF"))
    line9 = string_from_list(list_filter(list_get(CURRENT_PAGE_LINES, 9), "IS_NOT_CRLF"))

    WRITTER_ENCODE_PAGE(line0, line1, line2, line3, line4, line5, line6, line7, line8, line9)

    endm


; 6 pixels space
WRITTER_CREATE_CHAR(
    sp,
    "      ",
    "      ",
    "      ",
    "      ",
    "      ",
    "      ",
    "      ",
    "      "
)
    include "writter_font.asm"
    include "writter_pages.asm"


    macro WRITTER_GENERATE_PAGES
WRITTER_PAGES
        repeat CURRENT_PAGE_NUMBER, i, 0
            dw WRITTER_PAGE{i}
        endrepeat
        dw 0
    endm

    WRITTER_GENERATE_PAGES()


    ; Instead of storing pairs of x,y, directly store screen addresses
    ; it is the very same size
    macro BUILD_WRITTER_TRANSITION_TABLE table_code
writter_transition_table{table_code}
        current_db = WRITTER_TRANSITION_TABLE{table_code}
        repeat list_len(current_db), i, 0
            current_entry = list_get(current_db, {i})
            current_x = list_get(current_entry, 0)
            if {table_code} == 0
                current_y = list_get(current_entry, 1) ; full screen is used for this one
            else
                current_y = list_get(current_entry, 1) + 8*WRITTER_GRID_START_ROW ; we need to skip part upper the writter
            endif
            ; the VISIBLE screen address is stored (erase stages use it as is);
            ; the buffer address only differs by bit 6 of the high byte, so the
            ; copy stages derive it with a single "res 6, h"
            current_address = compute_screen_address(0xC000, 96, current_x, current_y)
            db low(current_address)
            db high(current_address)

        endrepeat
    endm
    

    ; generate the copy tables for the writter
    BUILD_WRITTER_TRANSITION_TABLE(0) ; XXX this one is the very first one. It concerns the whole screen and has to be handled differently than the others
    BUILD_WRITTER_TRANSITION_TABLE(1)
    BUILD_WRITTER_TRANSITION_TABLE(2)
    BUILD_WRITTER_TRANSITION_TABLE(3)
    
transition_tables
    dw writter_transition_table0 ; this one is used the very first time to display the whole screen
.restart
    dw writter_transition_table1
    dw writter_transition_table2
    dw writter_transition_table3
    dw 0


