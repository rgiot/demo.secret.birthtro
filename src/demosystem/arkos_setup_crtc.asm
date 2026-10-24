;    _____         __
;   /  _  \_______|  | ______  ______
;  /  /_\  \_  __ \  |/ /  _ \/  ___/
; /    |    \  | \/    <  <_> )___ \
; \____|__  /__|  |__|_ \____/____  >
;         \/           \/         \/
; Seamless CRTC-frame setup (keep the VSync stable!). CPU-Driven version.
; Grim/Arkos^Semilanceata
;
; version 5.0 (june 2009) (added support for R7=0 # 63 bytes smaller)
;
; *** API ***
; crtc_setup(HL) - setup a new CRTC-frame configuration.
; crtc_restore() - restore the last known CRTC-frame configuration.
;
; *** Notes ***
; cRx mean current CRTC register value
; nRx mean the new CRTC register value
; where x is the register id (0 to 13)
;
; *** Known Limitations ***
; - When swapping from differents R9 values (cR9<>nR9) and the interrupts are
;   enabled, the ISR(s) should not take any longer than min(cR9,nR9) rasterlines
;   otherwise the CRTC registers setup will miss a char and screw the VSync.
;
; - Should not be used with very little R9 values. R9=3 should be the minimum.
;   With lower values, an overflow of the R4 might appears and fuckup the frame
;   timings. BE CAREFUL!
;
; - You have to provide a valid registers list (i.e. producing a stable and
;   standard video-frame timings). There's almost no check to prevent the lib
;   from fucking up the CRTC if you provide crappy values.
;
; - If you want to switch from 50Hz to 60Hz frame-rate seamlessly then... write
;   your own lib to do that (good luck =).
;
; For further informations, see the Reapers documentation online
; www.grimware.org/doku.php/projects/reaper/start#crtc
;
; *** Configuration ************************************************************

				ifndef cnf_crtc_default_R0
cnf_crtc_default_R0			EQU 63
				endif
				
				ifndef cnf_crtc_default_R1
cnf_crtc_default_R1			EQU 40
				endif
				
				ifndef cnf_crtc_default_R2
cnf_crtc_default_R2			EQU 46
				endif
				
				ifndef cnf_crtc_default_R3
cnf_crtc_default_R3			EQU #8E
				endif
				
				ifndef cnf_crtc_default_R4
cnf_crtc_default_R4			EQU 38
				endif
				
				ifndef cnf_crtc_default_R5
cnf_crtc_default_R5			EQU 0
				endif
				
				ifndef cnf_crtc_default_R6
cnf_crtc_default_R6			EQU 25
				endif
				
				ifndef cnf_crtc_default_R7
cnf_crtc_default_R7			EQU 30
				endif
				
				ifndef cnf_crtc_default_R8
cnf_crtc_default_R8			EQU 0
				endif
				
				ifndef cnf_crtc_default_R9
cnf_crtc_default_R9			EQU 7
				endif
				
				ifndef cnf_crtc_default_R10
cnf_crtc_default_R10			EQU 0
				endif
				
				ifndef cnf_crtc_default_R11
cnf_crtc_default_R11			EQU 0
				endif
				
				ifndef cnf_crtc_default_R12
cnf_crtc_default_R12			EQU #30
				endif
				
				ifndef cnf_crtc_default_R13
cnf_crtc_default_R13			EQU #00
				endif

; ******************************************************************************

				; Setup a new CRTC-Frame configuration
				; Input
				; 	HL=CRTC Register List address
				;
				; Register List format
				; 	db reg,value
				; use reg+#80 to tag the last register in the list
crtc_setup:
				; Parse registers list
				ld d,hi(_crtc_data_registers)
				ld a,(hl)
				and 15
				add lo(_crtc_data_registers)
				ld e,a
				jr nc,$+3
				 inc d
				bit 7,(hl)
				ex af,af'
				inc hl
				ldi
				ex af,af'
				jr z,crtc_setup
crtc_restore:
				; Initialize the register buffer pointer
				ld ix,_crtc_data_registers
				
				; Save some of the new CRTC register values
				; as they are going to be overwritten with
				; temporary values.
				ld d,(ix+7)
				push de
				ld de,(_crtc_data_register_R4)
				push de
				
				; Calculate how many scanline there are between
				; VSync and VCC=0 with the new CRTC-frame setup.
				; SLVC0=(nR4+1-nR7)*(nR9+1)+nR5
				
				; (nR4+1-nR7)
				ld a,e ;(ix+4)
				inc a
				ld c,a
				sub (ix+7)
				
				; In case there's no VSync (nR7>nR4)
				; Don't care about timing, write all CRTC registers.
				jr c,_crtc_exit_novsync
				
				; Detect special case when R7=0
				cp c
				ld e,128	; if nR7=0, set tR7=0
				jr z,$+3
				 dec e		; if nR7>0, set R7=127 (kill VSync)
				ld (ix+7),e
				
				; *(nR9+1)+nR5
				ld b,(ix+9)
				inc b	; R9+1
				ld c,d	;(ix+5)
				ld d,0
				ld e,a	; DE = Char
				ld h,d
				ld l,d	; HL = 0
				; HL=DE*R9
				add hl,de
				djnz $-1
				; HL=HL+R5 (B=0 after djnz)
				add hl,bc
				; Output
				;	HL holds the number of scanlines (SLVC0)
				;	Carry is clear
				;	B is Zero
				
				; Save the number of scanlines for later
				push hl
				
				; Get the temporary CRTC Reg4 # Reg5 value to perform
				; a clean setup transition.
				;  tR4 = cR7 + integer(SLVC0/nR9)
				;  tR5 = SLVC0 % nR9
				ld a,cnf_crtc_default_R7
_crtc_var_current_R7		equ $-1
				ld c,(ix+9)
				inc c		; BC=nR9+1
				dec a
				dec a		; <= voodoo! (investigate this)
_crtc_SLVC0_convertion		inc a
				sbc hl,bc
				jr nc,_crtc_SLVC0_convertion
				add hl,bc
				ld (ix+4),a	; tR4 = cR7 + integer(SLVC0/nR9)
				ld (ix+5),l	; tR5 = SLVC0 % nR9
				
				; Wait for a fresh VSync to start
				ld b,#F5
_crtc_wait_noVSync		in a,(c)	; if a VSync is already active
				rra		; wait until it goes inactive.
				jr c,_crtc_wait_noVSync
_crtc_wait_VSync		in a,(c)	; wait for a fresh VSync
				rra
				jr nc,_crtc_wait_VSync
				
				; Update all CRTC registers while the
				; frame fly-back (using the calculated
				; temporary values).
				call _crtc_setAll
				
				; Wait for VCC=0 (at it's new position), that is
				; SLVC0 scalines from VSync, so we adjust the SLVC0
				; value to take into account the rasterlines taken
				; after the VSync to setup the CRTC registers
				; (almost 4 rasterlines).
				pop hl
				dec hl	; adjust timing to get the closest
				dec hl	; as possible of VCC=0 (# HCC=0)
				dec hl
				
			; ****** CUSTOMIZE HERE ********************************
			; Input
			;	HL hold the number of scanlines to wait until VCC=0
			;
			; *** Notes ***
			; The CPU will be stuck in the loop below to waste
			; some cycles until VCC=0. If you need these cycles to
			; do some other tasks (eg. playing music), you can do
			; your changes here (BEWARE! HL might be very little
			; depending on your new CRTC configuration thus you
			; won't get much cpu-cycles).
			; 
			; On the Amstrad Plus, a DMA channel could be programmed
			; with PAUSE INT instructions to trigger a DMA-INT when
			; VCC=0 (thus freeing the CPU for some other tasks until
			; the DMA-INT is issued). The PRI might not be appropriate
			; because of it's 8bit boundary and CRTC dependencies.
			
				; HL*64us loop
_crtc_wait_VCC0			ld b,14
				djnz $
				dec hl
				ld a,h
				or l
				jr nz,_crtc_wait_VCC0
				
			; ******************************************************
_crtc_exit_novsync
				; Restore the new R4 # R5 values.
				pop de
				ld (_crtc_data_register_R4),de
				
				; Restore new R7 value.
				pop af
				ld (ix+7),a
				ld (_crtc_var_current_R7),a
				
				; Update (again) all the CRTC registers
				; to their final values.
				; 226us / ~3.5 raster-lines
				;
				; Only R4,R5 and R7 need to be updated, but I
				; prefered to re-use the same CRTC routine to
				; save some bytes.
_crtc_setAll:
				ld hl,_crtc_data_registers+13
				ld bc,#BCBE
				ld a ,13
_crtc_setAll_loop
				out (c),a
				ld b,c
				outd
				dec b
				dec a
				jp p,_crtc_setAll_loop
				ret
				
_crtc_data_registers		; CRTC Register values (buffer)
_crtc_data_register_R0		db cnf_crtc_default_R0
_crtc_data_register_R1		db cnf_crtc_default_R1
_crtc_data_register_R2		db cnf_crtc_default_R2
_crtc_data_register_R3		db cnf_crtc_default_R3
_crtc_data_register_R4		db cnf_crtc_default_R4
_crtc_data_register_R5		db cnf_crtc_default_R5
_crtc_data_register_R6		db cnf_crtc_default_R6
_crtc_data_register_R7		db cnf_crtc_default_R7
_crtc_data_register_R8		db cnf_crtc_default_R8
_crtc_data_register_R9		db cnf_crtc_default_R9
_crtc_data_register_R10		db cnf_crtc_default_R10
_crtc_data_register_R11		db cnf_crtc_default_R11
_crtc_data_register_R12		db cnf_crtc_default_R12
_crtc_data_register_R13		db cnf_crtc_default_R13
				

    macro AKS_CRTC_TRANS_ADD_ROW reg, val, last
        if {last}
            db {reg}+0x80, {val}
        else
            db {reg}, {val}
        endif
    endm
    
    ; {table} is a list of pairs [reg, value] to setup the CRTC
    macro AKS_CRTC_TRANS_TABLE table
        @table = {table}
        @nb_items = list_len(@table)
        repeat @nb_items, i, 0
            @row = list_get(@table, {i})
            @reg = list_get(@row, 0)
            @val = list_get(@row, 1)
            @last =  @nb_items - 1 == {i}
            AKS_CRTC_TRANS_ADD_ROW({eval}@reg, {eval}@val, {eval}@last)
        endrepeat
    endm

    macro AKS_HANDLE_CRTC_TRANSITION table
        ld hl, {table}
        call crtc_setup
    endm
    