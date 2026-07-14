;; June 2026
;; Krusty/Benediction
;; Start to work on the background display.
;; Nothing fancy here : there is a 4 colors background.
;;                      idealy it will have some animated parts



SPECTRAL_PLAIN = false

SCREEN_WDITH equ 96 ; number of bytes
SCREEN_HEIGHT_CHARS equ 21


MODE0_LEFT_PIXEL_BIT0_POS equ 7
MODE0_LEFT_PIXEL_BIT1_POS equ 3
MODE0_LEFT_PIXEL_BIT2_POS equ 5
MODE0_LEFT_PIXEL_BIT3_POS equ 1

MODE0_RIGHT_PIXEL_BIT0_POS equ 6
MODE0_RIGHT_PIXEL_BIT1_POS equ 2
MODE0_RIGHT_PIXEL_BIT2_POS equ 4
MODE0_RIGHT_PIXEL_BIT3_POS equ 0

; writter uses bit 3
WRITTER_LEFT_BIT_POS equ  MODE0_LEFT_PIXEL_BIT3_POS     
WRITTER_RIGHT_BIT_POS equ  MODE0_RIGHT_PIXEL_BIT3_POS    

WRITTER_LEFT_DRAW_MASK equ (1 << WRITTER_LEFT_BIT_POS)
WRITTER_RIGHT_DRAW_MASK equ (1 << WRITTER_RIGHT_BIT_POS)

WRITTER_LEFT_CLEAR_MASK equ ~(1 << WRITTER_LEFT_BIT_POS)
WRITTER_RIGHT_CLEAR_MASK equ ~(1 << WRITTER_RIGHT_BIT_POS)
WRITTER_CLEAR_MASK equ WRITTER_LEFT_CLEAR_MASK & WRITTER_RIGHT_CLEAR_MASK

; Original demo uses a fixed size font of 4 bytesx8 lines (i.e. 8 pixels x 6 pixels)
; I would preder a proportional font at pixel resolution
; (because Eliot discussed about that, so it would be neat)
WRITTER_CHAR_WIDTH_MAX equ 4  ; Let's consider it is a max size and that each char decides of its width
WRITTER_CHAR_HEIGHT equ 8  ; we really want to keep this 8 pixels height

WRITTER_GRID_HEIGHT equ 10
WRITTER_GRID_WIDTH_APPROXIMATE equ 24 ; as char are supposed to be propotional, we can only have an approximate number of char per line
WRITTER_GRID_WIDTH_PIXELS equ SCREEN_WDITH*2  ; TODO remove few pixels to be sure to not have hidden chars

