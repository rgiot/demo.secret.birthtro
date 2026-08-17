;;;
;;; Private part of HBL demosystem
;;; &e000-&ffff => demosystem space + bootstrap space
;;; &c000-&dfff => temporary area used to copy data in &4000 area of main memory

;;; demosystem space:
;;; &c000 > SP > &4000 => set to &C000
;;; &c000 > fname stuff < &40 => set to &40

;;;
;;; Tiny demosystem that only serves to load files using the firmware even
;;; after killing the firmware.
;;; Nothing more, nothing less.
;;;
;;; This must not be used directly by the user. 
;;; Assemble it, provide a binary to the user with the macro.asm file that acts as a public API
;;; Everything must be hidden and abstracted.
;;;
;;; ds_c1_XXX must be called from a &c1 context
;;;; ds_c2_XXX must be called from a &c2 context


    include once "public.asm"
    include once "error.asm"

__AMSDOS_STATIC_DATA_ADDRESS__ equ &be40
__AMSDOS_STATIC_DATA_SIZE__ equ &40
__AMSDOS_DYNAMIC_DATA_ADDRESS_PTR__ equ &be7d
__AMSDOS_DYNAMIC_DATA_SIZE__ equ &500
__FIRMWARE_DATA_START__ equ  &a800 ; b000 &b8b4  ;< here we try to collect as much as possible
__FIRMWARE_DATA_END__ equ &be00
__FIRMWARE_DATA_SIZE__ equ __FIRMWARE_DATA_END__ - __FIRMWARE_DATA_START__


__STACK_SIZE__ equ 2*40
__FIRMWARE_STORAGE_SIZE__ equ __FIRMWARE_DATA_SIZE__ + __AMSDOS_STATIC_DATA_SIZE__ + __AMSDOS_DYNAMIC_DATA_SIZE__


__DS_BUFFER_CAS_IN__ equ &170
__DS_FILENAME__ equ __DS_BUFFER_CAS_IN__
;;
; BUFFER TO THE LENGHT OF THE FILENAME
__DS_FILENAME_SIZE__ EQU __DS_FILENAME__ + 256
;;
; LOADING ADDRESS
__DS_LOAD_ADDRESS__ EQU __DS_FILENAME_SIZE__ + 1
__DS_FNAME_BUFFER_SIZE EQU (__DS_LOAD_ADDRESS__+2) - __DS_BUFFER_CAS_IN__

__DS_TRUE_FIRST_AVAILABLE_ADDRESS equ __DS_FNAME_BUFFER_SIZE + __DS_BUFFER_CAS_IN__
assert __DS_TRUE_FIRST_AVAILABLE_ADDRESS <= DS_FIRST_AVAILABLE_ADDRESS

__DS_STACK__ equ &C000
__COPY_BUFFER__ equ &c000
__COPY_BUFFER_SIZE__ equ &2000

__MODE_NUMBER_PTR_6128__ equ 0xB7C3
__MODE_NUMBER_PTR_464__ equ 0xB1C8  

__DS_DEVICE_UNSET__ equ 0
__DS_DEVICE_FLOPPY_DRIVE__ equ 1
__DS_DEVICE_ALBIREO_LIKE__ equ 2

