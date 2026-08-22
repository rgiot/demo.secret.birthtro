# Birthtro Demo — How to Modify and Build

This guide helps graphicians and non-programmers customize the demo: change colors, backgrounds, sprites, music, text, and more.

---

## Quick Start — Test the Demo

To rebuild and run the demo quickly in an emulator:

```bash
cd src
bndbuild test_sna
```

This compiles the demo and launches it in the emulator. It takes a few seconds the first time (rebuilds changed assets), then only rebuilds what changed.

**Alternatively, from VS Code:** Click the **"Run: test_sna"** button if you have the build extension installed.

---

## Understanding the Build System

XXX: AI generted crap ;) title are wrong, but content is ok...

The build system has three layers:

1. **User configuration** (`src/build.bnd`)
   - You edit *variables* here (which sprites to use, sprite position/size)
   - Example: `{% set FACE="face3" %}` means "use face3_cpc.scr, face3_cpc.pal, face3_eye*.spr"

2. **Automatic asset generation** (`data/build.bnd`)
   - Converts image files (BMP, PNG) to CPC format (.scr, .pal, .spr)
   - Happens automatically when you change images

3. **Compilation & linking** (`src/*.asm`)
   - Assembly compiler reads all files and produces the snapshot
   - Injected variables from step 1 tell it which .scr/.pal/.spr files to use

**The workflow:**
```
Edit src/build.bnd (change FACE variable)
    ↓
Run: bndbuild test_sna
    ↓
Build system finds face3_cpc.scr, face3_cpc.pal, face3_eye0/1/2.spr
    ↓
Assembler includes them in the snapshot
    ↓
birthtro.sna is created and runs in emulator
```

---

## Common Tasks

### Task 1: Change Palette Colors

**What you're doing:** Changing which colors the demo uses.

**Where to work:**
- Your PC image files: `data/Baby_Face_v3.bmp` (background), `data/face3_eye*.png` (sprites)
- The palette is **automatically extracted** from the main image

**Steps:**

1. Edit your image files (Photoshop, GIMP, etc.)
   - Edit `Baby_Face_v3.bmp` to change backgropixels/und colors
   - Edit `face3_eye0.png`, `face3_eye1.png`, `face3_eye2.png` to change eye sprite pixels with the same colors
   - ⚠️ **Important:** Keep to **4 colors max** in each image (CPC Mode 0 limitation)

2. Save your images in the same location (`data/` folder)

3. Rebuild:
   ```bash
   cd src
   bndbuild test_sna
   ```

4. The build system automatically converts your images to CPC format, extracts colors, and rebuilds the demo.

**What happens behind the scenes:**
- `img2cpc` converts your BMP to screen data (`.scr`) and palette (`.pal`)
- Your PNG sprites are converted to `.spr` files using the palette from the background
- The compiler reads these files and includes them in the snapshot

---

### Task 2: Change Background & Eye Sprites (Pick a Different Face)

**What you're doing:** Switching to a different set of background + sprite images.

**Current setup:** Uses "face3" files (face3_cpc.scr, face3_cpc.pal, face3_eye0/1/2.spr)

**To use a different face:**

1. **Option A: Use an existing face** (if face0, face2, etc. already exist in `data/`)
   
   Edit `src/build.bnd` and change:
   ```jinja2
   {% set FACE="face3" %}  →  {% set FACE="face0" %}
   ```
   
   Then rebuild:
   ```bash
   cd src
   bndbuild test_sna
   ```