; the writter grid is shorter than the screen, so it is vertically centered
; by starting a few char lines below the top of the screen
; NB: this must stay a whole number of char lines (8 scanlines) since it is
;     used as a row index into screen_table - "/2" would yield a .5 result
;     for an odd difference and misalign every row lookup, hence the ">>1"
WRITTER_GRID_START_ROW equ (SCREEN_HEIGHT_CHARS - WRITTER_GRID_HEIGHT) >> 1


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


        ; set up the background_palette for the background
        ld bc, 0x7f00 : out (c), c : ld a, (background_palette+0) : out (c), a
        ld bc, 0x7f01 : out (c), c : ld a, (background_palette+1) : out (c), a
        ld bc, 0x7f02 : out (c), c : ld a, (background_palette+2) : out (c), a
        ld bc, 0x7f03 : out (c), c : ld a, (background_palette+3) : out (c), a
        ld bc, 0x7f00 + 8 : out (c), c : ld a, (writter_palette+0) : out (c), a
        ld bc, 0x7f01 + 8 : out (c), c : ld a, (writter_palette+0) : out (c), a
        ld bc, 0x7f02 + 8 : out (c), c : ld a, (writter_palette+0) : out (c), a
        ld bc, 0x7f03 + 8 : out (c), c : ld a, (writter_palette+0) : out (c), a

        ; TODO setup the background_palette for the extra layers

        ; set up the background_palette for the background
		ld bc, 0x7f10 : out (c), c : ld bc, 0x7f54 : out (c), c
		ld sp, $


    ;; TODO Add argument to
    ;  - specify the char to display
    ;  - specify the char line position of the char to display
    ;  - specify the pixel column position of the char to display to have a pixel precision positionning
    
    if true
    ld hl, 0xC000   + 10 + 96         ; Screen address
        ld de, writter_char_a    ; Address of the character data
    call print_one_char_left

    ld hl, 0xC000   + 10 + 96  + 96        ; Screen address
        ld de, writter_char_a    ; Address of the character data
    call print_one_char_left

    ld hl, 0xC000   + 10 + 96  + 96  + 96      ; Screen address
        ld de, writter_char_a    ; Address of the character data
    call print_one_char_left


    ld hl, 0xC000   + 10 + 96  +4       ; Screen address
        ld de, writter_char_a    ; Address of the character data
    call print_one_char_left

    ld hl, 0xC000   + 10 + 96  + 96 +4       ; Screen address
        ld de, writter_char_a    ; Address of the character data
    call print_one_char_left

    ld hl, 0xC000   + 10 + 96  + 96  + 96  +4      ; Screen address
        ld de, writter_char_a    ; Address of the character data
    call print_one_char_left
    endif



    ; right stuff

    if true

    ld hl, 0xC000   + 10 + 96  + 40       ; Screen address
        ld de, writter_char_a    ; Address of the character data
    call print_one_char_right

    ld hl, 0xC000   + 10 + 96  + 96  + 40      ; Screen address
        ld de, writter_char_a    ; Address of the character data
    call print_one_char_right

    ld hl, 0xC000   + 10 + 96  + 96  + 96    + 40    ; Screen address
        ld de, writter_char_a    ; Address of the character data
    call print_one_char_right


    ld hl, 0xC000   + 10 + 96  +4    + 40     ; Screen address
        ld de, writter_char_a    ; Address of the character data
    call print_one_char_right

    ld hl, 0xC000   + 10 + 96  + 96 +4    + 40     ; Screen address
        ld de, writter_char_a    ; Address of the character data
    call print_one_char_right

    ld hl, 0xC000   + 10 + 96  + 96  + 96  +4   + 40     ; Screen address
        ld de, writter_char_a    ; Address of the character data
    call print_one_char_right
    endif



        ld hl, 0xC000   + 10 + 96  + 40  + 4*96     ; Screen address
        ld de, writter_char_a    ; Address of the character data
        call print_one_char_left

        ld hl, 0xC000   + 10 + 96  + 40  + 5*96     ; Screen address
        ld de, writter_char_a    ; Address of the character data
        call print_one_char_right

        ld hl, 0xC000   + 10 + 96  + 40  + 6*96 + 1    ; Screen address
        ld de, writter_char_a    ; Address of the character data
        call print_one_char_left

    call writter_draw_page_start
    ei
frame
    ld b, 0xF5
    in a, (c)
    rra
    jr nc, frame

    halt : halt

    ld bc, 0x7f10 : out (c), c : ld bc, 0x7f45 : out (c), c
    call writter_draw_page_step
    ld bc, 0x7f10 : out (c), c : ld bc, 0x7f54 : out (c), c

    jp frame



;; Drawing a whole page in one go (clearing + every line + every char) is far too
;; slow to fit in a frame, so the page draw is implemented as a state machine:
;; writter_draw_page_start (re)starts it, and writter_draw_page_step performs a
;; single bounded unit of work (clear one scanline, or draw one char) each time
;; it is called. Call writter_draw_page_step as many times as needed (e.g. once
;; per frame) until writter_state reaches WRITTER_STATE_DONE.
    enum WRITTER_STATE
        DONE 
        CLEAR
        DRAW
    endenum

writter_state db WRITTER_STATE_DONE

; clearing phase
writter_clear_ptr dw 0           ; next entry to read in screen_table
writter_clear_left db 0           ; scanlines still to clear

