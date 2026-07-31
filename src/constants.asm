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
;; The number of times a routine is dulicated
SCROLLER_BLOC_HEIGHT equ 8



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

