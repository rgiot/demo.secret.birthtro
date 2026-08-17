	;; Search a given parameter in the basic program line
	;; Input
	;;  - param: the parameter to search (as a string)
	macro DS_BASIC_GET_PARAM param
	    jr @execute
@param 
	defb {param}
	defb '='
@execute
		; setup the parameters to search the string
		ld hl, @param
		ld a, string_len({param}) + 1 ; +1 for the '='
		ld (ds_search_end_of_substring.searched_string_length), a
		ld (ds_search_end_of_substring.searched_string_address), hl

		; skip process if there is no comment in the basic prompt
		call ds_basic_first_comment_char_address
		ret nz

		call ds_search_end_of_substring
	endm


	;; Check if a parameter is equal to a given value.
	;; ATTENTION! This version does in fact a prefix search, there is no
	;; notion of the end of the parameter value (like a space or comment char).
	;; 
	;;
	;; Precondition
	;;  - HL: address of the first character after the '=' of the parameter
	;;    The string is at max 255 characters long.
	;; Input
	;;  - value: the value to compare to (as a string)
	;; Modified values
	;;  - BC
	;; Postcondition
	;;  - Z flag set if the parameter value is equal to the given value
	;;  -HL points to the next character after the compared value

	macro DS_BASIC_PARAM_IS value
		jr @execute
@value
		defb {value}
@execute

		ld de, @value
		ld a, string_len({value})
		ld (ds_search_end_of_substring.searched_string_length), a
		ld (ds_search_end_of_substring.searched_string_address), de

		ld bc, 255 ; TODO check if we can provide a value
		call ds_search_end_of_substring
	endm