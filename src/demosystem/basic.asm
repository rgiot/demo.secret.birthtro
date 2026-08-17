;;; This file contains the various functions that could be useful to manipulate the basic input. Especially to retrieve parameters from the line typed by the user.
;;; To reduce the memory usage, functions are only assembled if used.
;;;
;;; Example:
;;;
;;; ```z80
;;; ; To be called one time to avoid search issues
;;; call ds_secure_basic_line
;;;
;;; ; Get the numeric value of the CRTC parameter (CRTC=2 for example)
;;; call ds_basic_get_crtc_selection
;;; call z, handle_crtc_detection
;;;
;;; ; Check the string value of the PART parameter (PART=INTRO for example)
;;; DS_BASIC_GET_PARAM("PART")
;;; ```



BASIC_input_area_for_lines_ EQU $ac8a

	ifused ds_basic_first_comment_char_address
;;
;; look for the first character of the first comment in the basic program line
;;
;; MODIFIED:
;;  -   A, DE
;;
;; RETURNS:
;;   - HL: address of the first character of the first comment in the basic program line
;;   - BC: the number of remaining bytes in the line
;;   - Z is set if comment found
ds_basic_first_comment_char_address
	ld hl, BASIC_input_area_for_lines_
	ld bc, 255
	ld a, "'"
	cpir

	ret nz

	push af
		ld de, BASIC_input_area_for_lines_ + 256
		ex de, hl
		or a : sbc hl, de
		ex hl, de
		ld bc, de
	pop af

	ret
	endif

	ifused ds_secure_basic_line
;; Ensure the rest of the line is compose of 0 to avoid mismatch of previous input
ds_secure_basic_line
	; search the end of string
	ld hl, BASIC_input_area_for_lines_
	ld bc, 255
	ld a, 0
	cpir

	; fill the rest of the line with 0
	ld de, hl : dec hl
	ldir

	ret
	endif

	ifused ds_basic_get_crtc_selection
;;
;; Look for the crtc version requested by the user in the basic program line
;; post condition:
;;   Z flag set if found
;;   - A: crtc version (0-4)
ds_basic_get_crtc_selection

	ld hl, ds_basic_crtc_keyword.start
	ld a, ds_basic_crtc_keyword.length
	jr ds_basic_get_integer_param

ds_basic_crtc_keyword
.start
	db "CRTC="; upper case mandatory
.length equ $ - .start

	endif


	ifused ds_basic_get_integer_param
;;
;; Search the named parameter in the basic program line and retrieve its integer value
;; pre condition
;; - HL: address of the first character to search from
;; - A: length of the screen
;; post condition
;; Z flag set if an integer parameter is found
;; A: integer parameter value if any
ds_basic_get_integer_param

	; store the searched string info
	ld (ds_search_end_of_substring.searched_string_length), a
	ld (ds_search_end_of_substring.searched_string_address), hl

	; retreive the address of the first comment char
	call ds_basic_first_comment_char_address
	ret nz

	; really do the search
	call ds_search_end_of_substring
	ret nz

.found
	; retrieve the crtc version
	;inc hl => no need to inc as we are just after the '='
	ld a, (hl)
	sub '0'
    
	; ensure Z flag is set
	ld b, a
	xor a : or a
	ld a, b
	ret
	endif

	ifused ds_search_end_of_substring
;;
; case insensitive search for a substring in a memory area
;; Prerequisites:
;;   - HL: address of the first character to search from
;;     .searched_string_length: length of the string to search
;;     .searched_string: the string to search
;;   - BC number of bytes to search in (<256)
;; Postcondition:
;;  - HL address of the first character after the searched string if found
;;  - Z is set if found
ds_search_end_of_substring
	ld (.starting_search_address), hl
	;; Search the very first letter of the searched string
.search_first_letter
	ld hl, (.starting_search_address)  ; retreive the address where to start reading
	ld de, (.searched_string_address)
	ld b, c 
	ld a, (de)      ; get the first char to search
	ld c, a
.first_letter_loop
		ld a, (hl) : inc hl
		call ds_ensure_upper_case
		cp c
		jr z, .found_first_letter
	djnz .first_letter_loop
	ret; NZ set
.found_first_letter
	ld (.starting_search_address), hl  ; we will start with this address next time

	; check the next letters
	push bc
		ld a, (.searched_string_length)
		dec a ; remaining letters to check
		ld b, a
.remaining_loop
			inc de ; next char to compare
			ld a, (de) : ld c, a

			ld a, (hl)
			call ds_ensure_upper_case

			cp c
			jr nz, .need_to_restart ; not matching, search again from the beinning of keyword
			inc hl ; move in memory search space
		djnz .remaining_loop
.found
	pop bc
	ret


.need_to_restart
	pop bc
	jr .search_first_letter


.searched_string_length
	db 0
.searched_string_address
	dw 0
.starting_search_address 
	dw 00

	endif


	ifused ds_ensure_upper_case
;;
; Prerequisit
; - A: character 
; Post condition
; - A: uppercase character
ds_ensure_upper_case
	cp 'a'-1
	jr c, .upper
	cp 'z'
	jr nc, .upper
	sub 'a' - 'A'
.upper
	ret
	endif