2. **Option B: Create a new face from scratch**
   
   a. Prepare two sets of images:
      - `Baby_Face_NEW.bmp` — the background (320×200 pixels, mode 0 → 4 colors max)
      - `NEW_eye0.png`, `NEW_eye1.png`, `NEW_eye2.png` — three animation frames (same palette)
   
   b. In `data/build.bnd`, add a new rule. Copy this block and update the filenames:
      ```bnd
      - tgt: faceNEW_cpc.scr faceNEW_cpc.pal
        dep: Baby_Face_NEW.bmp
        cmd: 
          - img2cpc --mode 0 --overscan  Baby_Face_NEW.bmp scr  --output faceNEW_cpc.scr --palette faceNEW_cpc.pal

      - tgt: faceNEW_eye0.spr faceNEW_eye1.spr faceNEW_eye2.spr
        dep: faceNEW_eye0.png faceNEW_eye1.png faceNEW_eye2.png faceNEW_cpc.pal
        cmd:
          - img2cpc --mode 0 --ga-pal faceNEW_cpc.pal faceNEW_eye0.png sprite --output faceNEW_eye0.spr
          - img2cpc --mode 0 --ga-pal faceNEW_cpc.pal faceNEW_eye1.png sprite --output faceNEW_eye1.spr
          - img2cpc --mode 0 --ga-pal faceNEW_cpc.pal faceNEW_eye2.png sprite --output faceNEW_eye2.spr
      ```
   
   c. In `src/build.bnd`, change:
      ```jinja2
      {% set FACE="face3" %}  →  {% set FACE="faceNEW" %}
      ```
   
   d. Also adjust sprite dimensions in `src/build.bnd` if needed:
      ```jinja2
      {%set SPRITE0_WIDTH=48//2 %}   # Eye width in bytes (pixels = bytes × 4)
      {%set SPRITE0_HEIGHT=44 %}     # Eye height in lines
      {%set SPRITE0_X_OFFSET=10 %}   # Horizontal position (in bytes, × 2 for pixels)
      {%set SPRITE0_Y_OFFSET=50 %}   # Vertical position (in pixels from top)
      ```
   
   e. Rebuild:
      ```bash
      cd src
      bndbuild test_sna
      ```

**Sprite constraints:**
- All three animation frames (eye0, eye1, eye2) must have **the same width, height, and position**
- Each sprite must use **the same 4-color palette** as the background
- No pixel duplication or mode 1/2 conversions — images are used as-is

# How to change the music

Current music is played with Arkos Generic Player. We can change it without any issue.
But ATM the music must be written with AT3 and exported in AKG format, with source format and configuration file exported.

In `src/build.bnd` search for these lines

```jinja2
{% set MUSIC_DATA="../data/music/ops.asm" %}
{% set MUSIC_CFG="../data/music/ops_playerconfig.asm" %}
```

and replace the paths by the new file names.

---

### Task 3: Change Music

**To change music:**

1. Create your music file in AT3 format (e.g., with Arkos Tracker)

2. Export it as:
   - `YOUR_SONG.asm` — the music data
   - `YOUR_SONG_playerconfig.asm` — the player configuration

3. In `src/build.bnd`, change:
   ```jinja2
   {% set MUSIC_DATA="../data/music/ops.asm" %}
   {% set MUSIC_CFG="../data/music/ops_playerconfig.asm" %}
   ```
   
   to:
   ```jinja2
   {% set MUSIC_DATA="../data/music/YOUR_SONG.asm" %}
   {% set MUSIC_CFG="../data/music/YOUR_SONG_playerconfig.asm" %}
   ```

4. Rebuild:
   ```bash
   cd src
   bndbuild test_sna
   ```


---

### Task 4: Change Writter Font (Text Font)

**What you're doing:** Modifying the custom pixel font used for text display.

**Font file:** `src/writter_font.asm`

**To edit a character:**

In `src/writter_font.asm`, find the character you want to change. Each character is defined like:

```asm
WRITTER_CREATE_CHAR(
    i,                  # Character ID
    " ##  ",           # Row 1 (space = empty pixel, # = filled pixel)
    "     ",           # Row 2
    "###  ",           # Row 3
    " ##  ",           # Row 4
    " ##  ",           # Row 5
    " ##  ",           # Row 6
    "#### ",           # Row 7
    "     "            # Row 8 (usually empty for spacing)
)
```

