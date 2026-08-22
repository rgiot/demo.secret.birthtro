	;; We do not want to display complete sprite, but sprite delta between a source sprite and a destintion sprite

	; Use a LRU cache to handle the bytes to draw

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
    jp $
        current_sprite_location = SPRITE{sprite_nb}_LOCATION 
        ld hl, current_sprite_location

        ; XXX There is a bug in basm when using @lru instead of current_lru => the lru is wrongly altered
        current_lru = lru_new(4)  ; LRU for B, C, D, E registers

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
                                    ld b, @current_value
                                    break
                                case 1
                                    ld c, @current_value
                                    break
                                case 2
                                    ld d, @current_value
                                    break
                                case 3
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


    ;; bc26 but in assembler
    function compute_next_line, current_sprite_location

        h = high({current_sprite_location})
        l = low({current_sprite_location})

        h = h + 8
        if h > 0xff
            h = h - 0x100
			l = l + 96
			if l > 0xff
				l = l - 0x100
				h = h + 1
			endif
			h = h + 0xC0
        endif

        return 256*h + l 
    endfunction


add_to_change equ duration(ld a, 0) + duration(add l) + duration(ld l, a)


;;
;; The animation cannot run if the scroll is too low because it takes too much tim
cancel_animation_0_if_needed
    ld a, (demo_frame_run.wait_lines-1)
    cp ANIMATION_SCROLLER_POSITION_THRESHOLD
    ret c

    ; we go back one step in the animation
    ld hl, (replace_background_sprite_0.ptr)
    dec hl : dec hl
    ld (replace_background_sprite_0.ptr), hl

    pop hl ; we consume the return address of the drwining routine to really leave
    ret


    ;; To speed up spirtes drwing, we want dedicated macros
    macro GENERATE_SPRITE_DISPLAY_CODE_DELTA sprite_nb, src, dst
; Replace the bytes to go from sprite {src} to sprite {dst} for sprite number {sprite_nb}
replace_background_sprite_{sprite_nb}_{src}_{dst}

        call cancel_animation_0_if_needed




        current_sprite_location = SPRITE{sprite_nb}_LOCATION 

        ; XXX There is a bug in basm when using @lru instead of current_lru => the lru is wrongly altered
        current_lru = lru_new(3)  ; LRU for C, D, E registers
		current_cursor_x = 0
		current_cursor_y = 0
		current_cursor_location = current_sprite_location
		current_sprite_location_in_registers = false


		ld b, SPECTRAL_SPRITE_DRAW_MASK_BOTH_POS | WRITTER_DRAW_MASK

        repeat SPRITE{sprite_nb}_HEIGHT, y, 0
           ; push hl
		   previous_sprite_location = current_sprite_location
                repeat SPRITE{sprite_nb}_WIDTH, x, 0

                    @current_value_src = list_get(SPRITE{sprite_nb}_STEP{src}_CONTENT, {y} * SPRITE{sprite_nb}_WIDTH + {x}) 
                    @current_value_dst = list_get(SPRITE{sprite_nb}_STEP{dst}_CONTENT, {y} * SPRITE{sprite_nb}_WIDTH + {x}) 
					@to_be_displayed = @current_value_src != @current_value_dst

					if @to_be_displayed

						if current_sprite_location_in_registers
							; move at the right place
							assert current_cursor_y == {y}, "current_cursor_y is not equal to y"
							assert current_cursor_x <= {x}, "current_cursor_x is not less than or equal to x"
							

							delta_x = {x} - current_cursor_x
							if delta_x > add_to_change && (low(current_cursor_location)+delta_x <= 255)
								ld a, delta_x
								add l
								ld l, a
								current_cursor_location = current_sprite_location
								current_cursor_x = {x}
							else
								
								while current_cursor_x < {x}
									if low(current_cursor_location) != 255
										inc l
									else
										inc hl
									endif
									current_cursor_location = current_cursor_location + 1
									current_cursor_x = current_cursor_x + 1
								endwhile
							endif
						else
							ld hl, current_sprite_location
							current_cursor_location = current_sprite_location
							current_cursor_x = {x}
							current_sprite_location_in_registers = true
						endif


						@current_value = @current_value_dst
						print "current lru: ", current_lru, " current y: ", {y}, " current x: ", {x}, " current value: ", @current_value

						; read screen and remove former background
						ld a, (hl) : and b

						; we do not cler LRU cache when value is too rarely used, to avoid thrashing the cache
						@current_value_used_few_times = list_get(SPRITE{sprite_nb}_FROM{src}_TO{dst}_HISTOGRAM, @current_value) <=2
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
										ld c, @current_value
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
									or c
									break   
								case 1
									or d
									break
								case 2
									or e
									break
								default
									fail "Invalid slot number"
							endswitch

							; in any case we need to update the counters

						endif

						ld (hl), a

					endif

   ;                 print "current_sprite_location=",current_sprite_location 
   ;                 if low(current_sprite_location) != 255
   ;                     inc l
   ;                 else
   ;                     inc hl
   ;                 endif
