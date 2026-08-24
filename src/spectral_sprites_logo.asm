;; Texture in the background
;; XXX this is here a graphician can work.
;;     Note that blocs are not suare and duplicated.
;;     if needed, remove the call to double_columns and manually duplicate the line to double the horizontal resolution
;; use " " for an empty bloc
;; use "#" for a drawn bloc


SELECTED_LOGO=3

switch  SELECTED_LOGO
case 0:

    spectral_sprites_model equ [
        "####    ####    ####  ",
        "   ##   ##  #       # ",
        "####    ##  ##  ##  ##",
        "##  ##  ##  ##  ##  ##",
        "#####   ##  ##  ####  "
    ]

break
case 1:

    spectral_sprites_model equ [
        "##  ####   ##    ###  ",
        "    #   #   #   ##    ",
        "##      ##       #### ",
        "##      ##          ##",
        "##      ##      ##### "
    ]
break
case 2:

 spectral_sprites_model equ [
     "         ####         ",
     "            ##        ",
     "        ######        ",
     "        ##  ##        ",
     "        ##  ##        "
 ]

break
case 3:


 spectral_sprites_model equ [
     "####     ####   ##  ##",
     "   ##       ##  ##  ##",
     "####    ##  ##   #### ",
     "##  ##  ##  ##    ##  ",
     "####     ####     ##  "
 ]

 endswitch