**To create a new character:**

1. Find an unused character ID (check existing IDs in the file)
2. Add a new `WRITTER_CREATE_CHAR` block with 8 rows
3. Use space (` `) for empty pixels, `#` for filled pixels
4. Below the font definitions, register your new characters:
   ```asm
   WRITTER_MAPPING
       WRITTER_MAPPING_GENERATE("ari")  # Add your new char IDs here
   ```

**Character design tips:**
- Each character can have a different width (but all rows must match)
- Use 8 lines (required)
- Leave the last row empty for spacing between lines (you can still use it if necessary)
- Leave at least one empty column for spacing between characters (you can still use it if necessary)

**Rebuild:**
```bash
cd src
bndbuild test_sna
```

---

### Task 5: Change Writter Text Content

**What you're doing:** Changing the text that appears on screen.

**File:** `src/writter_pages.asm`

**To change the text:**

Find the `WRITTER_PAGE` you want to edit and change the strings:

```asm
WRITTER_PAGE1
    WRITTER_ENCODE_PAGE(
        " a ",           # Page title or first line
        " r ",
        " i ",
        "                   ",  # Blank line
        "ariariariariariariariari",  # Text line
        "rr iiii",
        "rrrrr iiii",
        ...
    )
```


As char width is variable, you can have a avariable number of chars per line. Text is pixel centered.

**Rebuild:**
```bash
cd src
bndbuild test_sna
```

---

### Task 6: Change Scroller Fonts (Top Scroller Text)

**What you're doing:** Modifying the pixel fonts used for the top scroller text display.

**Font file:** `src/split_scroller_font.asm`

**To edit a character:**

The scroller uses two font variants for smooth animation:
- **IPM precision** (4-nop pixels) — slower scroll, smoother animation
- **NOP precision** (1-nop pixels) — faster scroll

Character definitions use `#` for pixels and `.` for empty:

```asm
FONT_CREATE_IPM_CHAR( a,
    ".#..",      # Row 1 (4 pixels wide for IPM)
    "#.#.",      # Row 2
    "#.#.",
    "###.",
    "#.#.",
    "#.#.",
    "#.#.",
    "#.#."
)
```

**To create a new character:**

1. Define the IPM precision version with `FONT_CREATE_IPM_CHAR` (8 rows, 4 columns):
   ```asm
FONT_CREATE_IPM_CHAR( yourchar,
    ".#..",      # Row 1 (4 pixels wide; . = empty, # = filled)
    "#.#.",      # Row 2
    "#.#.",
    "###.",
    "#.#.",
    "#.#.",
    "#.#.",
    "#.#."
)
   ```

2. Define the NOP precision version. Either **reuse the same design** by strictly doing nothing.
   Or write a **different, more detailed design** with `FONT_CREATE_CHAR` (1-nop pixels, same 8 rows):
   ```asm
FONT_CREATE_CHAR( yourchar,
    "....####........",   # Each # is 1 nop wide — much finer detail possible
    ".##########.....",
    "####....####....",
    "####....####....",
    "############....",
    "####....####....",
    "####....####....",
    "####....####...."
)
   ```
   
   
   Write a `FONT_CREATE_CHAR` when you want a sharper, more detailed variant (as is done for `a` and `i` in the current font file).

   If you design a nop precise character that **is not** present in the IPM variant,
   you also have to register it (x is like that for example): `FONT_REGISTER_NOP_CHAR(X)` (respect the uppercasing).


I strongly suggest to create a NOP variant char from the IPM variant in order to keep a bit of consistency. But it's not mandatory.

So from 
```
FONT_CREATE_IPM_CHAR( c,
   "###.",
   "#.#.",
   "#...",
   "#...",
   "#...",
   "#...",
   "#.#.",
   "###."
)
```

we can create the very same one as a nop precise variante byt repeating each char 4 times (vscode cna do itself if you ask "repeat each caracter of each string 4 times")

