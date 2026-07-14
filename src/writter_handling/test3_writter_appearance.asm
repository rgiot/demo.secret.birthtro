;; June, July 2026
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
WRITTER_GRID_HEIGHT_PIXELS equ WRITTER_GRID_HEIGHT*8

; the writter grid is shorter than the screen, so it is vertically centered
; by starting a few char lines below the top of the screen
; NB: this must stay a whole number of char lines (8 scanlines) since it is
;     used as a row index into screen_table - "/2" would yield a .5 result
;     for an odd difference and misalign every row lookup, hence the ">>1"
WRITTER_GRID_START_ROW equ (SCREEN_HEIGHT_CHARS - WRITTER_GRID_HEIGHT) >> 1

; once a page is fully drawn, it stays on screen this many frames before the
; next page (from WRITTER_PAGES) starts being drawn
WRITTER_PAGE_WAIT_FRAMES equ 200

WRITTER_TRANSITION_ATOMIC_UNIT_WIDTH_IN_PIXELS equ 4
WRITTER_TRANSITION_ATOMIC_UNIT_HEIGHT_IN_PIXELS equ 8
WRITTER_TRANSITION_TABLE0 equ [[58,32], [58,24], [56,32], [58,40], [56,24], [60,40], [56,40], [48,64], [60,32], [50,64], [58,16], [54,40], [62,40], [48,56], [46,64], [60,24], [52,64], [50,56], [46,56], [60,48], [56,16], [52,56], [54,48], [52,48], [54,32], [58,48], [62,32], [74,56], [62,48], [74,32], [54,64], [72,56], [60,16], [56,48], [52,40], [50,72], [76,56], [76,48], [48,72], [52,72], [54,56], [64,32], [74,64], [70,56], [64,40], [44,64], [74,48], [74,24], [46,72], [54,72], [76,40], [50,48], [74,40], [72,32], [72,64], [54,24], [48,48], [72,48], [64,48], [56,64], [62,24], [76,64], [70,48], [46,48], [76,32], [76,24], [66,32], [44,56], [60,56], [62,56], [64,56], [72,40], [56,56], [58,56], [22,32], [58,64], [56,72], [24,32], [68,56], [58,8], [72,24], [70,64], [60,64], [70,40], [62,64], [68,48], [56,8], [66,40], [64,24], [44,72], [22,40], [66,56], [66,48], [70,32], [54,16], [64,64], [68,32], [24,40], [78,48], [76,16], [62,16], [60,8], [68,40], [58,72], [78,56], [74,16], [52,32], [42,64], [66,24], [78,24], [56,0], [26,32], [78,40], [44,48], [54,0], [78,16], [76,72], [22,24], [42,56], [50,40], [20,32], [20,40], [74,72], [26,40], [24,24], [60,72], [54,8], [66,64], [78,64], [70,24], [62,72], [68,24], [18,40], [64,72], [16,40], [78,32], [68,64], [72,72], [62,8], [20,24], [72,16], [16,48], [58,0], [42,48], [26,24], [48,40], [46,40], [22,48], [80,16], [80,24], [52,0], [70,72], [18,32], [42,72], [14,48], [60,0], [24,48], [66,72], [18,48], [52,24], [44,40], [78,72], [20,48], [28,40], [40,56], [62,0], [42,40], [20,16], [64,16], [40,64], [18,24], [28,24], [74,8], [80,32], [16,32], [14,40], [40,48], [28,32], [68,72], [76,8], [26,48], [78,8], [72,8], [52,8], [80,48], [14,56], [28,16], [70,16], [52,16], [82,32], [14,16], [80,40], [18,16], [12,16], [80,8], [80,56], [40,40], [22,56], [50,32], [82,24], [16,24], [16,56], [22,16], [16,16], [12,24], [50,0], [14,24], [26,16], [28,48], [14,8], [14,32], [82,16], [24,56], [44,32], [82,40], [22,64], [66,16], [82,8], [80,0], [24,16], [68,16], [80,64], [64,8], [78,0], [12,48], [12,56], [42,32], [30,24], [82,48], [10,16], [12,8], [82,56], [70,8], [30,16], [50,24], [20,56], [64,0], [10,24], [18,56], [40,72], [48,32], [12,32], [38,32], [50,8], [40,32], [46,32], [28,8], [50,16], [24,64], [16,8], [30,40], [38,64], [12,40], [82,0], [30,32], [20,8], [80,72], [38,40], [76,0], [26,56], [84,32], [84,64], [82,64], [16,64], [18,8], [38,56], [48,24], [0,56], [26,8], [38,48], [14,64], [20,64], [38,24], [44,24], [14,0], [84,40], [84,56], [36,64], [12,64], [22,72], [84,8], [18,64], [10,32], [26,0], [36,32], [22,8], [46,24], [10,72], [36,40], [48,16], [74,0], [16,72], [38,72], [30,48], [10,8], [32,72], [86,64], [28,0], [86,72], [36,56], [10,64], [34,40], [0,0], [12,0], [24,0], [48,0], [72,0], [84,0], [0,8], [0,16], [0,24], [42,24], [84,24], [0,48], [36,48], [84,48], [30,72], [84,72], [8,16], [24,8], [34,72], [32,40], [34,48], [40,24], [82,72], [10,56], [34,64], [8,24], [12,72], [36,72], [66,8], [32,24], [28,56], [22,0], [10,48], [32,32], [68,8], [24,72], [18,72], [10,40], [84,16], [14,72], [34,56], [36,24], [0,32], [0,64], [30,8], [26,64], [48,8], [6,16], [20,72], [16,0], [70,0], [66,0], [34,32], [46,16], [32,16], [86,0], [32,48], [94,0], [0,40], [28,72], [8,72], [20,0], [2,56], [86,8], [8,32], [6,24], [44,16], [38,16], [88,72], [8,8], [4,16], [8,40], [18,0], [6,8], [10,0], [86,32], [68,0], [34,24], [2,48], [8,48], [28,64], [4,48], [26,72], [42,16], [6,40], [6,48], [32,64], [40,16], [2,64], [0,72], [86,56], [86,40], [30,56], [4,8], [6,32], [4,24], [88,0], [30,64], [36,16], [6,0], [8,64], [4,40], [8,56], [2,16], [32,56], [4,56], [2,72], [4,0], [8,0], [86,24], [2,8], [2,24], [86,48], [86,16], [2,0], [88,8], [30,0], [2,40], [4,32], [46,8], [6,72], [34,16], [46,0], [88,64], [6,56], [88,40], [2,32], [90,40], [4,72], [40,8], [88,32], [42,8], [94,8], [88,16], [44,8], [92,0], [32,8], [38,8], [4,64], [88,24], [90,0], [88,48], [6,64], [90,48], [92,40], [90,32], [90,16], [44,0], [36,8], [88,56], [42,0], [90,24], [90,72], [90,8], [34,8], [92,48], [92,8], [40,0], [94,16], [92,16], [92,32], [92,24], [32,0], [90,56], [94,24], [90,64], [94,32], [94,40], [38,0], [94,48], [92,72], [92,56], [34,0], [36,0], [94,56], [94,72], [92,64], [94,64]]
WRITTER_TRANSITION_TABLE1 equ [[82,64], [82,72], [82,56], [80,64], [80,72], [84,72], [84,64], [80,56], [80,48], [70,48], [70,56], [70,40], [68,40], [84,56], [82,48], [70,64], [68,48], [86,72], [78,72], [72,64], [78,64], [86,64], [72,56], [90,64], [72,48], [70,32], [66,40], [68,72], [70,72], [90,72], [88,64], [78,48], [80,40], [68,56], [68,64], [88,72], [68,32], [72,40], [78,56], [78,40], [92,64], [92,72], [66,32], [72,72], [74,64], [86,56], [66,48], [72,32], [76,64], [76,72], [84,48], [90,56], [88,56], [36,72], [76,40], [74,72], [64,32], [76,32], [74,56], [92,56], [66,72], [74,40], [76,48], [74,48], [34,72], [70,24], [64,40], [78,32], [74,32], [82,40], [76,56], [94,64], [76,24], [72,24], [94,72], [66,56], [42,40], [76,16], [76,8], [66,64], [38,72], [74,24], [44,40], [64,24], [68,24], [66,24], [42,72], [42,32], [40,32], [40,40], [94,56], [40,72], [64,48], [62,32], [36,64], [42,48], [42,64], [78,8], [44,48], [64,72], [44,64], [78,24], [44,72], [76,0], [92,48], [74,16], [78,16], [62,72], [94,40], [38,64], [42,56], [86,48], [94,32], [94,48], [80,32], [58,40], [58,48], [40,64], [40,48], [44,56], [90,48], [64,16], [62,24], [62,40], [72,16], [46,40], [62,64], [60,32], [60,40], [44,32], [70,16], [34,64], [64,64], [74,8], [88,48], [64,56], [60,64], [58,56], [40,56], [38,40], [40,24], [78,0], [60,48], [60,72], [60,56], [66,16], [46,48], [92,40], [74,0], [38,32], [64,8], [66,8], [62,8], [68,16], [62,16], [58,32], [46,64], [62,48], [84,40], [32,72], [62,56], [50,0], [92,32], [56,40], [68,8], [38,48], [36,32], [36,24], [38,56], [46,56], [56,48], [38,24], [38,0], [34,24], [36,40], [36,16], [58,64], [42,24], [34,16], [60,24], [46,72], [46,32], [34,32], [38,8], [40,0], [94,24], [60,8], [32,0], [52,0], [62,0], [38,16], [36,56], [48,40], [72,8], [90,40], [80,8], [56,56], [36,8], [70,8], [80,0], [68,0], [0,0], [24,0], [30,0], [36,0], [42,0], [48,0], [60,0], [66,0], [72,0], [84,0], [36,48], [48,48], [58,72], [64,0], [22,0], [32,8], [82,32], [60,16], [80,24], [34,8], [56,64], [40,16], [34,40], [82,0], [80,16], [58,24], [20,0], [70,0], [34,0], [54,40], [26,0], [44,0], [56,32], [44,24], [48,64], [86,0], [32,16], [88,40], [90,32], [48,56], [46,24], [54,64], [40,8], [54,48], [86,40], [28,0], [46,0], [92,24], [50,8], [30,8], [18,0], [34,56], [50,40], [56,72], [32,64], [48,32], [52,40], [32,24], [92,0], [54,72], [20,8], [82,8], [48,72], [52,64], [34,48], [50,48], [54,56], [58,16], [48,8], [58,8], [30,72], [84,32], [94,0], [56,24], [58,0], [84,8], [46,16], [52,48], [54,0], [90,0], [50,64], [48,16], [52,72], [88,32], [30,16], [42,16], [32,32], [84,16], [82,24], [88,0], [94,16], [18,8], [82,16], [52,8], [16,0], [54,32], [22,8], [48,24], [84,24], [22,16], [0,56], [42,8], [20,16], [50,56], [50,72], [86,32], [32,40], [52,56], [86,16], [86,8], [56,16], [46,8], [86,24], [28,8], [0,64], [24,8], [54,24], [94,8], [50,16], [30,24], [56,0], [28,16], [90,24], [14,0], [0,72], [44,16], [54,16], [92,8], [26,8], [22,24], [52,16], [44,8], [52,32], [50,32], [24,16], [92,16], [88,24], [2,0], [0,8], [30,32], [16,8], [54,8], [52,24], [12,0], [0,48], [18,16], [56,8], [90,8], [50,24], [28,24], [20,24], [88,8], [32,48], [26,16], [32,56], [30,64], [28,72], [10,0], [2,72], [88,16], [24,24], [30,40], [2,64], [2,56], [90,16], [4,0], [0,16], [20,32], [8,0], [28,32], [22,32], [6,0], [0,24], [18,40], [0,40], [26,24], [20,40], [0,32], [22,72], [18,24], [2,48], [14,8], [16,16], [8,72], [28,40], [28,64], [18,48], [18,32], [30,48], [16,72], [24,72], [16,64], [18,72], [20,72], [4,72], [22,40], [24,32], [30,56], [26,72], [6,72], [12,8], [10,72], [20,48], [22,64], [18,64], [2,8], [26,32], [14,64], [22,48], [16,48], [24,56], [10,8], [18,56], [22,56], [16,40], [16,56], [24,64], [24,48], [14,72], [2,40], [4,64], [24,40], [10,64], [20,64], [28,48], [4,56], [12,64], [26,40], [26,64], [26,48], [26,56], [12,72], [28,56], [20,56], [8,64], [4,48], [14,16], [8,8], [16,24], [6,64], [10,16], [14,56], [2,32], [4,8], [2,16], [12,16], [16,32], [6,8], [2,24], [12,56], [4,40], [10,56], [14,48], [6,56], [8,16], [4,32], [10,24], [8,56], [12,48], [14,40], [14,24], [10,48], [8,24], [12,24], [6,48], [4,16], [6,16], [4,24], [6,40], [6,32], [8,32], [6,24], [12,40], [10,40], [14,32], [10,32], [8,48], [8,40], [12,32]]
WRITTER_TRANSITION_TABLE2 equ [[4,16], [6,16], [6,24], [4,8], [6,0], [6,8], [8,0], [4,24], [10,0], [8,16], [8,24], [10,16], [6,32], [8,40], [12,0], [8,32], [4,0], [10,24], [8,8], [10,40], [4,32], [10,8], [2,8], [2,16], [10,32], [6,40], [14,0], [10,48], [2,24], [94,40], [92,40], [12,8], [8,48], [12,16], [4,40], [90,40], [0,24], [2,32], [16,0], [58,8], [58,0], [0,32], [10,56], [40,72], [0,16], [12,24], [94,32], [88,40], [92,72], [2,40], [40,64], [42,72], [10,64], [92,48], [0,40], [94,48], [2,0], [92,32], [60,8], [12,40], [6,48], [90,32], [88,32], [42,64], [12,32], [38,64], [14,8], [2,48], [60,0], [0,48], [12,48], [16,72], [90,72], [8,56], [90,48], [60,16], [12,64], [94,72], [56,0], [92,64], [4,48], [38,72], [8,64], [64,0], [0,8], [86,40], [58,16], [94,64], [66,0], [12,56], [56,8], [16,64], [14,72], [14,64], [44,72], [62,16], [64,8], [8,72], [10,72], [62,8], [64,16], [68,0], [66,8], [88,48], [94,56], [70,8], [86,32], [70,0], [92,56], [18,0], [12,72], [62,0], [68,8], [94,24], [0,56], [66,16], [18,72], [14,16], [44,64], [90,64], [46,72], [48,72], [64,24], [36,64], [36,72], [18,64], [16,40], [2,56], [90,56], [70,16], [40,56], [68,16], [92,24], [6,56], [14,56], [14,40], [16,56], [46,40], [88,24], [90,24], [46,64], [62,24], [16,8], [56,16], [38,56], [14,24], [22,0], [50,72], [46,48], [60,24], [14,48], [18,32], [66,24], [48,64], [86,48], [16,32], [20,0], [18,40], [16,48], [42,56], [6,72], [6,64], [44,56], [14,32], [54,0], [0,72], [54,8], [72,16], [44,48], [58,24], [0,64], [4,56], [94,16], [88,72], [46,56], [88,0], [44,40], [34,72], [50,64], [18,56], [72,8], [48,40], [20,32], [88,8], [54,16], [64,32], [20,40], [84,32], [82,0], [84,40], [88,56], [46,0], [18,48], [86,0], [88,16], [90,16], [90,0], [92,16], [90,8], [52,24], [16,24], [56,24], [54,24], [42,48], [46,32], [80,0], [86,24], [46,16], [46,24], [0,0], [24,0], [48,0], [72,0], [84,0], [48,48], [52,32], [68,24], [52,16], [22,40], [94,8], [52,72], [54,32], [2,72], [2,64], [20,72], [66,32], [18,24], [88,64], [16,16], [92,8], [48,24], [48,32], [82,72], [50,24], [40,48], [52,64], [4,64], [48,56], [34,64], [86,8], [48,16], [4,72], [52,0], [44,0], [74,16], [52,8], [94,0], [36,56], [50,32], [84,72], [92,0], [20,48], [20,64], [22,8], [62,32], [86,72], [56,32], [70,24], [72,24], [50,16], [20,24], [54,40], [18,8], [28,0], [74,24], [50,0], [20,56], [46,8], [42,40], [50,40], [22,48], [44,32], [22,32], [84,8], [44,16], [42,0], [56,40], [44,24], [58,32], [86,16], [38,48], [60,32], [54,64], [86,56], [54,72], [48,8], [80,72], [22,16], [82,8], [26,0], [30,0], [32,72], [52,40], [56,72], [84,24], [64,40], [24,8], [22,24], [20,8], [56,64], [54,48], [84,48], [50,8], [18,16], [58,72], [56,48], [50,56], [54,56], [76,24], [44,8], [22,72], [50,48], [82,32], [68,32], [78,0], [20,16], [62,40], [24,16], [56,56], [66,40], [34,0], [32,0], [52,56], [86,64], [40,0], [22,56], [84,16], [24,40], [40,40], [52,48], [76,32], [74,8], [58,64], [28,8], [80,8], [22,64], [58,40], [24,72], [26,8], [60,40], [82,40], [74,32], [76,16], [24,24], [62,48], [42,8], [82,24], [24,32], [84,64], [42,32], [30,8], [42,16], [58,48], [58,56], [74,0], [82,16], [36,0], [24,48], [36,48], [60,48], [82,64], [26,16], [34,8], [34,56], [80,64], [78,72], [70,32], [78,32], [72,32], [84,56], [78,24], [42,24], [30,72], [68,40], [60,72], [26,72], [60,56], [80,32], [32,8], [32,64], [76,0], [64,48], [38,0], [24,64], [38,40], [78,8], [28,16], [60,64], [80,24], [36,8], [76,40], [40,8], [62,56], [28,72], [78,16], [76,8], [80,16], [26,24], [24,56], [74,40], [74,72], [76,72], [26,40], [78,64], [30,16], [66,48], [82,48], [80,40], [78,40], [38,8], [26,32], [40,16], [70,40], [40,32], [72,40], [74,64], [26,64], [72,72], [32,16], [76,64], [74,48], [82,56], [76,48], [26,48], [34,48], [68,48], [34,16], [62,72], [28,40], [74,56], [76,56], [28,24], [68,72], [36,40], [62,64], [72,64], [30,64], [40,24], [80,56], [78,56], [32,56], [28,48], [36,16], [66,72], [70,72], [64,56], [78,48], [38,16], [72,48], [80,48], [28,64], [26,56], [72,56], [28,32], [70,48], [64,72], [30,48], [70,64], [30,40], [30,24], [32,48], [38,32], [30,56], [28,56], [66,56], [70,56], [68,64], [68,56], [34,40], [64,64], [66,64], [38,24], [32,24], [30,32], [32,40], [34,24], [36,32], [36,24], [32,32], [34,32]]
WRITTER_TRANSITION_TABLE3 equ [[46,40], [8,72], [44,40], [64,72], [66,72], [10,72], [12,72], [20,72], [44,48], [14,72], [8,64], [48,40], [46,48], [64,64], [6,72], [48,32], [18,72], [10,64], [46,32], [66,64], [16,72], [62,72], [4,40], [8,48], [62,64], [8,56], [42,40], [6,64], [50,40], [62,56], [22,72], [6,40], [50,32], [12,64], [8,40], [2,48], [10,48], [6,48], [68,72], [4,48], [10,56], [2,40], [90,72], [44,32], [92,72], [10,40], [0,48], [48,48], [64,56], [6,56], [88,72], [0,40], [60,72], [60,64], [4,32], [62,48], [42,48], [94,72], [2,56], [66,40], [0,56], [48,24], [66,48], [20,64], [60,56], [68,40], [64,48], [66,56], [44,56], [14,64], [42,32], [86,72], [0,32], [58,72], [4,56], [0,24], [0,64], [2,32], [50,24], [46,56], [22,64], [68,48], [70,72], [64,40], [0,16], [6,32], [46,24], [52,40], [68,64], [4,72], [4,64], [58,64], [50,48], [12,56], [72,72], [84,72], [52,32], [18,64], [2,24], [2,64], [68,32], [84,64], [40,72], [44,24], [90,0], [12,48], [60,48], [76,56], [42,24], [78,56], [68,56], [94,0], [16,64], [76,48], [20,56], [12,40], [74,72], [82,64], [88,0], [92,0], [68,0], [70,0], [86,64], [0,72], [48,16], [94,64], [70,40], [22,16], [80,64], [4,24], [8,32], [78,64], [62,40], [40,32], [40,40], [42,56], [76,64], [66,32], [74,48], [82,72], [10,32], [74,40], [70,32], [58,0], [82,0], [22,0], [50,16], [72,40], [20,0], [46,0], [42,72], [44,64], [54,32], [22,56], [0,8], [40,24], [46,64], [78,48], [80,56], [46,16], [2,72], [24,72], [38,72], [20,48], [48,56], [52,48], [94,8], [52,24], [84,56], [92,8], [46,8], [90,8], [42,64], [56,0], [80,0], [22,8], [2,16], [44,16], [22,24], [18,56], [56,72], [42,16], [70,48], [92,64], [58,56], [18,0], [40,64], [20,16], [48,8], [56,32], [76,40], [58,8], [74,64], [44,0], [54,40], [82,56], [24,16], [80,72], [0,0], [12,0], [24,0], [48,0], [54,0], [60,0], [66,0], [72,0], [78,0], [84,0], [72,48], [84,48], [56,24], [74,56], [76,72], [44,72], [70,8], [20,8], [92,16], [86,56], [64,32], [16,0], [88,8], [68,24], [14,0], [80,8], [18,48], [6,24], [60,40], [94,16], [86,0], [14,56], [70,64], [80,16], [54,24], [88,64], [94,56], [58,16], [40,48], [72,32], [80,24], [46,72], [90,64], [40,16], [86,48], [80,48], [70,24], [44,8], [82,8], [24,8], [52,0], [76,0], [24,64], [78,40], [38,64], [72,64], [78,8], [10,0], [84,40], [56,64], [20,24], [60,8], [12,32], [90,16], [58,24], [80,32], [78,72], [60,16], [20,40], [12,8], [50,8], [82,48], [16,56], [18,16], [34,40], [70,56], [38,40], [82,16], [4,16], [50,0], [74,0], [22,48], [56,8], [36,40], [70,16], [58,48], [62,32], [86,40], [56,16], [78,16], [14,48], [82,40], [80,40], [68,8], [42,0], [72,8], [50,56], [18,8], [82,24], [38,32], [82,32], [94,24], [10,24], [26,0], [52,16], [58,32], [60,24], [94,48], [10,8], [8,24], [14,40], [18,40], [88,16], [66,24], [56,40], [78,32], [72,56], [48,64], [14,8], [76,8], [68,16], [24,24], [54,48], [78,24], [62,0], [64,0], [60,32], [18,24], [92,56], [38,24], [92,48], [40,56], [42,8], [84,8], [52,8], [16,48], [10,16], [34,48], [54,8], [74,32], [58,40], [86,8], [16,8], [20,32], [24,56], [94,32], [54,16], [36,48], [62,24], [84,16], [8,0], [84,32], [2,8], [16,16], [22,32], [92,24], [94,40], [86,16], [52,56], [40,0], [74,8], [62,16], [92,40], [6,0], [72,24], [84,24], [26,72], [36,72], [18,32], [26,8], [36,64], [12,16], [56,56], [64,24], [38,48], [72,16], [32,40], [38,16], [16,40], [28,0], [16,24], [4,0], [76,32], [22,40], [36,32], [56,48], [6,16], [88,48], [62,8], [34,32], [12,24], [48,72], [86,32], [2,0], [88,40], [40,8], [14,32], [90,48], [86,24], [76,16], [16,32], [88,56], [54,56], [90,40], [26,16], [90,24], [32,32], [66,8], [8,16], [90,56], [4,8], [36,56], [88,24], [38,56], [66,16], [38,0], [92,32], [14,16], [30,0], [36,24], [76,24], [8,8], [34,56], [54,72], [28,72], [74,16], [88,32], [54,64], [32,48], [64,16], [6,8], [26,64], [34,24], [74,24], [14,24], [36,0], [24,48], [64,8], [32,24], [32,0], [90,32], [38,8], [28,8], [36,16], [34,0], [50,64], [24,32], [30,40], [34,64], [34,16], [26,56], [30,32], [26,24], [32,16], [30,24], [28,16], [30,72], [52,64], [36,8], [34,72], [30,8], [30,16], [24,40], [32,56], [50,72], [28,64], [30,48], [34,8], [32,8], [26,48], [28,24], [52,72], [32,72], [28,40], [28,48], [28,32], [30,64], [28,56], [32,64], [30,56], [26,32], [26,40]]
WRITTER_TRANSITION_NB_STEPS equ 480
print "WRITTER_TRANSITION_NB_STEPS: ", WRITTER_TRANSITION_NB_STEPS


	org 0x4000

