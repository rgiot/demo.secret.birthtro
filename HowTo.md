The aim of this document is to help to modify the code and assets.

# How to test the demo

Use the `test_sna` rule in the bndbuild file of `src` folder.
It will rebuild the snapshot of the demo if needed and launch it from ace emulator.

In a terminal, from `src` folder :

```bash
$ bndbuild test
```



In vscode with the appropriate extension installed, click on the "Run: test" button


# How to really run the demo

The former way is the quick and dirty way to test the demo.
For a real world usage, we have to link the demo, create the dsk and launch if from the dsk.
It way notwork as it impact the linking that as been hand coded for a specific state of the demo. It may have to be adapted depending on crunch sizeevolution

this time the rule to test is `test_dsk`

# How to change the music

Current music is played with Arkos Generic Player. We can change it without any issue.
But ATM the music must be written with AT3 and exported in AKG format, with source format and configuration file exported.

In `src/build.bnd` search for these lines

```jinja2
{% set MUSIC_DATA="../data/music/ops.asm" %}
{% set MUSIC_CFG="../data/music/ops_playerconfig.asm" %}
```

and replace the paths by the new file names.


# How to specify colors


**Note** At the moment the demo has only one colorscheme. Of course we could use several later and change them on the fly.
So it is possible to provide several versions of palette.asm and let Krusty handle the marge later

Most of the time colors have to be specified using their ga arary values. no need to remember well, you can use symbols instead

With `BASIC_COLOR_0`, ..., `BASIC_COLOR_27`
or the name of the left:

```
GA_BLACK    set GA_COL_00 
GA_BLUE set GA_COL_01 
GA_BRIGHT_BLUE  set GA_COL_02 
GA_RED  set GA_COL_03 
GA_MAGENTA  set GA_COL_04 
GA_MAUVE    set GA_COL_05 
GA_BRIGHT_RED   set GA_COL_06 
GA_PURPLE   set GA_COL_07 
GA_BRIGHT_MAGENTA   set GA_COL_08 
GA_GREEN    set GA_COL_09 
GA_CYAN set GA_COL_10 
GA_SKY_BLUE set GA_COL_11 
GA_YELLOW   set GA_COL_12 
GA_WHITE    set GA_COL_13 
GA_PASTEL_BLUE  set GA_COL_14 
GA_ORANGE   set GA_COL_15 
GA_PINK set GA_COL_16 
GA_PASTEL_MAGENTA   set GA_COL_17 
GA_BRIGHT_GREEN set GA_COL_18 
GA_SEA_GREEN    set GA_COL_19 
GA_BRIGHT_CYAN  set GA_COL_20 
GA_LIME set GA_COL_21 
GA_PASTEL_GREEN set GA_COL_22 
GA_PASTEL_CYAN  set GA_COL_23 
GA_BRIGHT_YELLOW    set GA_COL_24 
GA_PASTEL_YELLOW    set GA_COL_25 
GA_BRIGHT_WHITE set GA_COL_26 
```

# How to change the background and moving eyes sprites

In `src/build.bnd` search for these lines and update them if needed

```jinja2
{% set FACE="face3" %} # Change here the prefix of the background if needed to change the picture
{%set SPRITE0_WIDTH=48//2 %} # Number of bytes  in the width of the sprite (we obtain the number of pixels by multiplying it by 4)
{%set SPRITE0_HEIGHT=44 %} # Number of lines of the sprite
{%set SPRITE0_X_OFFSET=10 %} # horizontal position in byte (so *2 to get the number of pixels) from left of the screen
{%set SPRITE0_Y_OFFSET=50 %} # vertical position in pixel from top of the screen
```
They allow to setup the base name of the files to load size of the eye sprites in case it is changed.