```
FONT_CREATE_CHAR( c,
   "############....",
   "####....####....",
   "####............",
   "####............",
   "####............",
   "####............",
   "####....####....",
   "############...."
)
```
And then you can arve a bit inside to make it a bit smoother

```
FONT_CREATE_CHAR( c,
   ".##########.....",
   "####....####....",
   "####............",
   "####............",
   "####............",
   "####............",
   "####....####....",
   ".##########....."
)
```

it is thuse more clever to design the IPM variant first (or keep the one I have made by cloning the oriignal version)

**Character design constraints (both variants):**
- All 8 rows must have the same total nop duration
- Lines must end with `.` pixels (not `#`)
- The first `#` can be anywhere on the line (leading `.` run has no minimum length)

**Additional constraint for `FONT_CREATE_IPM_CHAR`:**
- Exactly 4 columns per row (each column = 4 nops internally)
- Minimum 2 columns (= 8 nops) for 8-frame drawing animation

**Additional constraint for `FONT_CREATE_CHAR` (NOP precision):**
- Any run of `.` or `#` after the first `#` must be **at least 4 symbols long** (each symbol = 1 nop)
- Minimum 8 symbols total width

**Rebuild:**
```bash
cd src
bndbuild test_sna
```

---

### Task 7: Change Scroller Text Content

**What you're doing:** Changing what text scrolls.

**File:** `src/split_scroller_text.txt`

**To change the text:**

Just edit the file using ASCII chars.
You can use several lines if needed.
Tink to add a space at the end of a line if you want to spearte last car of a line from first char of the next line.

**Text case note:** The scroller switches fonts based on uppercase/lowercase:
- Uppercase letters use IPM precision (blocky - oldschool)
- Lowercase letters use NOP precision (smoother - newschool)

**Rebuild:**
```bash
cd src
bndbuild test_sna
```

---

### Task 8: Change Scroller Color Palette

**What you're doing:** Switching between two scroller color schemes.

**File:** `src/split_scroller.asm` (line ~842)

**Available palettes:**

1. **SCROLLER_COLORED_PALETTE** (current default)
   ```
   GA_COL_09, GA_COL_10, GA_COL_18, GA_COL_20,
   GA_COL_20, GA_COL_18, GA_COL_10, GA_COL_09
   ```

2. **SCROLLER_MONOCHROME_PALETTE**
   ```
   GA_BRIGHT_WHITE (repeated 8 times)
   ```

**To switch palettes:**

In `src/split_scroller.asm`, find this section (around line 842):

```asm
.selected_scroller_palette equ $-2
    db SCROLLER_MONOCHROME_PALETTE  # Change this line
    db SCROLLER_COLORED_PALETTE
```

Change `SCROLLER_MONOCHROME_PALETTE` to `SCROLLER_COLORED_PALETTE` or vice versa.

**To create a custom palette:**

1. In `src/palettes.asm`, add a new palette definition:
   ```asm
   SCROLLER_CUSTOM_PALETTE equ [
       GA_COL_01,
       GA_COL_02,
       GA_COL_03,
       GA_COL_04,
       GA_COL_04,
       GA_COL_03,
       GA_COL_02,
       GA_COL_01
   ]
   assert list_len(SCROLLER_CUSTOM_PALETTE) == 8, "Must be 8 inks"
   ```

2. In `src/split_scroller.asm`, use it:
   ```asm
   .selected_scroller_palette equ $-2
       db SCROLLER_CUSTOM_PALETTE
       db SCROLLER_COLORED_PALETTE
   ```

3. Rebuild:
   ```bash
   cd src
   bndbuild test_sna
   ```

---

### Task 9: Change Spectral Sprites Logo (Animated Logo)

**What you're doing:** Modifying the animated pixel logo pattern.

**File:** `src/spectral_sprites_logo.asm`

**To edit the logo:**