MAKE_FIRMWARE_SILENT equ false
ENABLE_OPTION_LOADER_OPTION_DISABLE_SYSTEM_RESTORATION equ true


    ;;
    ;; Save the stack from the main program, 
    ;; then switch to the demosystem one
    ;; Must be called from &C1
    ;; Modified :
    ;;  - SP
    ;;  - 1 word at (__ds_program_stack_backup__)
    macro __SWITCH_TO_BOOTSTRAP_STACK__
        ld (__ds_bootstrap_program_stack_backup__), sp
        ld sp, __ds_bootstrap_stack__ 
        assert __ds_bootstrap_stack__ > &C000; "The stack needs to be in the same space has we do not force the use of DI"
    endm

    macro __SWITCH_TO_DS_STACK__
        ld (__ds_demosystem_bootstrap_stack_backup__), sp
        ld sp, __DS_STACK__ 
        assert __DS_STACK__ <= &C000 && __DS_STACK__ >= &4000
    endm

    ;;
    ; Stop to use the system stack and go back to the program stack
    ; Must be called from &C1
    macro __SWITCH_TO_PROG_STACK__
        ld sp, (__ds_bootstrap_program_stack_backup__)
    endm

    ;;
    ;; Select the full C2 memory space
    ;; Be careful, di must be set to avoid crash if there is not ei:ret or whatever in 0x38
    macro __DS_SELECT_DS_FULL_SPACE__
        DS_SELECT_A_MEMORY_SPACE(DS_FULL_SPACE_GA)
    endm


    ;;
   ; ; This macro works when system has been saved
    macro __DS_FIRMWARE_CHECK_IF_FLOPPY_DRIVE__
        __DS_FIRMWARE_CHECK_IF_ALBIREO_LIKE__()
        neg
    endm

    macro __DS_FIRMWARE_CHECK_IF_ALBIREO_LIKE__
        ld a,(&be5f)
        or a
    endm


    ;;
    ;; Reset the basic timer.
    ;; MOD:
    ;;  - HL
    macro DS_PRIVATE_RESET_TIMER
        if USE_BASIC_TIMER
            ld hl, 0
            ld (&b8b4), hl
        endif
    endm
    
    ;;
    ;; Get the basic timer (i.e. number of halts since last reset)
    macro DS_PRIVATE_COLLECT_TIMER_IN reg16
        if USE_BASIC_TIMER
            ld {reg16}, (&b8b4)
        endif
    endm

    ;;
    ;; send a code and its 16bits value to the cpc booster
    ;; modified: A, BC
    ;; precondition: {reg16} != BC, {reg16} != AF
    macro DS_PRIVATE_BOOSTER_COMMUNICATION code, reg16
        if USE_CPCBOOSTER
            LD BC, BOOSTER_COMMUNICATION_PORT
            ld a, {code}
            out (c), a
            out (c), {reg16}.low
            out (c), {reg16}.high
        endif
    endm


    DS_PRIVATE_BOOSTER_COMMUNICATION_FILE_SIZE equ 1
    DS_PRIVATE_BOOSTER_COMMUNICATION_FILE_HALTS equ 2


    ;;
    ;; Demosystem is store in 0xe000-0xf000
    org __DS_FILE_LOADING_ROUTINE__

    assert $ >= __COPY_BUFFER__ + __COPY_BUFFER_SIZE__

    assert $ == __DS_FILE_LOADING_ROUTINE__    : jp ds_c1_load_file
    assert $ == __DS_BACKUP_FIRMWARE_ROUTINE__ : jp ds_c1_backup_firmware 
    assert $ == __DS_SAVE_SCREEN_MODE__        : jp ds_c1_save_screen_mode
    assert $ == __DS_COPY_FROM_EXTRA_TO_MAIN__ : jp ds_c1_copy_from_extra_to_main_over_buffer

;;
;; This function MUST be called when being in bootstrap space c1.
;; It restores the firmware, load the file, save the firmware, kill it.
;; Input
;;   - HL = filename
;;   - DE = address
;;   - B = size of the filename
;;     C = options of loading
;; Output
;; BC: lenght of the file
;; DE: expected destination of the file
ds_c1_load_file

    ; no modification HL/BC
    __SWITCH_TO_BOOTSTRAP_STACK__()

    ; Save file-handling data in bootstrap memory 

    ; Save the loading option
        ld a, c : ld (.option), a

     ; Save the filename size
    .copy_filename_size
        ld a, b : ld (__ds_bootstrap_filename_size__), a

        ; Save the load address
    .save_load_address
        ld (__ds_bootstrap_load_address__), de

        ; copy the filename before it is not anymore available
        ; we do not care of the realsize
    .copy_filename
        ld de, __ds_bootstrap_filename__
        ld c, b : ld b, 0
        ldir

.enter_demosystem_space
    di
        __DS_SELECT_DS_FULL_SPACE__()
        __SWITCH_TO_DS_STACK__()

        if ENABLE_OPTION_LOADER_OPTION_DISABLE_SYSTEM_RESTORATION
            ld a, (.option)
            cp DS_LOADER_OPTION_DISABLE_SYSTEM_RESTORATION
            jr z, .skip_restoration
        endif
        ; here we are in the full space of the demossytem
        call ds_c2_restore_firmware
        call ds_c2_clean_firmware_state
.skip_restoration
    ei
    

    ; set motor drive on if needed
    __DS_FIRMWARE_CHECK_IF_ALBIREO_LIKE__()
    jr z, .after_motor_on
    ld a, (.option)
    and ~DS_LOADER_OPTION_REQUEST_DRIVE_MOTOR_ON
    jr z, .after_motor_on