init
	run $
	di

        ; set up the screen

		ld hl, 0xc9fb : ld (0x38), hl
		ld bc, 0xbc00 + 1 : out (c), c : ld bc, 0xbd00 + 96/2 : out (c), c
		ld bc, 0xbc00 + 2 : out (c), c : ld bc, 0xbd00 + 50 + 2 : out (c), c
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


    ; init the writter
    ld hl, WRITTER_PAGE0
    call writter_draw_page_start
    ei
frame
    ld b, 0xF5
    in a, (c)
    rra
    jr nc, frame

    halt : halt

    ld bc, 0x7f10 : out (c), c : ld bc, 0x7f40 : out (c), c
    call writter_draw_page_step
    ld bc, 0x7f10 : out (c), c : ld bc, 0x7f45 : out (c), c
    halt
    ld bc, 0x7f10 : out (c), c : ld bc, 0x7f54 : out (c), c

    ei
    jp frame



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
    jr z, .draw_step
    cp WRITTER_STATE_COPY
    jr z, .copy_step
    cp WRITTER_STATE_WAIT
    jr z, .wait_step
    ret                                  ; nothing to do (done, or not started)

.wait_step
    ld a, 0 : writter_wait_left equ $-1
    dec a
    ld (writter_wait_left), a
    ret nz                                  ; still waiting, nothing else to do this call

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
    ld b, SCREEN_WDITH
