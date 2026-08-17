;;
;; public part of HBL demosystem
;; Macros to use the the demosystem.
;; Here most thing are ultra specific to the demosystem
;;
;; This one targets a file loading with the firmware.
;; So not really usable in a huge demo

    include "common.asm"
    include "demosystem_config.asm"
    include "booster.asm"

DS_MAIN_SPACE_GA equ 0xc0
DS_BOOTSTRAP_DS_SPACE_GA equ 0xc1
DS_FULL_SPACE_GA equ 0xc2

DS_LOADER_OPTION_NONE equ 0
DS_LOADER_OPTION_REQUEST_DRIVE_MOTOR_ON equ (1<<0)
DS_LOADER_OPTION_REQUEST_DRIVE_MOTOR_OFF equ (1<<1)
DS_LOADER_OPTION_DISABLE_SYSTEM_RESTORATION equ (1<<2)

__DS_FILE_LOADING_ROUTINE__    equ &e000 + 0*3
__DS_BACKUP_FIRMWARE_ROUTINE__ equ &e000 + 1*3
__DS_SAVE_SCREEN_MODE__         equ &e000 + 2*3
__DS_COPY_FROM_EXTRA_TO_MAIN__ equ &e000 + 3*3

DS_LOAD_ADDRESS equ __DS_FILE_LOADING_ROUTINE__
DS_LOAD_ADDRESS_FROM_DEMO_SPACE = DS_LOAD_ADDRESS % 0x4000 + 0x4000 ; Convert the address in the demo space


;; The minmum address available to load a file in the main memory.
DS_FIRST_AVAILABLE_ADDRESS equ &300
__DS_FIRST_BANK_SIZE__ equ &4000 - DS_FIRST_AVAILABLE_ADDRESS ; The maximum number of bytes avaialble in the first bank

;;
;; This macro should be called at the very beginning of the demo.
;; it aims at checking the kind of device use to load
macro DS_INITIALIZATION
    DS_PRIVATE_CPCBOOSTER_INIT_COMMUNICATION() ; setup the booster if flag activated
    DS_BACKUP_FIRMWARE()
endm


;;
;; Select a memory space for the demo
;; Completly relocatable code
macro DS_SELECT_A_MEMORY_SPACE space
    assert {space} >= 0xC0 and {space} <= 0xc7
    ld bc, &7f00 + {space} : out (c),c  
endm

macro DS_SELECT_DS_BOOTSTRAP_SPACE
    DS_SELECT_A_MEMORY_SPACE(DS_BOOTSTRAP_DS_SPACE_GA)
endm

macro DS_SELECT_MAIN_SPACE
    ; TODO allow to select a different bank
    DS_SELECT_A_MEMORY_SPACE(DS_MAIN_SPACE_GA)
endm

macro DS_SAVE_SCREEN_MODE mode
    assert {mode} == &8c || {mode} == &8d || {mode} == &8e
    di
        DS_SELECT_DS_BOOTSTRAP_SPACE() 
        ld a, {mode}
        call __DS_SAVE_SCREEN_MODE__
        DS_SELECT_MAIN_SPACE()
    ei
endm

;;
;; Request the demosystem to load a file.
;; This macro must be called when being in space &c0
;; The process to load a file is the following:
;; - memory conf. in &C1
;; - restore the system
;; - memory conf in &C2
;; - load the file
;; - backup the system
;; - memory conf in C1
;; - restore the normal stack
;; - memory conf in &C0
;;
;; In case of failure the program is stucked
;; In case of success:
;;  - page 1 contains the loaded file
;;  - bc contains the length of the file
;;  - de contains the expected destination of the file
;;
;; Input:
;;  - filename: address to the filename
;;  - address: loading address IN THE EXTRA page
macro DS_LOAD_FILE_IN_EXTRA_PAGE filename, filename_size, address, loading_options
    __DS_LOAD_FILE_IN_EXTRA_PAGE_INNER__({filename}, {filename_size}, {address}, true, {loading_options})
endm

