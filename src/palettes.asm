include once "inner://ga.asm"

BACKGROUND_PALETTE equ load("../../data/face0_cpc.pal")  ; 4 inks in a list
SPECTRAL_SPRITES_PALETTE equ [0x58, 0x45, 0x4d, 0x4f ]   ; 4 inks in a list 
SPECTRAL_SPRITE_MONOCHROME_PALETTE equ [0x4f, 0x4f, 0x4f, 0x4f]   ; 4 inks in a list
BLACK_PALETTE4 equ [0x54, 0x54, 0x54, 0x54]
WRITTER_PALETTE equ 0x4A                                 ; 1 ink

;;
;; Generate the palette with the given configuration.
;; Even when something is hidden a palette needs to be provided
function GENERATE_PALETTE background, background_visible, sprites, sprites_visible, writter, writter_visible
    inks = [0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54, 0x54]  ; default to 16 black

    ; Get the true background palette
    if {background_visible}
        real_background = background
    else
        real_background = BLACK_PALETTE4
    endif

    ; set the background everywhere (background position as well as sprite and writter)
    repeat 4, i, 0
        inks = list_set(inks, {i}, list_get(real_background, {i}))
        inks = list_set(inks, {i}+1<<2, list_get(real_background, {i}))
        inks = list_set(inks, {i}+1<<3, list_get(real_background, {i}))
        inks = list_set(inks, {i}+1<<3+1<<2, list_get(real_background, {i}))
    endrepeat


    if {sprites_visible}
        repeat 4, i, 0
            inks = list_set(inks, {i}+1<<2, list_get(sprites, {i})) ; on top of background
        endrepeat
    endif

    if {writter_visible}
        repeat 4, i, 0
            inks = list_set(inks, {i}+1<<3+1<<2, list_get(writter, {i})) ; on top of background and sprites
            inks = list_set(inks, {i}+1<<3, list_get(writter, {i}))
        endrepeat
    endif

    return inks
endfunction



palette_all_visible db GENERATE_PALETTE(BACKGROUND_PALETTE, true, SPECTRAL_SPRITES_PALETTE, true, WRITTER_PALETTE, true)
palette_all_hidden db GENERATE_PALETTE(BLACK_PALETTE4, true, SPECTRAL_SPRITES_PALETTE, false, WRITTER_PALETTE, false)
palette_sprites_monochrome_only db GENERATE_PALETTE(BACKGROUND_PALETTE, false, SPECTRAL_SPRITE_MONOCHROME_PALETTE, true, WRITTER_PALETTE, false)
palette_sprites_monochrome_and_background db GENERATE_PALETTE(BACKGROUND_PALETTE, true, SPECTRAL_SPRITE_MONOCHROME_PALETTE, true, WRITTER_PALETTE, false)