.clear_byte_loop
        ld a, (hl)
        and WRITTER_CLEAR_MASK
        ld (hl), a
        inc hl
        djnz .clear_byte_loop

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
    ; TODO Implementation for the copy step
    ; screen_table contains the destination screen addresses in 0xc000
    ; the source screen adress is obtained by substracting 0x40 to the high byte (or resetting bit 6)


    repeat 4
        call copy_one_block_step_erase1
    endr


    ld a, 25 : .delay_erase2 equ $-1
    or a : jr z, .delay_erase2_done
    dec a : ld (.delay_erase2), a
    ret

.delay_erase2_done


    repeat 4
        call copy_one_block_step_erase2
    endr


    ld a, 25 : .delay_step1 equ $-1
    or a : jr z, .delay_step1_done
    dec a : ld (.delay_step1), a
    ret

.delay_step1_done

    repeat 4
        call copy_one_block_step1
    endr

    ld a, 25 : .delay_step2 equ $-1
    or a : jr z, .delay_step2_done
    dec a : ld (.delay_step2), a
    ret

.delay_step2_done
    repeat 4
        call copy_one_block_step2
    endr
    ret



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

    ld a, 0 : writter_side equ $-1
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
    ld a, 0 : writter_pixels_pending equ $-1
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
    ld hl, WRITTER_TRANSITION_NB_STEPS
    ld (copy_one_block_step_erase1.copy_amount), hl
    ld (copy_one_block_step1.copy_amount), hl
    ld (copy_one_block_step2.copy_amount), hl
    ld (copy_one_block_step_erase2.copy_amount), hl


    ld hl, transition_tables : .transtion_ptr equ $-2
