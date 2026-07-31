;; Krusty/Benediction, july 2026
;;
;; List of constants used in the demo. Avoid at maximum their use elswhere



;;;;;;;; Screen related constants ;;;;;;;

SCREEN_WIDTH equ 96
SCREEN_WIDTHS_WORD equ SCREEN_WIDTH/2
SCREEN_HEIGHT_CHARS equ 21

;;;;;;;; Pixels related constants ;;;;;;;;


MODE0_LEFT_PIXEL_BIT0_POS equ 7
MODE0_LEFT_PIXEL_BIT1_POS equ 3
MODE0_LEFT_PIXEL_BIT2_POS equ 5
MODE0_LEFT_PIXEL_BIT3_POS equ 1

MODE0_RIGHT_PIXEL_BIT0_POS equ 6
MODE0_RIGHT_PIXEL_BIT1_POS equ 2
MODE0_RIGHT_PIXEL_BIT2_POS equ 4
MODE0_RIGHT_PIXEL_BIT3_POS equ 0



;;;;;;;; Scroller related constants ;;;;;;;
SCROLLER_NB_VERTICAL_BLOCS equ 8
;; The number of times a routine is duplicated. The original scroll is not too tall
SCROLLER_BLOC_HEIGHT equ 6

SCROLLER_SINE equ [36, 36, 37, 38, 39, 40, 41, 41, 42, 43, 44, 45, 46, 46, 47, 48, 49, 50, 50, 51, 52, 53, 53, 54, 55, 56, 56, 57, 58, 58, 59, 60, 60, 61, 61, 62, 63, 63, 64, 64, 65, 65, 66, 66, 66, 67, 67, 67, 68, 68, 68, 69, 69, 69, 69, 70, 70, 70, 70, 70, 70, 70, 70, 70, 71, 70, 70, 70, 70, 70, 70, 70, 70, 70, 69, 69, 69, 69, 68, 68, 68, 67, 67, 67, 66, 66, 66, 65, 65, 64, 64, 63, 63, 62, 61, 61, 60, 60, 59, 58, 58, 57, 56, 56, 55, 54, 53, 53, 52, 51, 50, 50, 49, 48, 47, 46, 46, 45, 44, 43, 42, 41, 41, 40, 39, 38, 37, 36, 36, 35, 34, 33, 32, 31, 30, 30, 29, 28, 27, 26, 25, 25, 24, 23, 22, 21, 21, 20, 19, 18, 18, 17, 16, 15, 15, 14, 13, 13, 12, 11, 11, 10, 10, 9, 8, 8, 7, 7, 6, 6, 5, 5, 5, 4, 4, 4, 3, 3, 3, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5, 6, 6, 7, 7, 8, 8, 9, 10, 10, 11, 11, 12, 13, 13, 14, 15, 15, 16, 17, 18, 18, 19, 20, 21, 21, 22, 23, 24, 25, 25, 26, 27, 28, 29, 30, 30, 31, 32, 33, 34, 35]


;;;; Spectral sprites related constants ;;;;

SPECTRAL_PLAIN equ true ; Voxy's choice, but I'm sure it is a mistake

; spectral sprites uses bit 2
SPECTRAL_SPRITE_LEFT_BIT_POS equ  MODE0_LEFT_PIXEL_BIT2_POS      ; used for even lines
SPECTRAL_SPRITE_RIGHT_BIT_POS equ  MODE0_RIGHT_PIXEL_BIT2_POS    ; used for odd lines

SPECTRAL_SPRITE_DRAW_MASK_BOTH_POS equ (1 << SPECTRAL_SPRITE_LEFT_BIT_POS) | (1 << SPECTRAL_SPRITE_RIGHT_BIT_POS)
SPECTRAL_SPRITE_ERASE_MASK_BOTH_POS equ (~(SPECTRAL_SPRITE_DRAW_MASK_BOTH_POS)) & 0xff

SPECTRAL_SPRITE_WIDTH equ 22 ; more columns is too slow
SPECTRAL_SPRITE_HEIGHT equ 5

SPECTRAL_BLOC_HEIGHT equ 16
SPECTRAL_BLOC_WIDTH equ 4

SPECTRAL_DELTA_CURVE equ [4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 2, 4, 4, 4, 2, 4, 4, 2, 4, 4, 2, 4, 2, 4, 2, 4, 2, 4, 2, 4, 2, 2, 4, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 0, 2, 2, 2, 2, 2, 2, 2, 0, 2, 2, 2, 0, 2, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 0, 2, 0, 0, 2, 0, 0, 0, 2, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 2, 0, 0, 2, 0, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 2, 0, 2, 2, 2, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 4, 2, 2, 4, 2, 4, 2, 4, 2, 4, 2, 4, 2, 4, 4, 2, 4, 4, 2, 4, 4, 4, 2, 4, 4, 4, 4, 4, 2, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4]
SPECTRAL_CURVE_STEPX equ 3


SPECTRAL_START_LINE equ SCREEN_HEIGHT_CHARS*8/2 - SPECTRAL_BLOC_HEIGHT*SPECTRAL_SPRITE_HEIGHT/2 + 1
SPECTRAL_START_COLUMN equ 4
