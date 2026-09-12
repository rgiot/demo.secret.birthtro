include once "inner://ga.asm"




BACKGROUND_IMG_PALETTE equ load(FACE_PAL) ; 4 inks in a list
SPECTRAL_SPRITES_PALETTE equ [0x58, 0x45, 0x4d, 0x4f ]   ; 4 inks in a list 
SPECTRAL_SPRITES_MONOCHROME_PALETTE equ [0x4f, 0x4f, 0x4f, 0x4f]   ; 4 inks in a list
BLACK_PALETTE4 equ [GA_BLACK, GA_BLACK, GA_BLACK, GA_BLACK] ; DO NOT MODIFY
WRITTER_PALETTE equ 0x4A                                 ; 1 ink


SCROLLER_COLORED_PALETTE equ [
        GA_COL_09,
		GA_COL_10,
		GA_COL_18,
		GA_COL_20,
		GA_COL_20,
		GA_COL_18,
		GA_COL_10,
		GA_COL_09
]

assert list_len(SCROLLER_COLORED_PALETTE) == 8, "SCROLLER_COLORED_PALETTE must be 8 inks long"

SCROLLER_MONOCHROME_PALETTE equ [
        GA_BRIGHT_WHITE,
        GA_BRIGHT_WHITE,
        GA_BRIGHT_WHITE,
        GA_BRIGHT_WHITE,
        GA_BRIGHT_WHITE,
        GA_BRIGHT_WHITE,
        GA_BRIGHT_WHITE,
        GA_BRIGHT_WHITE
]
assert list_len(SCROLLER_MONOCHROME_PALETTE) == 8, "SCROLLER_MONOCHROME_PALETTE must be 8 inks long"


inks = 0

;;
;; Generate the palette with the given configuration.
;; Even when something is hidden a palette needs to be provided
function GENERATE_PALETTE background, background_visible, sprites, sprites_visible, writter, writter_visible
    inks = [GA_BLACK, GA_BLACK, GA_BLACK, GA_BLACK, GA_BLACK, GA_BLACK, GA_BLACK, GA_BLACK, GA_BLACK, GA_BLACK, GA_BLACK, GA_BLACK, GA_BLACK, GA_BLACK, GA_BLACK, GA_BLACK]  ; default to 16 black

    ; Get the true background palette
    if {background_visible}
        real_background = {background}
    else
        real_background = BLACK_PALETTE4
    endif

    ; set the background everywhere (background position as well as sprite and writter)
    repeat 4, i, 0
        inks = list_set(inks, {i}, list_get(real_background, {i}))
        inks = list_set(inks, {i}+(1<<2), list_get(real_background, {i}))
        inks = list_set(inks, {i}+(1<<3), list_get(real_background, {i}))
        inks = list_set(inks, {i}+(1<<3)+(1<<2), list_get(real_background, {i}))
    endrepeat


    if {sprites_visible}
        repeat 4, i, 0
            inks = list_set(inks, {i}+(1<<2), list_get({sprites}, {i})) ; on top of background
        endrepeat
    endif

    if {writter_visible}
        repeat 4, i, 0
            inks = list_set(inks, {i}+(1<<3)+(1<<2), {writter}) ; on top of background and sprites
            inks = list_set(inks, {i}+(1<<3), {writter})
        endrepeat
    endif

    return inks
endfunction

;; Set the palette to the given one, which is a list of 16 inks
;; In: HL: pointer to the palette
;; Modified: Hl, A, B
ga_set_palette
    ld b, 0x7f : xor a
    repeat 16, i
        ld c, (hl)
        out (c), a : out (c), c
        if {i} != 16 : inc hl : inc a : endif
    endrepeat
    ret


    macro DEBUG_PALETTE palname
        PRINT "DEBUG palette:  {palname}"
        repeat 16, i, 0
            ink = peek({palname}+{i})
            PRINT "DEBUG ", {hex}ink
        endrepeat
    endm 

palette_background_only db GENERATE_PALETTE(BACKGROUND_IMG_PALETTE, true, SPECTRAL_SPRITES_PALETTE, false, WRITTER_PALETTE, false)
palette_all_visible db GENERATE_PALETTE(BACKGROUND_IMG_PALETTE, true, SPECTRAL_SPRITES_PALETTE, true, WRITTER_PALETTE, true)
palette_all_hidden db GENERATE_PALETTE(BLACK_PALETTE4, true, SPECTRAL_SPRITES_PALETTE, false, WRITTER_PALETTE, false)
palette_sprites_monochrome_only db GENERATE_PALETTE(BACKGROUND_IMG_PALETTE, false, SPECTRAL_SPRITES_MONOCHROME_PALETTE, true, WRITTER_PALETTE, false)
palette_sprites_monochrome_and_background db GENERATE_PALETTE(BACKGROUND_IMG_PALETTE, true, SPECTRAL_SPRITES_MONOCHROME_PALETTE, true, WRITTER_PALETTE, false)
palette_sprites_spectral_and_background db GENERATE_PALETTE(BACKGROUND_IMG_PALETTE, true, SPECTRAL_SPRITES_PALETTE, true, WRITTER_PALETTE, false)
palette_writter_only db GENERATE_PALETTE(BACKGROUND_IMG_PALETTE, false, SPECTRAL_SPRITES_PALETTE, false, WRITTER_PALETTE, true)
palette_all_but_spectral db GENERATE_PALETTE(BACKGROUND_IMG_PALETTE, true, SPECTRAL_SPRITES_MONOCHROME_PALETTE, false, WRITTER_PALETTE, true)