.restart_transition_tables
    ld c, (hl) : inc hl : ld b, (hl) : inc hl
    ld a, b : or c : jr nz, .setup_transition_tables
    ld hl, transition_tables : jr .restart_transition_tables
    
.setup_transition_tables
    ld (.transtion_ptr), hl
    ld (copy_one_block_step_erase1.copy_table_position), bc
    ld (copy_one_block_step1.copy_table_position), bc
    ld (copy_one_block_step2.copy_table_position), bc
    ld (copy_one_block_step_erase2.copy_table_position), bc
    
    ld a, 3
    ld (writter_draw_page_step.delay_step1), a
    ld (writter_draw_page_step.delay_erase2), a
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

;; Erase previous char
copy_one_block_step_erase1
    ld ix, writter_transition_table0 : .copy_table_position equ $-2

    ld hl, (.copy_amount)
    ld a, h : or l : ret z

    ld c, WRITTER_RIGHT_CLEAR_MASK
    ld b, WRITTER_LEFT_CLEAR_MASK

.copy_loop
        ; get source
        ld l, (ix+0) : inc ix
        ld h, (ix+0) : inc ix
        ld (.copy_table_position), ix

        ; get destination
        ld a, 0x40 : add h : ld d, a
        ld e, l
        
        ; copy top 8 lines
        assert WRITTER_TRANSITION_ATOMIC_UNIT_WIDTH_IN_PIXELS == 4
        assert WRITTER_TRANSITION_ATOMIC_UNIT_HEIGHT_IN_PIXELS

        repeat 4, i, 0
            ld a, (de) : and WRITTER_RIGHT_CLEAR_MASK : ld (de), a : inc de

            ld a, 8 : add d : ld d, a

            ld a, (de) : and WRITTER_LEFT_CLEAR_MASK : ld (de), a : dec de


            if {i} != 4
                ld a, 8 : add d : ld d, a
            endif
        endr

    ld bc, WRITTER_TRANSITION_NB_STEPS : .copy_amount equ $-2
    dec bc
    ld (.copy_amount), bc
    ret