;					current_cursor_x = current_cursor_x + 1
                    current_sprite_location = current_sprite_location + 1
                endrepeat

            ;pop hl

            ;call bc26_hl
            current_sprite_location = previous_sprite_location ; go back to the beginning of the line
            current_sprite_location = compute_next_line(current_sprite_location) ; compute the next line

			print {hex}current_sprite_location
			assert current_sprite_location >= 0xc000

			current_sprite_location_in_registers = false


			current_cursor_location = current_sprite_location
			current_cursor_y = current_cursor_y + 1
			current_cursor_x = 0
            ;current_lru = lru_remove_slot(current_lru, 0) ; a has been used in bc26
        endrepeat
        ret

		

    endm



    ;; Get the histogram of bytes for a given image
	;; not used anymore
    function histogram bytes
        histo = list_new(256, 0)
        iterate val in {bytes}
            histo = list_set(histo, {val}, list_get(histo, {val}) + 1)
        enditerate
        return histo
    endfunction


	;; Get the histogram of bytes for a change from one image to another one
	function histogram_delta bytes_src, bytes_dest
		histo = list_new(256, 0)
		repeat list_len({bytes_src}), i, 0
			val1 = list_get({bytes_src}, {i})
			val2 = list_get({bytes_dest}, {i})
			; add the byte only if needed
			if val1 != val2
				histo = list_set(histo, val2, list_get(histo, val2) + 1)
			endif
		endrepeat
		return histo
	endfunction


; Generate sprites data and code

;SPRITE0_STEP0_CONTENT equ load("../data/face0_eye0.spr")
;SPRITE0_STEP1_CONTENT equ load("../data/face0_eye1.spr")
;SPRITE0_STEP2_CONTENT equ load("../data/face0_eye2.spr")

	; load the sprites
	repeat SPRITE0_NB_FRAMES, frame, 0
SPRITE0_STEP{{frame}}_CONTENT equ load(LEFT_EYE{{frame}}_SPR)
	endrepeat

	; compute the histogram of each sprite
	repeat SPRITE0_NB_FRAMES, src, 0
		repeat SPRITE0_NB_FRAMES, dest, 0
			; We generate only consecutive sprites for the animation purposes
			if {dest}!={src} && (({dest}=={src}+1) || ({src}=={dest}+1))
				SPRITE0_FROM{{src}}_TO{{dest}}_HISTOGRAM equ histogram_delta(SPRITE0_STEP{{src}}_CONTENT, SPRITE0_STEP{{dest}}_CONTENT)
				SPRITE0_FROM{{src}}_TO{{dest}}_ARGSORT equ list_argsort(SPRITE0_FROM{{src}}_TO{{dest}}_HISTOGRAM)

				print "histogram of sprite ", {src}, " to sprite ", {dest}, " is ", SPRITE0_FROM{{src}}_TO{{dest}}_HISTOGRAM
				print "argsort of sprite ", {src}, " to sprite ", {dest}, " is ", SPRITE0_FROM{{src}}_TO{{dest}}_ARGSORT

				GENERATE_SPRITE_DISPLAY_CODE_DELTA(0, {src}, {dest}) ; only difference between the two sprites is shown
			endif

		endrepeat
	endrepeat



NB_REPEATED_FRAMES_IN_ANIMATION equ 10
animation_do_nothing ret
macro ANIMATION_STEP routine
	dw {routine}
	repeat NB_REPEATED_FRAMES_IN_ANIMATION-1, i, 0
		dw animation_do_nothing
	endrepeat
endm

reset_background_sprite_0
	ld hl, replace_background_sprite_0.table
	ld (replace_background_sprite_0.ptr), hl


	ret

replace_background_sprite_0
	; Get the appropriate routine
	ld hl, .table : .ptr equ $-2
	ld e, (hl) : inc hl : ld d, (hl)
	ld a, e : or d

	jr z, .over ; animation is played just one  time
.not_end
	inc hl
	ld (.ptr), hl


	; and call it
	ex de, hl
	di
	call call_hl
	ei
	ret
.over
    BREAKPOINT : ld a, ANIMATION_STATE_FINISHED
    ld (animation_state), a
    ret

.table
		ANIMATION_STEP(replace_background_sprite_0_0_1)
		ANIMATION_STEP(replace_background_sprite_0_1_2)
		ANIMATION_STEP(replace_background_sprite_0_2_1)
		ANIMATION_STEP(replace_background_sprite_0_1_0)
	dw 0


    if false
    // seems to not work ATM
enum ANIMATION_STATE
    PLAYING
    FINISHED
endenum
    else
    ANIMATION_STATE_PLAYING equ 0
    ANIMATION_STATE_FINISHED equ 1
    endif

