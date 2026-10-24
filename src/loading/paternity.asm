INKS = load("../../data/loading.inks")

LOCOMOTIVE LOADER_LINKER_ADDRESS, INKS
    10 MODE 0
    20 BORDER {list_get(INKS, 0)}
    30 INK 0,{list_get(INKS, 0)}:INK 1,{list_get(INKS, 1)}
    50 INK 2,{list_get(INKS, 2)}:INK 3,{list_get(INKS, 3)}
    80 INK 4,{list_get(INKS, 4)}:INK 5,{list_get(INKS, 5)}
    100 INK 6,{list_get(INKS, 6)}:INK 7,{list_get(INKS, 7)}
    120 INK 8,{list_get(INKS, 8)}:INK 9,{list_get(INKS, 9)}
    140 INK 10,{list_get(INKS, 10)}:INK 11,{list_get(INKS, 11)}
    160 INK 12,{list_get(INKS, 12)}:INK 13,{list_get(INKS, 13)}
    170 INK 14,{list_get(INKS, 14)}:INK 15,{list_get(INKS, 15)}
    510 EVERY 2 GOSUB 1000
    520 call {LOADER_LINKER_ADDRESS}
    530 run "PATER.000"
    1000 FOR P=10 TO 15
    1010 INK P,INT(RND*27)
    1020 NEXT P
    1030 RETURN
ENDLOCOMOTIVE

    assert $<LOADER_LINKER_ADDRESS
  ;  assert LOADER_LINKER_ADDRESS - $ < 10

    org LOADER_LINKER_ADDRESS
    incbin "LOADER.BIN"