.set_motor_on
    ld bc, 0xFA7E : out (c), c ; open motor drive
    ; wait a bit to obtain a full speed
    repeat 5
        call ds_c1_wait_secured_vsync
    endr
.after_motor_on

    ; copy file loading information
    ld hl, __ds_bootstrap_filename__
    ld de, __DS_FILENAME__
    ld bc, __DS_FNAME_BUFFER_SIZE
    ldir
    
    call ds_c2_load_file_impl : ld (.file_size), bc
    ; XXX Do not touch DE or backup it until the end of the execution
    ; call ds_c2_backup_frimware  ; XXX it would be nice toreactivate that


    ; set motor drive off if needed
    __DS_FIRMWARE_CHECK_IF_ALBIREO_LIKE__()
    jr z, .after_motor_off
    ld a, (.option)
    and ~DS_LOADER_OPTION_REQUEST_DRIVE_MOTOR_OFF
    jr z, .after_motor_off
.set_motor_off
    ld bc, 0xFA7E : out (c), 0  ;  motor off
.after_motor_off



    di
        DS_SELECT_DS_BOOTSTRAP_SPACE()
    ; here we are in the bootstrap space ...
        __SWITCH_TO_PROG_STACK__()
    ; ... with the program stack
    ei

    ld bc, 0 : .file_size equ $-2
    ret
.option db 0

;;
; Save the current screen mode
; Input: A screen mode in Gate Array notation
ds_c1_save_screen_mode
    ld (__ds_screen_mode__), a
    ret

;;
;; Copy a huge block from extra memory to main memory
;; Restrictions:
;;   - source address < &c000
;;   - destination address > &40
;;   - destination address + nb_bytes < &8000
;; Input:
;; - HL: Adress in extra page
;; - DE: Adress in main page 
;; - BC: number of bytes to copy
ds_c1_copy_from_extra_to_main_over_buffer
    BREAKPOINT
    __SWITCH_TO_BOOTSTRAP_STACK__()

.handle_current_bloc
    ld a, b : or c
    jr z, .copy_completed ; we have finished to copy

    ;; Check if we have to copy more than &2000 bytes
    ;; (the size of the temporary buffer)
    push hl
        ld hl, __COPY_BUFFER_SIZE__
        or a : sbc hl, bc
    pop hl
    jr c, .needs_an_intermediate_copy ; we have an intermediate &2000 bytes copy

    ; here we have &2000 or less bytes to copy

    ; here we know it is the very last copy
    ; BC<=__COPY_BUFFER_SIZE__
.last_bloc_copy
    call .copy_one_bloc
.copy_completed
    __SWITCH_TO_PROG_STACK__()
    ret

.needs_an_intermediate_copy
    push bc

        ; copy a bloc of &2000 bytes
        push de, hl
            ld bc, __COPY_BUFFER_SIZE__
            call .copy_one_bloc
        pop hl, de

        ; compute values for next bloc
        ; add &2000 to src and tgt
        ld bc, __COPY_BUFFER_SIZE__
        add hl, bc
        ex de, hl : add hl, bc : ex de, hl
    
    pop bc
    
    ; Remove &2000 to bc
    push hl
        ld hl, bc
        ld bc, __COPY_BUFFER_SIZE__
        or a : sbc hl, bc
        ld bc, hl
    pop hl
    jr .handle_current_bloc

    ;;
    ; Copy in main memory over the proxy of the 2k buffer
    ; 
    ; Input
    ; - HL: src in C2 space
    ; - DE: dst in C1 space
    ; - BC number of bytes to copy <= &2000
.copy_one_bloc

    di
        ; Swith to C2 space
        push bc
            ld bc, 0x7fc2 : out (c), c
        pop bc

        ; copy the appropriate amount of bytes
        ; hl, bc have the right value
        ; de is used at the 2nd step
        push de, bc
            ; copy to the temporary buffer
            ld de, __COPY_BUFFER__
            ldir

            ; Switch back to C1 space
            ld bc, 0x7fc1 : out (c),c 
        pop bc, de

        ; copy to the main memory
        ld hl, __COPY_BUFFER__
        ldir
    ei
    ret