;;
;; Private macro. Do not use directly
;; Load a file and optionnaly restore &C0
macro __DS_LOAD_FILE_IN_EXTRA_PAGE_INNER__ filename, filename_size, address, restore_bank, loading_options

    assert {filename} < 0xC000, "The filename cannot be in the address space [&C000-&FFFF] because we switch of bank"

    ; TODO add memory check to ensure we do no load in restricted areas

    assert $<0xC000, "You cannot be here as we will switch in &C1 and &C2 configurations" ; TODO use a real filtering adress bacause we do not have to be so pedantic
    assert {filename_size} > 0, "You need a file name"

    DS_SELECT_DS_BOOTSTRAP_SPACE() 

        ld hl, {filename}
        ld de, {address}
        ld bc, {filename_size}*256 + {loading_options}
        call DS_LOAD_ADDRESS

    if {restore_bank}
        push bc
            DS_SELECT_MAIN_SPACE()
        pop bc
    endif
endm

;;
;; Load first the file in extra page.
;; Once done, move it, in the main memory.
;; This is a slow process as each byte has to pass over a buffer
;; TODO handle a fast copy for bytes NOT in &4000-&7fff space as they can skip the buffer
;; TODO handle case where the memory is overriden by the loaded file
macro DS_LOAD_FILE_IN_MAIN_PAGE filename_addr, filename_size, load_address, loading_options
    ; Load the file and stay in the extra memory configuration
    __DS_LOAD_FILE_IN_EXTRA_PAGE_INNER__({filename_addr}, {filename_size}, DS_FIRST_AVAILABLE_ADDRESS, false, {loading_options})
    
    ; By construction BC contains the number of byte read
    ld hl, DS_FIRST_AVAILABLE_ADDRESS
    ld de, {load_address}
    call __DS_COPY_FROM_EXTRA_TO_MAIN__

    DS_SELECT_MAIN_SPACE()

endm

;;
;; Load first the file in extra page.
;; Once done, move it, in the main memory.
;; This is a slow process as each byte has to pass over a buffer.
;; Then launch it
;; TODO handle a fast copy for bytes NOT in &4000-&7fff space as they can skip the buffer
;; TODO handle case where the memory is overriden by the loaded file
macro DS_LOAD_AND_RUN_FILE_IN_MAIN_PAGE filename, filename_size, load_address, exec_address, loading_options

    DS_LOAD_FILE_IN_MAIN_PAGE( {filename}, {filename_size}, {load_address}, {loading_options})
    jp {exec_address}
	assert $<={load_address}

endm



;;
;; Ensure the demosystem will not write anywhere
;; It is probably mandatory using C1 as any print will destroy the demosystem
macro DS_MAKE_FIRMWARE_QUIET
    di

        ; Coupe tout son et on s'assure qu'aucun
        ; évènement sonore est en cours de traitement
        call &bca7 ; SOUND RESET
        ; Purge de tout appui de touche en cours de traitement
        call &bd3d ; KM FLUSH
        ; Désactive complètement de la gestion du clavier
        ld a,&c9 ; RET
        ld (&bdf4),a ; KM SCAN KEYS
        ; Désactive les messages d'erreur disquette
        ; de cette façon, les erreurs ne sont plus bloquantes
        ; et les messages d'erreur ne sont plus affichés
        ld a,&ff ; &ff = Désactivé
        ld (&be78),a
        ; Désactive le clignotement des couleurs
        ld hl,&b7f9 ; HL = Event block des couleurs
        call &BCDD ; KL_DEL_FRAME_FLY
        ; Désactive tout affichage (au cas où)
        call &BB57 ; TXT_VDU_DISABLE

    ei
endm


;;
;; Copy something loaded in the extra memory into the main memory
macro DS_COPY_MEMORY_FROM_EXTRA_PAGE_TO_MAIN_PAGE from, to, page, size

    @from_until = {from} + {size}
    @to_until = {to} + {size}

    assert {from} >= 0x4000 and {from} < 0x8000 and  @from_until >= 0x4000 and @from_until < 0x8000, "You can copy at maximum 0x4000 bytes, from [0x4000;0x8000["
    assert ({to} < 0x4000 || {to} >= 0x8000) and (@to_until < 0x4000 || @to_until >= 0x8000), "You can paste only outside of [0x4000;0x8000["


    DS_SELECT_A_MEMORY_SPACE({eval}{page})

    ld bc, {size}
    ld de, {to}
    ld hl, {from}
    ldir

    DS_SELECT_MAIN_SPACE()
    

endm

;;
;; Backup the firmware.
;; Has to be called one time at the beginning of the demo.
macro DS_BACKUP_FIRMWARE
    DS_SELECT_DS_BOOTSTRAP_SPACE() 
        di
            call __DS_BACKUP_FIRMWARE_ROUTINE__
        ei
    DS_SELECT_MAIN_SPACE()
endm

