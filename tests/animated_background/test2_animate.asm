;; June 2026
;; Krusty/Benediction
;; Start to work on the background display.
;; Nothing fancy here : there is a 4 colors background.
;;                      idealy it will have some animated parts


SPRITE0_LOCATION equ 0xc000 + 96*2 + 0x800*5 + 12
SPRITE0_WIDTH equ 13
SPRITE0_HEIGHT equ 46


	org 0x4000

init
	run $
	di

        ; set up the screen

		ld hl, 0xc9fb : ld (0x38), hl
		ld bc, 0xbc00 + 1 : out (c), c : ld bc, 0xbd00 + 96/2 : out (c), c
		ld bc, 0xbc00 + 2 : out (c), c : ld bc, 0xbd00 + 50  : out (c), c
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

    ei

frame
	call secure_vsync
	call secure_vsync
	call secure_vsync
	call secure_vsync
    halt : halt : halt : halt
    ld bc, 0x7f00 : out (c), c : ld bc, 0x7f40 : out (c), c
    call replace_background_sprite_0_0
    ld bc, 0x7f00 : out (c), c : ld bc, 0x7f54 : out (c), c




    call secure_vsync
	call secure_vsync
	call secure_vsync
	call secure_vsync
    halt : halt : halt : halt
    ld bc, 0x7f00 : out (c), c : ld bc, 0x7f40 : out (c), c
    call replace_background_sprite_0_1
    ld bc, 0x7f00 : out (c), c : ld bc, 0x7f54 : out (c), c


   	call secure_vsync
	call secure_vsync
	call secure_vsync
	call secure_vsync
    halt : halt : halt : halt
    ld bc, 0x7f00 : out (c), c : ld bc, 0x7f40 : out (c), c
    call replace_background_sprite_0_2
    ld bc, 0x7f00 : out (c), c : ld bc, 0x7f54 : out (c), c

    jp frame


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


    ;; Create a new LRU of size {size}
    function lru_new size
        item = list_new(2, -1) ; value, timestamp
        lru = list_new({size}, item)
        return lru
    endfunction

    ;; Get the index of the value in the lru list, or -1 if not found
    ;; return -1 if not found, else the index of the value in the lru list
    ;; it is important that the caller update the lru list if the value is found, to update the timestamp to 0
    function lru_get_slot lru, value
        l = {lru}
        print l
        repeat list_len(l), i, 0
            item = list_get(l, {i})
            if list_get(item, 0) == {value}
                return {i}
            endif
        endrepeat
        return -1
    endfunction


    function lru_is_full, lru
        repeat list_len({lru}), i, 0
            item = list_get({lru}, {i})
            if list_get({item}, 1) == -1
                return false
            endif
        endrepeat
        return true
    endfunction

    function lru_free_slot, lru
        repeat list_len({lru}), i, 0
            item = list_get({lru}, {i})
            if list_get(item, 1) == -1
                return {i}
            endif
        endrepeat
        return -1
    endfunction

    ;; return the index of the oldest item in the lru list
    function lru_oldest_slot, lru
        l = {lru}
        oldest_index = -1
        oldest_timestamp = -1
        repeat list_len(l), i, 0
            item = list_get(l, {i})
            timestamp = list_get(item, 1)
            if oldest_index == -1 || timestamp > oldest_timestamp
                oldest_index = {i}
                oldest_timestamp = timestamp
            endif
        endrepeat
        return oldest_index
    endfunction

    ;; Remove the item in the lru list at the given slot
    function lru_remove_slot, lru, slot
        l = {lru}
        l = list_set(l, {slot}, [-1, -1])
        return l
    endfunction

    ;; Either add the new element or update the timestamp of an existing element in the lru list
    function lru_put, lru, value
        l = {lru}
        value = {value}
        print "BEFORE", l

        value_slot = lru_get_slot(l, value)
        if value_slot != -1
            ; the value is already in the lru list, we just need to update its timestamp to 0
            item = list_get(l, value_slot)
            item = [list_get(item, 0), 0]
            l = list_set(l, value_slot, item)
            inserted_slot = value_slot
        else
            ; Here we add the value
            free_slot = lru_free_slot(l)
            if free_slot != -1
                ; set the new value
                item = [value, 0]
                l = list_set(l, free_slot, item)
                inserted_slot = free_slot

            else
                ; find the item with the highest timestamp
                oldest_slot = lru_oldest_slot(l)
                item = [value, 0]
                l = list_set(l, oldest_slot, item)
                inserted_slot = oldest_slot
            endif
        endif


        ; increase the timestamp of all other items
        repeat list_len(l), i, 0
            if {i} != inserted_slot
                item = list_get(l, {i})
                if list_get(item, 1) != -1
                    item = [list_get(item, 0), list_get(item, 1) + 1]
                    l = list_set(l, {i}, item)
                endif
            endif
        endrepeat

        print "AFTER", l
        return l
    endfunction


    ;; To speed up spirtes drwing, we want dedicated macros
    macro GENERATE_SPRITE_DISPLAY_CODE sprite_nb, step_nb