;;
;; Backup the original CPC firmware that is in main memory or this system
;; that is in extra memory and used by the demo.
;; As this is stricly the same code, there is nothing to do
;; Interruption have to be cut
ds_c1_backup_firmware
ds_c2_backup_frimware

    ; All code is in &C000, we cannot write here
    call ds_c1_make_firmware_quiet
    di ; XXX remove ?

    ; Désactivation la ROM firmware
    ld bc, (__ds_screen_mode__) : ld b, &7f; here c is supposed to contains the screen mode
    out (c),c

    ld de, __ds_save_buffer__

    ; Données du Kernel et des indirections
    ld hl, __FIRMWARE_DATA_START__
    ld bc, __FIRMWARE_DATA_SIZE__
    ldir

    ; Données statiques de l'Amsdos
    ld hl, __AMSDOS_STATIC_DATA_ADDRESS__
    ld bc, __AMSDOS_STATIC_DATA_SIZE__
    ldir

    ; Données dynamiques de l'Amsdos
    ld hl, (__AMSDOS_DYNAMIC_DATA_ADDRESS_PTR__)
    ld bc, __AMSDOS_DYNAMIC_DATA_SIZE__
    ldir


    ; Registres secondaires utiles au Kernel
    ld ixh,d
    ld ixl,e
    ex af,af'
            ld (de),a
            exx
                    ld (ix+1),b
                    ld (ix+2),c
            exx
    ex af, af'

    ret



ds_c1_make_firmware_quiet
ds_c2_make_firmware_quiet
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
        jp &BB57 ; TXT_VDU_DISABLE

;;
;; Restore the demosystem in C2 space.
;; Need to be called from the C2 space too.
;; No input is required
;; Interruptions have to be cut here
ds_c2_restore_firmware

    ; Activation la ROM firmware
    ld a, (__ds_screen_mode__) : and %11111011
    ld b,&7f : out (c),a


    ; Recopie les primitives du Kernel vers la RAM
    push de
        ld hl,0
        ld de,0
        ld bc,&40
        ldir
    pop hl

    ; Désactivation de la ROM firmware
    ;ld bc,&7f8e : out (c),c
    ld bc, (__ds_screen_mode__) : ld b, &7f
    out (c),c

    ld hl, __ds_save_buffer__

    ; Firmware data and indirections
    ;ld hl,FirmwarePackAddress ; Already set
    ld de, __FIRMWARE_DATA_START__
    ld bc, __FIRMWARE_DATA_SIZE__
    ldir

    ; Données statiques de l'Amsdos
    ld de, __AMSDOS_STATIC_DATA_ADDRESS__
    ld bc, __AMSDOS_STATIC_DATA_SIZE__
    ldir

    ; Données dynamiques de l'Amsdos
    ld de,(__AMSDOS_DYNAMIC_DATA_ADDRESS_PTR__)
    ld bc, __AMSDOS_DYNAMIC_DATA_SIZE__
    ldir


    ; Override screen mode
    ld a, (__ds_screen_mode__) : and %11
    ld (__MODE_NUMBER_PTR_6128__), a ; TODO write a OS agnostic version

    ; Registres secondaires utiles au Kernel
    ld a,(hl)
    inc hl
    ld b,(hl)
    inc hl
    ld c,(hl)
    exx
    ex af,af'



    ret


ds_c1_wait_secured_vsync
ds_c2_wait_secured_vsync
    ld b, 0xf5
.vsync
    in a, (c)
    rra
    jr nc, .vsync

.novsync
    in a, (c)
    rra
    jr nc, .novsync
    ret

ds_c2_clean_firmware_state
    ; XXX
    ; here we have a limitation: we cannot pre-open a file as Toms was doing initially
    ld hl, &b11a : ld (hl),0 ;  ; mise à 0 du flag indiquant que un fichier est ouvert, sinon cas_in_open retourne un code d'erreur 0e (peut-être seulement si on charge depuis une cassette)
    
    call &bcc8 ; kl_choke_off, remet à 0 la liste des timers pour être dans un état propre

    ld a, (__ds_screen_mode__)
    ld b, 0x7f : out (c), a
    ld (__MODE_NUMBER_PTR_6128__), a ; XXX maybe not usefull
    and %11 : call &bd1c ; MC_SET_MODE
    
    ret

    if false // no need in our project
        ;;