copy_one_block_step1
    ld ix, writter_transition_table0 : .copy_table_position equ $-2

    ld hl, (.copy_amount)
    ld a, h : or l : ret z

    ld c, WRITTER_RIGHT_CLEAR_MASK
    ld b, WRITTER_LEFT_CLEAR_MASK

.copy_loop
        ; get source
        ld l, (ix+0) : inc ix
        ld h, (ix+0) : inc ix
        ld (.copy_table_position), ix

        ; get destination
        ld a, 0x40 : add h : ld d, a
        ld e, l
        
        ; copy top 8 lines
        assert WRITTER_TRANSITION_ATOMIC_UNIT_WIDTH_IN_PIXELS == 4
        assert WRITTER_TRANSITION_ATOMIC_UNIT_HEIGHT_IN_PIXELS

        repeat 4, i, 0
            ld a, (hl) : /*and b :*/ inc hl : ld (de), a : inc de
            ;ld a, (hl) : /*and c :*/ dec hl : ld (de), a : dec de

            ld a, 8 : add d : ld d, a
            ld a, 8 : add h : ld h, a

            ld a, (hl) : /*and c :*/ dec hl : ld (de), a : dec de


            if {i} != 4
                ld a, 8 : add d : ld d, a
                ld a, 8 : add h : ld h, a
            endif
        endr

    ld bc, WRITTER_TRANSITION_NB_STEPS : .copy_amount equ $-2
    dec bc
    ld (.copy_amount), bc
    ret