Find the `spectral_sprites_model` and edit it:

```asm
spectral_sprites_model equ [
    "####    ####    ####  ",
    "##  ##  ##  #   ##  ##",
    "####    ##  ##  ##  ##",
    "##  ##  ##  ##  ##  ##",
    "####    ##  ##  ####  "
]
```

**Logo design tips:**
- Use `#` for filled pixels, space for empty
- Each line can be any width
- All lines in one logo must have same width
- Pixels are drawn as circles, not squares
- ⚠️ **WARNING:** Changing logo size can break animation timing. Test carefully and may require Krusty to adjust memory layout.

**Rebuild:**
```bash
cd src
bndbuild test_sna
```

---

## Reference: Color System

### GA Color Constants

The CPC uses a color palette called the "Gate Array" (GA). Colors are referenced as GA values (0-27):

```
GA_BLACK (0)          GA_RED (3)           GA_GREEN (9)         GA_YELLOW (12)
GA_BLUE (1)           GA_MAGENTA (4)       GA_CYAN (10)         GA_WHITE (13)
GA_BRIGHT_BLUE (2)    GA_MAUVE (5)         GA_SKY_BLUE (11)     GA_PASTEL_BLUE (14)
...and more (see src/palettes.asm for full list)
```

### Available GA Colors

```
GA_COL_00 to GA_COL_27  # 28 distinct colors on the CPC
GA_BRIGHT_WHITE, GA_BLACK  # Special named colors
```

### Palette Composition

The demo uses `GENERATE_PALETTE()` to create 16-ink palettes dynamically:

- **Inks 0-3:** Background colors (4 inks)
- **Inks 4-7:** Sprite colors (4 inks)
- **Inks 8-15:** Writter font colors (8 inks)

Each layer can be shown or hidden independently.

### Scroller Palettes

The scroller has two pre-defined palette styles (8 inks each):

1. **SCROLLER_COLORED_PALETTE** — Gradient blend (GA_COL_09-20)
2. **SCROLLER_MONOCHROME_PALETTE** — White only

---

## Troubleshooting

### "Image must be 192x168"
Make sure your background BMP is exactly **192 pixels × 168 pixels**. Use your image editor to resize if needed.

(in fact we can double the pixels without issue)

### "Image must have 4 colors max"
Count unique colors in your image:
- Photoshop: Window → Color → check swatches
- GIMP: Image → Mode → check indexed color palette

### "Sprites have mismatched dimensions"
All three animation frames (eye0, eye1, eye2) must be:
- Same width (in pixels)
- Same height (in pixels)
- Same offset position (X, Y)

Adjust `src/build.bnd` if you change sprite size:
```jinja2
{%set SPRITE0_WIDTH=48//2 %}    # Width in bytes
{%set SPRITE0_HEIGHT=44 %}      # Height in lines
{%set SPRITE0_X_OFFSET=10 %}    # X position (in bytes)
{%set SPRITE0_Y_OFFSET=50 %}    # Y position (in pixels)
```

### "Build fails with 'size crunch'"
The demo has hard-coded memory layout for linking. If you add too much code/data, it may exceed available RAM. Contact the original creator (Krusty) for memory layout adjustments.

### "Scroller characters appear wrong"
Check these constraints:
- Characters must be **at least 8 nops wide** (for progressive 8-frame drawing)
- All rows must end with **4+ spaces** (timing requirement)
- All rows of one character must have **same duration** (nops)

### "Emulator won't run snapshot"
- Check that `bndbuild test_sna` completed without errors
- Check terminal output for error messages
- Verify all image files exist in `data/` folder

---

## Advanced: Running on Floppy Disk

To create a bootable disk image:

```bash
cd src
bndbuild test_dsk
```

Output: `src/BIRTHTRO.DSK` (ready to run on CPC or emulator)

**Note:** Full linking is involved (may take a minute on first build). Requires hard-coded memory layout—contact Krusty if you add significant code.