replace_background_sprite_{sprite_nb}_{step_nb}
        current_sprite_location = SPRITE{sprite_nb}_LOCATION 
        ld hl, current_sprite_location

        ; XXX There is a bug in basm when using @lru instead of current_lru => the lru is wrongly altered
        current_lru = lru_new(3)  ; LRU for A, D, E registers

        repeat SPRITE{sprite_nb}_HEIGHT, y, 0
            push hl
                repeat SPRITE{sprite_nb}_WIDTH, x, 0

                    @current_value = list_get(SPRITE{sprite_nb}_STEP{step_nb}_CONTENT, {y} * SPRITE{sprite_nb}_WIDTH + {x}) 
                    print "current lru: ", current_lru, " current y: ", {y}, " current x: ", {x}, " current value: ", @current_value

                    ; we do not cler LRU cache when value is too rarely used, to avoid thrashing the cache
                    @current_value_used_few_times = list_get(SPRITE{sprite_nb}_STEP{step_nb}_HISTOGRAM, @current_value) <=2
                    if @current_value_used_few_times
                        print "Scarce value, writing directly to memory: ", @current_value
                        ; if the value is used few times, we do not use the LRU cache, we just write it directly
                        ld (hl), @current_value
                    else
                        print "Value is used more than twice, using LRU cache: ", @current_value
                        ; check if the value is in the LRU cache

                        @slot = lru_get_slot(current_lru, @current_value)
                        if @slot == -1
                            ; the value is in the LRU cache, we can use it directly
                            ; we need to update the LRU cache to mark this value as recently used
                            current_lru = lru_put(current_lru, @current_value)
                            @slot = lru_get_slot(current_lru, @current_value)
                            print "added value to the LRU cache, new slot is ", @slot, " new LRU cache is ", current_lru
                            ; update the corresponding register
                            switch @slot
                                case 0
                                    ld a, @current_value
                                    break
                                case 1
                                    ld d, @current_value
                                    break
                                case 2
                                    ld e, @current_value
                                    break
                                default
                                    fail "Invalid slot number"
                            endswitch
                        else
                            print "value is in slot ", @slot, " of the LRU cache"
                            current_lru = lru_put(current_lru, @current_value)
                            print "update couneter for value ", @current_value, " in slot ", @slot, " of the LRU cache ", current_lru
                        endif

                        ; write in memory the proper value from the LRU cache
                        switch @slot
                            case 0
                                ld (hl), a
                                break   
                            case 1
                                ld (hl), d
                                break
                            case 2
                                ld (hl), e
                                break
                            default
                                fail "Invalid slot number"
                        endswitch

                        ; in any case we need to update the counters

                    endif


                    print "current_sprite_location=",current_sprite_location 
                    if low(current_sprite_location) != 255
                        inc l
                    else
                        inc hl
                    endif
                    current_sprite_location = current_sprite_location + 1
                endrepeat

            pop hl
            call bc26_hl
            current_sprite_location = current_sprite_location - SPRITE{sprite_nb}_WIDTH
            current_sprite_location = compute_next_line(current_sprite_location)
            current_lru = lru_remove_slot(current_lru, 0) ; a has been used in bc26
        endrepeat
        ret

    endm



    ;; Get the histogram of bytes
    function histogram bytes
        histo = list_new(256, 0)
        iterate val in {bytes}
            histo = list_set(histo, {val}, list_get(histo, {val}) + 1)
        enditerate
        return histo
    endfunction



SPRITE0_STEP0_CONTENT equ load("../../data/face0_eye0.spr")
SPRITE0_STEP1_CONTENT equ load("../../data/face0_eye1.spr")
SPRITE0_STEP2_CONTENT equ load("../../data/face0_eye2.spr")

SPRITE0_STEP0_HISTOGRAM equ histogram(SPRITE0_STEP0_CONTENT)
SPRITE0_STEP1_HISTOGRAM equ histogram(SPRITE0_STEP1_CONTENT)        
SPRITE0_STEP2_HISTOGRAM equ histogram(SPRITE0_STEP2_CONTENT)

SPRITE0_STEP0_ARGSORT equ list_argsort(SPRITE0_STEP0_HISTOGRAM)
SPRITE0_STEP1_ARGSORT equ list_argsort(SPRITE0_STEP1_HISTOGRAM)
SPRITE0_STEP2_ARGSORT equ list_argsort(SPRITE0_STEP2_HISTOGRAM)

print "SPRITE0_STEP0_HISTOGRAM : ", SPRITE0_STEP0_HISTOGRAM
print "SPRITE0_STEP0_ARGSORT : ", SPRITE0_STEP0_ARGSORT

print "SPRITE0_STEP1_HISTOGRAM : ", SPRITE0_STEP1_HISTOGRAM
print "SPRITE0_STEP1_ARGSORT : ", SPRITE0_STEP1_ARGSORT

print "SPRITE0_STEP2_HISTOGRAM : ", SPRITE0_STEP2_HISTOGRAM
print "SPRITE0_STEP2_ARGSORT : ", SPRITE0_STEP2_ARGSORT





;; Draw a new sprite at a given position on the screen.
;; This is not trivial : we cannot copy the sprite directly b"cause we are working using bitplanes.
;; so bit0 and bit 1 change not the others (TODO really do that, it is not the case ATM)
;; TODO optiize code for a specific size of sprite
;; TODO really use the bit stuff
;; Input
;; : HL : position of the sprite in memory (sprite data)
GENERATE_SPRITE_DISPLAY_CODE(0, 0)
GENERATE_SPRITE_DISPLAY_CODE(0, 1)
GENERATE_SPRITE_DISPLAY_CODE(0, 2)


; input: DE: scree address
; modified: DE, A, BC
bc26
    ld a, d
    add 8
    ld d, a
    ret nc
    ld bc, 0xc000 + 96
    ex de, hl
        add hl, bc
    ex de, hl
    ret


    ;; bc26 but in assembler
    function compute_next_line, current_sprite_location

        h = high({current_sprite_location})
        l = low({current_sprite_location})

        h = h + 8
        if h > 0xff
            h = h - 0x100
            l = l + 96
        endif

        return 256*h + l 
    endfunction


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





    ; palette
palette
    incbin "../../data/face0_cpc.pal"

    ; screen
    org 0xc000
    incbin "../../data/face0_cpc.scr"