; drawing phase, between lines
writter_page_line_ptr dw 0         ; current line record in the page
writter_page_table_ptr dw 0         ; current row entry in screen_table
writter_page_rows_left db 0          ; rows still to draw in the page

; drawing phase, current line in progress (kept in memory, not registers,
; since print_one_char_left/print_one_char_right clobber af/bc/de/hl, and the
; state must also survive whatever runs between two writter_draw_page_step calls)
writter_side db 0              ; 0 => next char starts left-aligned ; 1 => next char starts mid-byte
writter_chars_left db 0         ; number of chars still to draw on the current line
writter_pixels_pending db 0      ; nb of pixels of the char being drawn (stashed across the print call)
writter_char_ptr dw 0             ; pointer to the next char code to draw in the current line
writter_cursor dw 0                ; screen address of the next char to draw

;; Prepares the state machine to (re)draw writter pagefrom scratch.
;; Must be called once before writter_draw_page_step is called repeatedly.
writter_draw_page_start
    ld hl, screen_table + WRITTER_GRID_START_ROW*16
    ld (writter_clear_ptr), hl
    ld a, WRITTER_GRID_HEIGHT*8
    ld (writter_clear_left), a
    ld a, WRITTER_STATE_CLEAR
    ld (writter_state), a
    ret

;; Performs one bounded unit of work towards drawing the page (clearing one
;; scanline, or drawing one char). Call repeatedly (e.g. once per frame) until
;; writter_state becomes WRITTER_STATE_DONE.
writter_draw_page_step
    ld a, (writter_state)
    cp WRITTER_STATE_CLEAR
    jr z, .clear_step
    cp WRITTER_STATE_DRAW
    jr z, .draw_step
    ret                                  ; nothing to do (done, or not started)

.clear_step
    ld hl, (writter_clear_ptr)
    ld a, (hl) : ld e, a
    inc hl
    ld a, (hl) : ld d, a                  ; de = scanline address to clear
    inc hl
    ld (writter_clear_ptr), hl

    ex de, hl                              ; hl = scanline address to clear
    ld b, SCREEN_WDITH
.clear_byte_loop
        ld a, (hl)
        and WRITTER_CLEAR_MASK
        ld (hl), a
        inc hl
        djnz .clear_byte_loop

    ld a, (writter_clear_left)
    dec a
    ld (writter_clear_left), a
    ret nz                                  ; more scanlines to clear on later calls

    ; clearing is done: set up the drawing phase, starting at the first line
    ld hl, WRITTER_PAGE0
    ld (writter_page_line_ptr), hl
    ld hl, screen_table + WRITTER_GRID_START_ROW*16
    ld (writter_page_table_ptr), hl
    ld a, WRITTER_GRID_HEIGHT
    ld (writter_page_rows_left), a
    call writter_start_line
    ld a, WRITTER_STATE_DRAW
    ld (writter_state), a
    ret

.draw_step
    ld a, (writter_chars_left)
    or a
    jr nz, .draw_one_char

        ; the current line is fully drawn: move to the next row (if any)
        call writter_advance_to_next_row
        ret z                                ; the whole page is now drawn
        call writter_start_line
        ret                                    ; the new line's first char is drawn on a later call

.draw_one_char
    ld hl, (writter_char_ptr)
    ld a, (hl) : inc hl
    ld (writter_char_ptr), hl                  ; a = char code of the next char

    add a, a                                     ; *2: each WRITTER_MAPPING entry is a word
    ld l, a : ld h, 0
    ld bc, WRITTER_MAPPING
    add hl, bc
    ld e, (hl) : inc hl : ld d, (hl)              ; de = address of the char data to draw

    ld a, (de)                                      ; a = nb of pixels of the char
    ld (writter_pixels_pending), a

    ld hl, (writter_cursor)                          ; hl = screen address to draw the char

    ld a, (writter_side)
    or a
    jr nz, .draw_right
        call print_one_char_left
        jr .drawn
