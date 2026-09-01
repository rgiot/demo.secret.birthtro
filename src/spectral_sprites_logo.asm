;; Texture in the background
;; XXX this is here a graphician can work.
;;     Note that blocs are not suare and duplicated.
;;     if needed, remove the call to double_columns and manually duplicate the line to double the horizontal resolution
;; use " " for an empty bloc
;; use "#" for a drawn bloc


spectral_sprites_model1 equ [
        "####    ####    ####  ",
        "   ##   ##  #       # ",
        "####    ##  ##  ##  ##",
        "##  ##  ##  ##  ##  ##",
        "#####   ##  ##  ####  "
    ]


spectral_sprites_model2 equ [
        "##  ####   ##    ###  ",
        "    #   #   #   ##    ",
        "##      ##       #### ",
        "##      ##          ##",
        "##      ##      ##### "
    ]

spectral_sprites_model3 equ [
     "         ####         ",
     "            ##        ",
     "        ######        ",
     "        ##  ##        ",
     "        ##  ##        "
 ]

 spectral_sprites_model4 equ [
     "####     ####   ##  ##",
     "   ##       ##  ##  ##",
     "####    ##  ##   #### ",
     "##  ##  ##  ##    ##  ",
     "####     ####     ##  "
 ]


SPECTRAL_LOGOS_MODELS equ [
    spectral_sprites_model1,
    spectral_sprites_model2,
    spectral_sprites_model3,
    spectral_sprites_model4
]