if `FACE` is `face3`, the following files will be used by the demo:
`data/face3_cpc.pal`, `data/face3_cpc.scr`, `data/face3_eye0.spr`, `data/face3_eye1.spr`, `data/face3_eye2.spr`.
The are automatically generate from the PC images. The current build system assumes there are 3 images in the animation (including the one already in the full picture).
Of course it is doable to have more steps (I'm pretty sure it will even speed up the display). Krusty can adapt everything if needed.

The rules to build these these files are in `data/build.bnd`. If you edit the very same images, there is nothing to change.
If your PC image differ, copy paste the rules and moify all file names in tgt, dep, cmd items.
If there are more images in the animation jsut duplicate the line that convert an eye.
ATM everything is hardcoded for Baby_Face_v3.bmp, face3_eye0.png, face3_eye1.png, face3_eye2.png with the **same palette**, **4 inks** and **no pixel duplication to micmick mode 0** (as it is the way voxy shared is picture).

# How to change the spectral sprites logo

Warning the change of the logo impact the duration of the rendering.
It may break some timing and the demo. In that case Krusty could try to fix without any guarantees.
So you can still propose logos that broke stuff.

The logo is written in the asm source code in `src/spectral_sprites_logo.asm`
Just modify the strings content and use space for no pixel, # for pixel.
It can be more visible if you ask your editor to search for # as it will be highlighted.
The "pixels" are not drawn as square in the demo, so take that into account

```
spectral_sprites_model equ [
    "####    ####    ####  ",
    "##  ##  ##  #   ##  ##",
    "####    ##  ##  ##  ##",
    "##  ##  ##  ##  ##  ##",
    "####    ##  ##  ####  "
]

```

Palette has to be setup in `src/palettes.asm` in these two arrays that are self-explicit

```z80
SPECTRAL_SPRITES_PALETTE equ [0x58, 0x45, 0x4d, 0x4f ]   ; 4 inks in a list 
SPECTRAL_SPRITES_MONOCHROME_PALETTE equ [0x4f, 0x4f, 0x4f, 0x4f] 
```


# How to change the writter font

The font has to be coded in the source file too: `src/writter_font.asm`.
Each char can have a **different number of pixels** horizontally as soon as all lines of a given char share the same number of pixels and **8 lines**. We can use **lowercase** and **uppercase** chars

You can modify existing chars, or create new char that are not yet encoded.
To encode a char respect the syntax:

```
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
```

`i` represents a char, and the next lines represent the pixels. space or #.
Ideally the last line needs to be empty expect for long chars in order to have a visual spearation between rows. At least one column should be empty to visially spearate chars in  a row. 
But this is a matter of design.

i and I would be two different chars.

To be usable the chars needs to registered

```z80
WRITTER_MAPPING
    WRITTER_MAPPING_GENERATE("ari")
```
means only a, r, i are usable in addition of space. If more chars are encoded, they need to be added to the string.




Palette has to be setup in `src/palettes.asm` here

```z80
WRITTER_PALETTE equ 0x4A  
```

# how to change the content of the writter pages

Everything is in `src/writter_page.asm`.

```
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
```

defines a page named WRITTER_PAGE2 with its content that will be rendered centered.
Each line beign an argument encoded in the string. stricly **10**. I do not know the number max of chars in a row, as it depends on their width.

All pages need to be registered to be displayed:

```
WRITTER_PAGES
    dw WRITTER_PAGE0
    dw WRITTER_PAGE1
    dw WRITTER_PAGE2
    dw 0
```

# How to change the fonts of the scroller

There are 2 fonts in the scroller

- IPM cult like font that uses the out precision that needs to be the same for the few exisitng chars and created similarly for the other
- birthro font that uses the nop precision instead of the out precision

all modifications have to be coded in `src/split_scroller_font.asm` and ipm/birthro fonts are coded in a differnt way.

an ipm char is coded like that
```z80
		FONT_CREATE_IPM_CHAR( s,
			"###.",
			"#...",
			"#...",
			"###.",
			"..#.",
			"..#.",
			"..#.",
			"###."
		)
```
you provide the  letter (in lower case) and the height lines of 4 columns. Here each `#` represents a 4 nops  wide pixel.

a birthro char is coded like that

```z80
		FONT_CREATE_CHAR( s,
			".###########....",
			"####............",
			"####............",
			".##########.....",
			"........####....",
			"........####....",
			"........####....",
			"###########....."
		)
```

you provide the char (also in lowercase) and the height lines.
There are various constraints, if you do not respect them, the assembler fails. I suggest to assemble regularly. Here each `#` represents a 1 nop  pixel.
Here are the constraints to respect:

- The first `#` of the line can start at any horizontal position
- Each line must end by at least 4 spaces
- you need at least 4 spaces before setting a `#` (expect at the very beginning of a line)
- you need at least 4 `#` before setting a space


If the birthro char is exactly the same than the ipm char, state it explicitly without drawing it a second time with another encoding

```z80
	NOP_FONT_SAME_AS_IPM(t)
```


There is another constraint too each char defined as ipm must be defined as birthro too (and vice versa).
So the best is probably to write first the IPM version of each char, use NOP_FONT_SAME_AS_IPM to duplicate them for birthro and progressively remove the duplication with handwritten variant that use the nop resolution.



The font as to be registered

Palette has to be setup in `src/palettes.asm` here



```z80
SCROLLER_PALETTE equ [
        GA_COL_09,
		GA_COL_10,
		GA_COL_18,
		GA_COL_20,
		GA_COL_20,
		GA_COL_18,
		GA_COL_10,
		GA_COL_09
]
```

There is a single color per block line. It is technically impossible to have one color per line as in IPM cult

# How to change the content of the scroller

The content is in `src/split_scroller_text.asm`.
switch between lower/upper case to select ipm/birthro font