.draw_right
        call print_one_char_right
.drawn

    ; move the cursor past the char and update the current side
    ; total = side + nb_pixels ; bytes advanced = total>>1 ; new side = total&1
    ld a, (writter_side)
    ld b, a
    ld a, (writter_pixels_pending)
    add a, b
    srl a                                            ; a = bytes to advance ; carry = new side
    ld c, a : ld b, 0
    ld hl, (writter_cursor)
    add hl, bc
    ld (writter_cursor), hl
    ld a, 0 : adc a, 0
    ld (writter_side), a

    ld a, (writter_chars_left)
    dec a
    ld (writter_chars_left), a
    ret


;; Advances writter_page_line_ptr/writter_page_table_ptr/writter_page_rows_left past
;; the line that was just drawn. Returns Z (and sets writter_state to
;; WRITTER_STATE_DONE) when the whole page has been drawn, NZ otherwise.
writter_advance_to_next_row
    ld hl, (writter_page_line_ptr)
    push hl
    inc hl : inc hl
    ld a, (hl)                         ; a = nb chars of the line just drawn
    pop hl
    add a, 3
    ld c, a : ld b, 0
    add hl, bc
    ld (writter_page_line_ptr), hl

    ld hl, (writter_page_table_ptr)
    ld bc, 16
    add hl, bc
    ld (writter_page_table_ptr), hl

    ld a, (writter_page_rows_left)
    dec a
    ld (writter_page_rows_left), a
    ret nz

    ld a, WRITTER_STATE_DONE
    ld (writter_state), a
    ret                                    ; Z is still set from the "dec a" above (ld does not affect flags)


;; Reads the line pointed to by writter_page_line_ptr/writter_page_table_ptr and sets
;; up writter_cursor/writter_side/writter_chars_left/writter_char_ptr to (re)start
;; drawing it one char at a time.
writter_start_line
    ld hl, (writter_page_table_ptr)
    ld a, (hl) : ld c, a
    inc hl
    ld a, (hl) : ld b, a                 ; bc = resolved row screen address

    ld hl, (writter_page_line_ptr)
    ld a, (hl) : inc hl                    ; a = nb bytes to skip
    ld e, a : ld d, 0
    push hl                                  ; save line ptr (points at nb_pixels_skip byte)
    ld h, b : ld l, c
    add hl, de
    ld (writter_cursor), hl
    pop hl                                      ; hl restored = line ptr

    ld a, (hl) : inc hl                    ; a = nb pixels to skip (0 or 1)
    ld (writter_side), a

    ld a, (hl) : inc hl                      ; a = nb chars in the line
    ld (writter_chars_left), a

    ld (writter_char_ptr), hl                   ; hl now points at the first char code
    ret


    macro PRINT_ONE_CHAR_GENERATOR(direction)
    ;; Draw the given char on screen at the given position
    ;; Input
    ;; - hl = address of the screen to draw the char
    ;; - de = address of the char data to draw (nb bits + the 8 bytes)
print_one_char_{direction}
        ld a, (de) : inc de      ; get the number of pixels in the character
                        ; store the number of pixels in b

        ld b, WRITTER_CHAR_HEIGHT
    .loop
            push bc, hl, af
                ; draw one line BUT do not change the screen address
                ; also keep the counter number
                call draw_pixel_line_start_{direction}
            pop af, hl
            or a : ld bc, 0x800
            add hl, bc
            pop bc
            djnz .loop
        ret
    endm

    PRINT_ONE_CHAR_GENERATOR(left)
    PRINT_ONE_CHAR_GENERATOR(right)


    macro INIT_CHAR_WRITTER
        ld bc, WRITTER_LEFT_DRAW_MASK*256+WRITTER_RIGHT_DRAW_MASK ; need to swap B and C for even start
        ex af, af'
            ld a, (de) : inc de  ; get the next line of pixels
            exx 
                ld c, a
            exx
        ex af, af'
    endm