copy_one_block_step_erase2
    ld ix, writter_transition_table0 : .copy_table_position equ $-2

    ld hl, (.copy_amount)
    ld a, h : or l : ret z

    ld c, WRITTER_RIGHT_CLEAR_MASK
    ld b, WRITTER_LEFT_CLEAR_MASK

.copy_loop
        ; get source
        ld l, (ix+0) : inc ix
        ld h, (ix+0) : inc ix
        ld (.copy_table_position), ix

        ; get destination
        ld a, 0x40 : add h : ld d, a
        ld e, l
        
        ; copy top 8 lines
        assert WRITTER_TRANSITION_ATOMIC_UNIT_WIDTH_IN_PIXELS == 4
        assert WRITTER_TRANSITION_ATOMIC_UNIT_HEIGHT_IN_PIXELS

        repeat 4, i, 0
            ;ld a, (hl) : /*and b :*/ inc hl : ld (de), a : inc de
            ;
            inc de 
            ld a, (de) : and  WRITTER_CLEAR_MASK : ld (de), a : dec de

            ld a, 8 : add d : ld d, a

            ld a, (de) :  and WRITTER_CLEAR_MASK :  ld (de), a 


            if {i} != 4
                ld a, 8 : add d : ld d, a
            endif
        endr

    ld bc, WRITTER_TRANSITION_NB_STEPS : .copy_amount equ $-2
    dec bc
    ld (.copy_amount), bc
    ret


