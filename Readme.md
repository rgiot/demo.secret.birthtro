Birthtro for the incomming baby of Eliot

The main ida is to to a modern version of ipm cult.


# IPM-CULT reverse engineering

## CRTC-configuration

- R12R13: 0x3000
- R1: 0x30 / 48 => 96 visible bytes
- R2 :0x32 => 50
- R9: 0x07 => 7
- R6: 0x15 => 21
- R7: 0x1d => 29
- R4: 0x26 => 38
- R3: 0x8 => 8


## split raster scroller

- Simple list of `out(c), [ed]` for displaying the chars bits. 13 of them => 52 nops displayed vs 48 nops visible vs 64 nops available => 12 nops available
- `exx: outi:inc b:nop:exx` to change border color
- ret table to select the routine to run
- however split rasters are display on the whole height of the vertical sine wave => so there are plenty of time lost to do empty splits
- at the end => remove split border state + set border color black
- `ldi : inc hl : inc de` to make it scroll


## Spectral sprite

 - `ld a, (hl): or e | and d : ld (hl), a` for each byte to drw or erase => 5 nops
 - `inc hl` to move to next byte or `ld bc, delta : add hl, bc` to move further (same line or next line)

# Our improvement


## split rasters scroller

- the chars can play with nops, so the code is composed of `nop|out(c), [ed]` depending on the shape of the char. Minimum unit is nop now. I think an extra compensation of 4 nops is needed to have no visual bugs
- last column of a char MUST be empty
- a soft scroll of the code is mandatory as well as a char compensation

For example IPM S is like that if we think in term of OUT

x => out for pixel
o => out for no pixel

```
xxxo
xooo
xooo
xxxo
ooxo
ooxo
ooxo
xxxo
```

But if we think in term of nops, we can think more like that

```
111122223333oooo
1111oooooooooooo
1111oooooooooooo
111122223333oooo
oooooooo3333oooo
oooooooo3333oooo
oooooooo3333oooo
111122223333oooo
```

This is quite blocky. We want to try to improve the situation by adding some nops instead of out when nothing as to be done
Let say . is a not when nothing is displayed and , is a nop when something is displayed. The very same char can be encoded as (by assuming we always start with an empty bloc)



```
1111,,,,,,,,oooo
1111oooo........
1111oooo........
1111,,,,,,,,oooo
........1111oooo
........1111oooo
........1111oooo
1111,,,,,,,,oooo
```

And a rounder version could be obtained easily:



```
.1111,,,,,,,oooo
1111oooo........
1111oooo........
.1111,,,,,,oooo.
........1111oooo
........1111oooo
........1111oooo
1111,,,,,,,oooo.
```



To make the split raster scroller moves from right to left 4nops per 4nops requires a bit of algorithmic and code manipulation generation.

First, the very first instruction of each line MUST be a `out` that selects the start color while being hidden in the monitor plastic. Because this color could live 1 nop only.

The 4 scrolling possibilities to modify the beginning of the routine are :

- `out (c), X | out(c), Y : <others>` =>                   `out (c), Y | <others>`
- `out (c), X | nop : out(c), Y : <others>` =>             `out (c), Y | nop : <others>`
- `out (c), X | nop : nop : out(c), Y : <others>` =>       `out (c), Y | nop : nop : <others>`
- `out (c), X | nop : nop : nop : out(c), Y : <others>` => `out (c), Y | nop : nop : nop : <others>`
- `out (c), X | nop : nop : nop : nop : <others>` =>       `out (c), X |  <others>`


## spectral sprites

- `set n, (hl)| res n, (hl) *2` 4+4 as must be done on 2 bits ... so 8 instead of 5
BUT
 - `set n, (hl)| res n, (hl) * 1` 4 nops for 1 pixel if working with dithering and alternating the pixel of interest on odd/even line