; we skip the very first left pixel of the char to draw.
; so we handle it specificaly. Afterwhise, e use the normal rendering
; XXX We assume there is at least 2 pixels. In case of 1 pixel, it will fail
draw_pixel_line_start_right

    INIT_CHAR_WRITTER()

    ; af = number of pixels to draw
    ; c' = stream of bits to draw (read from right to left and drawn from left to right)
 
    dec a ; decrement number of available bits unconditionnally
    ex af, af'
        ld a, (hl) ; read current byte from the screen
        ; handle 1st pixel
        exx
            rr c  ; Set left bit in carry
        exx

        jr nc, .continue_after_pixel2
.draw_pixel2
        or c                    ; add current pixel
.continue_after_pixel2
        ld (hl), a : inc hl ; save the result and move to next byte   
    ex af,af'
    jr draw_pixel_line_start_left.width_loop

; Input
; HL = address of the screen to draw the char
; DE = address of the char data to draw (nb bits + the 8 bytes)
; A = number of pixels to draw <= 8
draw_pixel_line_start_left
    INIT_CHAR_WRITTER()

    ; af = number of pixels to draw
    ; c' = stream of bits to draw (read from right to left and drawn from left to right)


; draw pixel per pixel from the left of the char to the right of the char
; A = number of pixels to draw <= 8
; C' = current state of the line
; B, C => drawing pixel masks (left, right)
.width_loop ; loop over the bytes
    ex af, af'
        ld a, (hl)               ; read current byte from the screen
        and WRITTER_CLEAR_MASK  ; remove former writter pixels

        ; handle 1st pixel
        exx
            rr c  ; Set left bit in carry
        exx

        ; handle the pixel drawing
        jr nc, .continue_after_pixel1
.draw_pixel1
        or b                    ; add current pixel
.continue_after_pixel1

        ; check if we have fished after this first pixel
        ex af, af'
    dec a
    jr z, .leave_after_left_pixel   ;  leave if all pixels have been drawn
    ex af, af'

        ; HL <= screen address
        ; A <= current value of the next byte to draw (with left pixel drawn if any, right pixel absent)
        exx
            rr c  ; Rotate right through carry to process the next pixel
        exx
        jr nc, .contnue_after_pixel2
.draw_pixel2
        or c      ; add current pixel
.contnue_after_pixel2
        ld (hl), a  ; save the current byte to the screen
        inc hl        ; move to the next byte in the screen

        ex af, af'
    dec a
    jr nz, .width_loop ; loop while we can
    ret ; leave otherwhise
.leave_after_left_pixel
    ex af, af'
    ld (hl), a
    ret



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
    macro WRITTER_CREATE_CHAR(symb, line0, line1, line2, line3, line4, line5, line6, line7)
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

writter_char_{symb}:
.nb_pixels db CURRENT_CHAR_LENGTH
        db writter_string_to_bitvalues({line0})
        db writter_string_to_bitvalues({line1})
        db writter_string_to_bitvalues({line2})
        db writter_string_to_bitvalues({line3})
        db writter_string_to_bitvalues({line4})
        db writter_string_to_bitvalues({line5})
        db writter_string_to_bitvalues({line6})
        db writter_string_to_bitvalues({line7})

writter_char_{symb}_length equ CURRENT_CHAR_LENGTH
    endm


    ;; Generate the entry table for the given letter
    macro WRITTER_MAPPING_ENTRY char
        @letter={char}
        dw writter_char_{@letter}
    endm


    ;; Macro to generate the table that maps the writter chars to their data.
    macro WRITTER_MAPPING_GENERATE chars