copy_one_block_step2
    ld ix, writter_transition_table0 : .copy_table_position equ $-2

    ld hl, (.copy_amount)
    ld a, h : or l : ret z

    ld c, WRITTER_RIGHT_CLEAR_MASK
    ld b, WRITTER_LEFT_CLEAR_MASK

.copy_loop
        ; get source
        ld l, (ix+0) : inc ix
        ld h, (ix+0) : inc ix
        ld (.copy_table_position), ix

        ; get destination
        ld a, 0x40 : add h : ld d, a
        ld e, l
        
        ; copy top 8 lines
        assert WRITTER_TRANSITION_ATOMIC_UNIT_WIDTH_IN_PIXELS == 4
        assert WRITTER_TRANSITION_ATOMIC_UNIT_HEIGHT_IN_PIXELS

        repeat 4, i, 0
            ;ld a, (hl) : /*and b :*/ inc hl : ld (de), a : inc de
            ;
            inc hl : inc de 
            ld a, (hl) : dec hl : ld (de), a : dec de

            ld a, 8 : add d : ld d, a
            ld a, 8 : add h : ld h, a

            ld a, (hl) :  ld (de), a 


            if {i} != 4
                ld a, 8 : add d : ld d, a
                ld a, 8 : add h : ld h, a
            endif
        endr

    ld bc, WRITTER_TRANSITION_NB_STEPS : .copy_amount equ $-2
    dec bc
    ld (.copy_amount), bc
    ld a, b : or c
    ret nz


    ld a, WRITTER_PAGE_WAIT_FRAMES
    ld (writter_wait_left), a
    ld a, WRITTER_STATE_WAIT
    ld (writter_state), a
    xor a
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
            or a : ld bc, 0x800 ; works correctly for any destination screen
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
        "rr iiii",
        "rrrrr iiii",
        "rrrrrr iiii",
        "rrrrrrr iiii",
        "rrrrrrrr iiii"
    )

