;;; This file contains the character control codes for the locomotive text display.
;;; Firmware is able to interpret these codes when they are sent to the text display.


;;
;;  No effect. Ignored. 
CHAR_CTRL_NUL equ 0

;;
;; Print the symbol given by the parameter value. This allows the symbols in the range 0 to 31 to be displayed. 
;; Parameter 0-255 value of the symbol to print
CHAR_CTRL_SOH equ 1
CHAR_CTRL_PRINT_SYMBOL equ CHAR_CTRL_SOH

;;  	Turn off text cursor.
CHAR_CTRL_STX equ 2
CHAR_CTRL_CURSOR_OFF equ CHAR_CTRL_STX

;;  	Turn on text cursor. 
CHAR_CTRL_ETX equ 3
CHAR_CTRL_CURSOR_ON equ CHAR_CTRL_ETX

;;
;;  	Set screen mode.
;; Parameter 0,1,2
CHAR_CTRL_EOT equ 4
CHAR_CTRL_SCREEN_MODE equ CHAR_CTRL_EOT


;;
;; Send the parameter character to the graphics cursor. 
;; Parameter 0-255 value of the symbol to print
CHAR_CTRL_ENQ equ 5
CHAR_CTRL_PRINT_AT_GRAPHICS_CURSOR equ CHAR_CTRL_ENQ

;;
;; Enable Text Screen (see NAK) 
CHAR_CTRL_ACK equ 6
CHAR_CTRL_ENABLE_TEXT_SCREEN equ CHAR_CTRL_ACK

;;
;; Sound Bleeper. Note that this flushes the sound queues.
CHAR_CTRL_BEL equ 7

;;
;; Move cursor back one character
CHAR_CTRL_BS equ 8

;;
;; Move cursor forward one character.
CHAR_CTRL_TAB equ 9


;;
;;  	Move cursor down one line
CHAR_CTRL_LF equ 10


;;
;;  	Move cursor up one line
CHAR_CTRL_VT equ 11


;;
;; Clear text window and move cursor to top left corner.
CHAR_CTRL_FF equ 12
CHAR_CTRL_CLS equ CHAR_CTRL_FF


;;
;; Move cursor to left edge of window on current line.
CHAR_CTRL_CR equ 13


;;
;; Set Paper Ink
;; parameter paper 0-15
CHAR_CTRL_SO equ 14
CHAR_CTRL_PAPER equ CHAR_CTRL_SO


;;
;; Set Pen Ink
;; parameter pen 0-15
CHAR_CTRL_SI equ 15
CHAR_CTRL_PEN equ CHAR_CTRL_SI

;;
;;  	Delete current character
CHAR_CTRL_DLE equ 16


;;
;; Clear from left edge of window to, and including, the current character position
CHAR_CTRL_DC1 equ 17

;;
;; 	Clear from, and including, the current character position to the right edge of window.
CHAR_CTRL_DC2 equ 18

;;
;;  	Clear from start of window to, and including, the current character position.
CHAR_CTRL_DC3 equ 19

;;
;;  	Clear from, and including, the current character position to the end of window.
CHAR_CTRL_DC4 equ 20


;;
;; Turn off text screen. The screen will not react to anything sent to it until after an ACK is sent
CHAR_CTRL_NAK equ 21

;;
;; Set transparency 
;; Parameter (0 disables, 1 enables) 
CHAR_CTRL_SYN equ 22
CHAR_CTRL_TRANSPARENCY equ CHAR_CTRL_SYN
;;
;;  	Set graphics ink mode. 
;; Parameter 0 normal (overwrite), 1 XOR, 2 AND, 3 OR 
CHAR_CTRL_ETB equ 23
CHAR_CTRL_GRAPHICS_INK_MODE equ CHAR_CTRL_ETB

;;
;; Exchange Pen and Paper Inks, effectively applying the reverse video effect
CHAR_CTRL_CAN equ 24

;;
;; Set the matrix for user definable character. The first parameter specifies which character's matrix to set. The next eight specify the matrix.
CHAR_CTRL_EM equ 25
CHAR_CTRL_SYMBOL equ CHAR_CTRL_EM

;;
;; Set Window. The parameters specify left, right, top and bottom edges of the window.
;; Parameters 1-80, 1-80, 1-25, 1-25
CHAR_CTRL_SUB equ 26
CHAR_CTRL_WINDOW equ CHAR_CTRL_SUB


;;
;; No effect. Ignored. 
CHAR_CTRL_ESC equ 27

;;
;; Set Ink to a pair of colors. The first parameter specifies the Ink, the next two the required colors
;; Parameters 0-15, 0-31, 0-31
CHAR_CTRL_FS equ 28
CHAR_CTRL_INK equ CHAR_CTRL_FS

;;
;; Set Border to a pair of colors. Equivalent to a BORDER command. The two parameters specify the two colors.
;; Parameters 0-31, 0-31
CHAR_CTRL_GS equ 29
CHAR_CTRL_BORDER equ CHAR_CTRL_GS

;;
;; Move cursor to top left hand corner of window. 
CHAR_CTRL_RS equ 30


;;
;; Move cursor to the given position in the current window. The first parameter gives the column to move to, the second gives the line.
;; Parameters  	1-80, 1-25
CHAR_CTRL_US equ 31
CHAR_CTRL_LOCATE equ CHAR_CTRL_US


;; Generates list list of character control codes to select screen mode
function CHARS_CTRL_SCREEN_MODE m
	assert {m}>=0 && {m}<=2
	return [CHAR_CTRL_SCREEN_MODE, {m}]
endf

;; Generates list of character control codes to set ink colors
function CHARS_CTRL_PEN p, i1, i2
	return [CHAR_CTRL_PEN, {p}, {i1}, {i2}]
endf


;; Generates list of character control codes to set border colors
function CHARS_CTRL_BORDER  i1, i2
	assert {i1} >=0 && {i1} <= 31
	assert {i2} >=0 && {i2} <= 31
	return [CHAR_CTRL_BORDER, {i1}, {i2}]
endf

;; Generates list list of character control codes to select paper pen
function CHARS_CTRL_SELECT_PEN pen
	assert {pen} >= 0 && {pen} <= 15
	return [CHAR_CTRL_PEN, {pen}]
endf

;; Generates list list of character control codes to print a symbol
function CHARS_CTRL_PRINT_SYMBOL sym
	assert {sym} >= 0 && {sym}<=255
	return [CHAR_CTRL_SOH, {sym}]
endf

;; Generates list list of character control codes to locate the cursor
function CHARS_CTRL_LOCATE x, y
	return [CHAR_CTRL_LOCATE, {x}, {y}]
endf