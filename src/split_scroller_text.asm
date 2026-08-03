; Scroller text data : lower case correspond to IPM font and upper case to the nop resolution font
scroller_text
	db "this is art "
scroller_text2

	db "THIS IS ART "

	repeat 10
		db "this is art "
		db "THIS IS ART "
	endr


	db "tTtTtTtTtTtTtTtTtTtTt"
	db "hHhHhHhHhHhHhHhHhHhHhH"
	db "iIiIiIiIiIiIiIiIiIiIiI"
	db "sSsSsSsSsSsSsSsSsSsSsS"
	db " "
	db "iIiIiIiIiIiIiIiIiIiIiI"
	db "sSsSsSsSsSsSsSsSsSsSsS"
	db " "
	db "aAaAaAaAaAaAaAaAaAaAaA"
	db "rRrRrRrRrRrRrRrRrRrRrR"
	db "tTtTtTtTtTtTtTtTtTtTtT"
	db "  "

		db 255 ; XXX mandatory end value