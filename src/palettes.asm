include once "inner://ga.asm"




BACKGROUND_IMG_PALETTE equ load(FACE_PAL) ; 4 inks in a list
SPECTRAL_SPRITES_PALETTE equ [0x58, 0x45, 0x4d, 0x4f ]   ; 4 inks in a list 
SPECTRAL_SPRITES_MONOCHROME_PALETTE equ [0x4f, 0x4f, 0x4f, 0x4f]   ; 4 inks in a list
BLACK_PALETTE4 equ [GA_BLACK, GA_BLACK, GA_BLACK, GA_BLACK] ; DO NOT MODIFY
WRITTER_PALETTE equ 0x4A                                 ; 1 ink


SCROLLER_COLORED_PALETTE_0 equ [
        GA_COL_05,
		GA_COL_14,
		GA_COL_23,
		GA_COL_25,
		GA_COL_26,
		GA_COL_23,
		GA_COL_14,
		GA_COL_05
]


SCROLLER_COLORED_PALETTE_1 equ [
        GA_COL_03,
		GA_COL_06,
		GA_COL_15,
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


SCROLLER_COLORED_PALETTE_13 equ [
        GA_COL_01,
		GA_COL_02,
		GA_COL_11,
		GA_COL_20,
		GA_COL_26,
		GA_COL_23,
		GA_COL_14,
		GA_COL_05
]

SCROLLER_COLORED_PALETTE_14 equ [
        GA_COL_01,
		GA_COL_05,
		GA_COL_14,
		GA_COL_23,
		GA_COL_26,
		GA_COL_17,
		GA_COL_08,
		GA_COL_04
]

NB_SCROLLER_PALETTE equ 15

	; Check that voxy's palette are correct
	repeat NB_SCROLLER_PALETTE, i, 0
		assert list_len(SCROLLER_COLORED_PALETTE_{i}) == 8, "SCROLLER_COLORED_PALETTE_{i} must be 8 inks long"
	endrepeat


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

SCROLLER_MONOCHROME_PALETTE3 equ [
        GA_PASTEL_GREEN,
        GA_PASTEL_GREEN,
        GA_PASTEL_GREEN,
        GA_PASTEL_GREEN,
        GA_PASTEL_GREEN,
        GA_PASTEL_GREEN,
        GA_PASTEL_GREEN,
        GA_PASTEL_GREEN
]


SCROLLER_MONOCHROME_PALETTE2 equ [
        GA_SEA_GREEN,
        GA_SEA_GREEN,
        GA_SEA_GREEN,
        GA_SEA_GREEN,
        GA_SEA_GREEN,
        GA_SEA_GREEN,
        GA_SEA_GREEN,
        GA_SEA_GREEN
]



SCROLLER_RANDOM_PALETTE_0 equ [
        GA_COL_7,
        GA_COL_22,
        GA_COL_3,
        GA_COL_15,
        GA_COL_0,
        GA_COL_18,
        GA_COL_11,
        GA_COL_25
]

SCROLLER_RANDOM_PALETTE_1 equ [
        GA_COL_13,
        GA_COL_4,
        GA_COL_20,
        GA_COL_8,
        GA_COL_26,
        GA_COL_2,
        GA_COL_17,
        GA_COL_10
]

SCROLLER_RANDOM_PALETTE_2 equ [
        GA_COL_1,
        GA_COL_24,
        GA_COL_9,
        GA_COL_16,
        GA_COL_5,
        GA_COL_21,
        GA_COL_12,
        GA_COL_6
]

SCROLLER_RANDOM_PALETTE_3 equ [
        GA_COL_19,
        GA_COL_0,
        GA_COL_14,
        GA_COL_23,
        GA_COL_7,
        GA_COL_3,
        GA_COL_25,
        GA_COL_11
]

SCROLLER_RANDOM_PALETTE_4 equ [
        GA_COL_8,
        GA_COL_18,
        GA_COL_2,
        GA_COL_26,
        GA_COL_13,
        GA_COL_5,
        GA_COL_20,
        GA_COL_1
]

SCROLLER_RANDOM_PALETTE_5 equ [
        GA_COL_16,
        GA_COL_6,
        GA_COL_22,
        GA_COL_10,
        GA_COL_4,
        GA_COL_24,
        GA_COL_15,
        GA_COL_9
]

SCROLLER_RANDOM_PALETTE_6 equ [
        GA_COL_3,
        GA_COL_17,
        GA_COL_12,
        GA_COL_25,
        GA_COL_0,
        GA_COL_19,
        GA_COL_8,
        GA_COL_21
]

SCROLLER_RANDOM_PALETTE_7 equ [
        GA_COL_26,
        GA_COL_11,
        GA_COL_5,
        GA_COL_14,
        GA_COL_23,
        GA_COL_2,
        GA_COL_18,
        GA_COL_7
]

SCROLLER_RANDOM_PALETTE_8 equ [
        GA_COL_10,
        GA_COL_21,
        GA_COL_1,
        GA_COL_16,
        GA_COL_24,
        GA_COL_13,
        GA_COL_6,
        GA_COL_20
]

SCROLLER_RANDOM_PALETTE_9 equ [
        GA_COL_15,
        GA_COL_4,
        GA_COL_25,
        GA_COL_9,
        GA_COL_17,
        GA_COL_0,
        GA_COL_22,
        GA_COL_12
]


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



	;; The standard background color is used
	macro GENERATE_PALETTE_JOINT_SPECTRAL_WRITTER spectral, writter
		db GENERATE_PALETTE(
			BACKGROUND_IMG_PALETTE, true, 
			{spectral}, true, 
			{writter}, true
		)
	endm

	macro GENERATE_PALETTE_JOINT_NO_SPECTRAL_WRITTER spectral, writter
		db GENERATE_PALETTE(
			BACKGROUND_IMG_PALETTE, true, 
			{spectral}, false, 
			{writter}, true
		)
	endm

	SPECTRAL_PALETTE_SET1 equ [GA_COL_04, GA_COL_07, GA_COL_08, GA_COL_17]
	SPECTRAL_PALETTE_SET2 equ [GA_COL_03, GA_COL_06, GA_COL_15, GA_COL_24]
	SPECTRAL_PALETTE_SET3 equ [GA_COL_04, GA_COL_05, GA_COL_14, GA_COL_23]
	SPECTRAL_PALETTE_SET4 equ [GA_COL_03, GA_COL_09, GA_COL_13, GA_COL_22]
	SPECTRAL_PALETTE_SET5 equ [GA_COL_04, GA_COL_13, GA_COL_16, GA_COL_17]
	SPECTRAL_PALETTE_SET6 equ [GA_COL_05, GA_COL_08, GA_COL_17, GA_COL_25]
	SPECTRAL_PALETTE_SET7 equ SPECTRAL_PALETTE_SET1
	SPECTRAL_PALETTE_SET8 equ SPECTRAL_PALETTE_SET2
	SPECTRAL_PALETTE_SET9 equ SPECTRAL_PALETTE_SET3
	SPECTRAL_PALETTE_SET10 equ SPECTRAL_PALETTE_SET4
	SPECTRAL_PALETTE_SET11 equ SPECTRAL_PALETTE_SET5
	SPECTRAL_PALETTE_SET12 equ SPECTRAL_PALETTE_SET6

	WRITTER_COLOR_SET1 equ GA_COL_25
	WRITTER_COLOR_SET2 equ GA_COL_17
	WRITTER_COLOR_SET3 equ GA_COL_22
	WRITTER_COLOR_SET4 equ GA_COL_16
	WRITTER_COLOR_SET5 equ GA_COL_25
	WRITTER_COLOR_SET6 equ GA_COL_23
	WRITTER_COLOR_SET7 equ GA_COL_16
	WRITTER_COLOR_SET8 equ GA_COL_17
	WRITTER_COLOR_SET9 equ GA_COL_22
	WRITTER_COLOR_SET10 equ GA_COL_16
	WRITTER_COLOR_SET11 equ GA_COL_19
	WRITTER_COLOR_SET12 equ GA_COL_23

	NB_JOINT_SPECTRAL_WRITTER_SETS equ 12

	repeat NB_JOINT_SPECTRAL_WRITTER_SETS, step, 1
		palette_spectral_writter_set{step}
			GENERATE_PALETTE_JOINT_SPECTRAL_WRITTER(SPECTRAL_PALETTE_SET{{step}}, WRITTER_COLOR_SET{{step}})

		palette_no_spectral_writter_set{step}
			GENERATE_PALETTE_JOINT_NO_SPECTRAL_WRITTER(SPECTRAL_PALETTE_SET{{step}}, WRITTER_COLOR_SET{{step}})


	endr



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





joint_palette_spectral_writter_set
	if false
		; the first set is the default one
		dw palette_all_visible 
	endif
	; the other sets are the joint ones
	repeat NB_JOINT_SPECTRAL_WRITTER_SETS, step, 1
		dw palette_spectral_writter_set{{step}}
		dw palette_no_spectral_writter_set{{step}}
	endr
	dw 0