;; Restauration complète du firmware préalablement sauvegardé via BackupFirmware
;; (tous les modules sont de nouveau utilisables, sauf les RSX)
;;
RestoreFullFirmware
        call RestoreFirmware
        call &bca7 ; SOUND RESET
        call &bb00 ; KM INITIALISE
        call &bb4e ; TXT INITIALISE
        call &bbba ; GRA INITIALISE
        call &bbff ; SCR INITIALISE
        call &bc64 ; CAS INITIALISE
        ; Reinstall CAS indirections which where
        ; just destroyed by CAS INITIALISE
        ld hl,FirmwarePackAddress+FirmwareDataStart-&bc77
        ld de,&bc77
        ld bc,13*3
        ldir
        ; Réactive les messages d'erreur disquette
        ld a,0 ; 0 = Activé
        ld (&be78),a

        ret
    endif


;;
; Really does the file loading after having everyhing prepared
; Output: BC: file size
ds_c2_load_file_impl

        ei
        ; cancel previous loading
        call &bc7d

        ; Open the file
        ld hl, __DS_FILENAME__
        ld a, (__DS_FILENAME_SIZE__) : ld b, a
        ld de, (__DS_LOAD_ADDRESS__)
        call &bc77 // cas in open
        jr nc, .open_error
        jr z, .open_error

        ; BC contains the length of the loaded file
        ld a, b : cp c : jr z, .ascii_error ; ascii file is not handled
        ld (.file_size), bc

        if USE_CPCBOOSTER
            ld hl, bc
            DS_PRIVATE_BOOSTER_COMMUNICATION DS_PRIVATE_BOOSTER_COMMUNICATION_FILE_SIZE, HL
        endif
        DS_PRIVATE_RESET_TIMER()

        ; Load the file
        ld hl, (__DS_LOAD_ADDRESS__) // XXX we ignore the header load address
        call &bc83 // cas in direct
        jr nc, .load_error
        jr z, .load_error



        ; Close the file
        call &bc7a // cas in close
        jr c, .ok
.close_error
    ld a, DS_CLOSE_ERROR_GA 
    jr .error
.ascii_error
    ld a, DS_ASCII_ERROR_GA 
    jr .error
.open_error
    ld a, DS_OPEN_ERROR_GA 
    jr .error
.load_error
    ld a, DS_LOAD_ERROR_GA 
    ; jr .error
.error
        di
        if !MAKE_FIRMWARE_SILENT
            ld bc, 0xbc00 + 1 : out (c), c
            ld bc, 0xbd00 + 0 : out (c), c
            ld bc, 0x7f10 : out (c), c
            out (c), a
        endif
        jp $
.ok

        DS_PRIVATE_COLLECT_TIMER_IN HL
        DS_PRIVATE_BOOSTER_COMMUNICATION DS_PRIVATE_BOOSTER_COMMUNICATION_FILE_HALTS, HL

        ; TODO add a halt for albireo

        ld hl, &c9fb
        ld (&38), hl

        ld bc, 0 : .file_size equ $-2
        ret



;;
; Screen mode in gate array space &8c, &8d, &8e
__ds_screen_mode__ db &8e


;;; ======== No more code must be added here =============
;;

;:
; buffer for the filename to load
__ds_bootstrap_filename__ 
;;
; buffer to the lenght of the filename
__ds_bootstrap_filename_size__ equ __ds_bootstrap_filename__ + 256 ; we can handle filenames of 256 bytes
;;
; loading address
__ds_bootstrap_load_address__ equ __ds_bootstrap_filename_size__ + 1
;;
; Storage to store the caller stack
__ds_bootstrap_program_stack_backup__  equ __ds_bootstrap_load_address__  + 2
__ds_demosystem_bootstrap_stack_backup__ equ __ds_bootstrap_program_stack_backup__ + 2
;;
; Storage to save the firmware stuff
; Can be accessed in 0xC1, 0xc2 space directly
; Can be accessed in 0xc7 space after removing 0x8000 to the address
__ds_save_buffer__ equ __ds_demosystem_bootstrap_stack_backup__ + 2
__ds_save_buffer_end__ equ __ds_save_buffer__ + __FIRMWARE_STORAGE_SIZE__

FirmwarePackAddress equ __ds_save_buffer__ ; TODO remove this line ASAP

;;
; The demosystem uses its own stack
; We still need to define a proper size
__ds_bootstrap_stack__ equ __ds_save_buffer_end__ + __STACK_SIZE__
    assert $
    assert $>0x0000, "You wrap memory, demosystem is too large or loaded to high"


print "DS SAVE_BUFFER: [", {hex}__ds_save_buffer__, "-", {hex}(__ds_save_buffer_end__-1), "]" 