WRITTER_PAGE2
    WRITTER_ENCODE_PAGE(
        " a ",
        " r ",
        " i ",
        "                   ",
        "ariariariariariariariari",
        "rr iiii",
        "rrrrr iiii",
        "rrrrrr iiii",
        "rrrrrrr iiii",
        "rrrrrrrr iiii"
    )

WRITTER_PAGES
    dw WRITTER_PAGE0
    dw WRITTER_PAGE1
    dw WRITTER_PAGE2
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


    ; Instead of storing pairs of x,y, directly store screen addresses
    ; it is the very same size
    macro BUILD_WRITTER_TRANSITION_TABLE table_code
writter_transition_table{table_code}
        current_db = WRITTER_TRANSITION_TABLE{table_code}
        repeat list_len(current_db), i, 0
            current_entry = list_get(current_db, {i})
            current_x = list_get(current_entry, 0)
            current_y = list_get(current_entry, 1) + 8*WRITTER_GRID_START_ROW
            current_address = compute_screen_address(0xC000, 96, current_x, current_y) - 0x4000
            db low(current_address)
            db high(current_address)

        endrepeat
    endm
    

    ; generate the copy tables for the writter
    BUILD_WRITTER_TRANSITION_TABLE(0)
    BUILD_WRITTER_TRANSITION_TABLE(1)
    BUILD_WRITTER_TRANSITION_TABLE(2)
    BUILD_WRITTER_TRANSITION_TABLE(3)
    
transition_tables
    dw writter_transition_table0
    dw writter_transition_table1
    dw writter_transition_table2
    dw writter_transition_table3
    dw 0



;;
;; Generate the screen table
;; TODO align on 256 bytes to avoif 16 bits manpuations when reading
screen_table
    repeat 8*SCREEN_HEIGHT_CHARS, lineid, 0
        dw compute_screen_address(0xc000, 96, 0, {lineid})
    endr


;;
;; Generate the screen table for the second screen as we are using a double buffer
screen_table2
    repeat 8*SCREEN_HEIGHT_CHARS, lineid, 0
        current_low = peek(screen_table + 2*{lineid}+0)
        current_high = peek(screen_table + 2*{lineid}+1)

        db current_low
        db current_high - 0x40 ; shit from 0xC000 to 0x8000
    endr


    ; screen
    org 0x8000
    incbin "../../data/face0_cpc.scr"

    org 0xc000
    incbin "../../data/face0_cpc.scr"