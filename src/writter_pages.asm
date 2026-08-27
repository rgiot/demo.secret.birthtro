
/*
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
*/

    repeat 2
        WRITTER_ADD_PAGE_FROM_FILE("writter_page1.txt")
    endrepeat
    WRITTER_ADD_PAGE_FROM_FILE("writter_page2.txt")
    WRITTER_ADD_PAGE_FROM_FILE("writter_page3.txt")
    WRITTER_ADD_PAGE_FROM_FILE("writter_page4.txt")
    WRITTER_ADD_PAGE_FROM_FILE("writter_page5.txt")
    WRITTER_ADD_PAGE_FROM_FILE("writter_page6.txt")