DEBUG_PALETTE(palette_background_only)
DEBUG_PALETTE(palette_all_visible)
DEBUG_PALETTE(palette_all_hidden)
DEBUG_PALETTE(palette_sprites_monochrome_only)
DEBUG_PALETTE(palette_sprites_monochrome_and_background)
DEBUG_PALETTE(palette_sprites_spectral_and_background)
DEBUG_PALETTE(palette_all_but_spectral)
DEBUG_PALETTE(palette_writter_only)







/*

SCROLLER_COLORED_PALETTE_1 equ [
        GA_COL_05,
		GA_COL_14,
		GA_COL_23,
		GA_COL_25,
		GA_COL_26,
		GA_COL_23,
		GA_COL_14,
		GA_COL_05
]


SCROLLER_COLORED_PALETTE_2 equ [
        GA_COL_03,
		GA_COL_06,
		GA_COL_23,
		GA_COL_24,
		GA_COL_26,
		GA_COL_16,
		GA_COL_07,
		GA_COL_03
]


SCROLLER_COLORED_PALETTE_2 equ [
        GA_COL_09,
		GA_COL_18,
		GA_COL_21,
		GA_COL_25,
		GA_COL_26,
		GA_COL_22,
		GA_COL_19,
		GA_COL_09
]



SCROLLER_COLORED_PALETTE_3 equ [
        GA_COL_05,
		GA_COL_14,
		GA_COL_19,
		GA_COL_22,
		GA_COL_25,
		GA_COL_23,
		GA_COL_11,
		GA_COL_01
]



SCROLLER_COLORED_PALETTE_4 equ [
        GA_COL_01,
		GA_COL_05,
		GA_COL_14,
		GA_COL_17,
		GA_COL_26,
		GA_COL_25,
		GA_COL_16,
		GA_COL_03
]



SCROLLER_COLORED_PALETTE_5 equ [
        GA_COL_09,
		GA_COL_12,
		GA_COL_15,
		GA_COL_24,
		GA_COL_26,
		GA_COL_19,
		GA_COL_10,
		GA_COL_01
]


SCROLLER_COLORED_PALETTE_6 equ [
        GA_COL_03,
		GA_COL_07,
		GA_COL_16,
		GA_COL_25,
		GA_COL_26,
		GA_COL_17,
		GA_COL_08,
		GA_COL_04
]



SCROLLER_COLORED_PALETTE_7 equ [
        GA_COL_04,
		GA_COL_08,
		GA_COL_17,
		GA_COL_25,
		GA_COL_26,
		GA_COL_23,
		GA_COL_14,
		GA_COL_05
]


SCROLLER_COLORED_PALETTE_8 equ [
        GA_COL_09,
		GA_COL_18,
		GA_COL_21,
		GA_COL_25,
		GA_COL_26,
		GA_COL_23,
		GA_COL_14,
		GA_COL_05
]



SCROLLER_COLORED_PALETTE_9 equ [
        GA_COL_04,
		GA_COL_13,
		GA_COL_19,
		GA_COL_25,
		GA_COL_26,
		GA_COL_23,
		GA_COL_14,
		GA_COL_05
]


SCROLLER_COLORED_PALETTE_10 equ [
        GA_COL_01,
		GA_COL_05,
		GA_COL_14,
		GA_COL_17,
		GA_COL_26,
		GA_COL_25,
		GA_COL_16,
		GA_COL_03
]


SCROLLER_COLORED_PALETTE_11 equ [
        GA_COL_05,
		GA_COL_10,
		GA_COL_22,
		GA_COL_23,
		GA_COL_26,
		GA_COL_17,
		GA_COL_07,
		GA_COL_04
]


SCROLLER_COLORED_PALETTE_12 equ [
        GA_COL_03,
		GA_COL_12,
		GA_COL_15,
		GA_COL_24,
		GA_COL_26,
		GA_COL_25,
		GA_COL_16,
		GA_COL_04
]

*/