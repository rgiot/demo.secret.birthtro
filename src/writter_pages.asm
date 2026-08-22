

; The very virst page is no tvisible at all
; we don't care of its content
WRITTER_PAGE0
    WRITTER_ENCODE_PAGE(
        "abcdefghijklmnopqrstuvwxyz",
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
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
        "abcdefghijklmnopqrstuvwxyz",
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
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