writter_complete_charset = " "
    
        repeat string_len({chars}), i, 0
            writter_complete_charset = string_concat(writter_complete_charset, string_get({chars}, {i}))
        endrepeat

        print "WRITTER CHARSET", writter_complete_charset
        charset writter_complete_charset, 0

        dw writter_char_sp
        repeat string_len({chars}), i, 0
            WRITTER_MAPPING_ENTRY({eval}string_get({chars}, {i})) 
        endrepeat
    endm



    ;; A line is shown horizontally centered and is encoded this way
    ;; - Number of bytes to skip in the line (1 byte)
    ;; - Number of pixels to skip in the line (0 or 1) (1 byte)
    ;; - Number of chars in the line (1 byte)
    ;; - For each char its code (1 byte/char, mapped through the writter charset, see WRITTER_MAPPING_GENERATE)
    macro WRITTER_ENCODE_LINE content
        ; Compute the total number of pixels in the string
        CURRENT_TOTAL_PIXELS_SIZE = 0
        repeat string_len({content}), i, 0
            current_char = string_get({content}, {i})
            if current_char == ' '
                current_char = 'sp'
            endif
            CURRENT_TOTAL_PIXELS_SIZE += writter_char_{current_char}_length
        endrepeat

        assert CURRENT_TOTAL_PIXELS_SIZE <= WRITTER_GRID_WIDTH_PIXELS, "Line is too long for the writter grid"
        ; centering offset: half of the unused pixels of the grid
        CURRENT_SKIP_PIXELS_SIZE = (WRITTER_GRID_WIDTH_PIXELS - CURRENT_TOTAL_PIXELS_SIZE) / 2
        db CURRENT_SKIP_PIXELS_SIZE>>1 ; nb bytes to skip
        db CURRENT_SKIP_PIXELS_SIZE&1  ; nb pixels to skip
        db string_len({content})       ; nb chars
        db {content}                    ; char codes, mapped through the currently active charset
    endm

    ;; A page is build with 10 lines.
    ;; Lines can be empty, but they must be present.
    ;; Each line is encoded with WRITTER_ENCODE_LINE
    ;; TODO here it would be better to modify basm to work with unamed arguments.
    ;;       this way we could work with a loop instead of hardcoding all cases
    macro WRITTER_ENCODE_PAGE line0, line1, line2, line3, line4, line5, line6, line7, line8, line9
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


; 8 pixels
WRITTER_CREATE_CHAR(
    a,
    "        ",
    "        ",
    " ####   ",
    "    ##  ",
    " #####  ",
    "##  ##  ",
    " ### ## ",
    "        "
)

; 7 pixels
WRITTER_CREATE_CHAR(
    r,
    "       ",
    "       ",
    "## ##  ",
    " ## ## ",
    " ##    ",
    " ##    ",
    "####   ",
    "       "
)

; 5 pixels
WRITTER_CREATE_CHAR(
    i,
    " ##  ",
    "     ",
    "###  ",
    " ##  ",
    " ##  ",
    " ##  ",
    "#### ",
    "     "
)


WRITTER_MAPPING
    WRITTER_MAPPING_GENERATE("ari")


WRITTER_PAGE0
    WRITTER_ENCODE_PAGE(
        "aaaaaaaaaaaaaaaaaaa",
        "rrrrrrrrrrrrrrrrrrr",
        "iiiiiiiiiiiiiiiiiii",
        "                   ",
        "ariariariariariariariari",
        "aaaa rrrr iiii",
        "aaaa rrrrr iiii",
        "aaaa rrrrrr iiii",
        "aaaa rrrrrrr iiii",
        "aaaa rrrrrrrr iiii"
    )

WRITTER_PAGE1
    WRITTER_ENCODE_PAGE(
        " a ",
        " r ",
        " i ",
        "                   ",
        "ariariariariariariariari",
        "aaaa rrrr iiii",
        "aaaa rrrrr iiii",
        "aaaa rrrrrr iiii",
        "aaaa rrrrrrr iiii",
        "aaaa rrrrrrrr iiii"
    )


WRITTER_PAGES
    dw WRITTER_PAGE0
    dw WRITTER_PAGE1
    dw 0

    ; background_palette
background_palette
    incbin "../../data/face0_cpc.pal"

    ; there is only one color for the writter
writter_palette
    db 0x4A


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


    ; screen
    org 0xc000
    incbin "../../data/face0_cpc.scr"