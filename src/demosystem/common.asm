;;
;; common.asm contains macros that would be usefull with any demo system.



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;          MEMORY HANDLING          ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	macro DS_PRODUCE_CRC16_SUM_ROUTINE
ds_crc16_sum
	DS_CRC16_SUM()
	ret
	endm

;; Compute the CRC16 sum of a data block.
;; Input:
;; - HL: pointer to the data block
;; - BC: length of the data block
;; Output:
;; - DE: CRC16 sum of the data block
;; Clobbers:
	macro DS_CRC16_SUM
		ld de, 0
@loop
		; get memory byte 
		ld a, (hl) : inc hl

		; 16 bits + bits
		add e : ld e, a
		ld a, d : adc a, 0: ld d, a

		; handle loop
		dec bc
		ld a, b
		or c
		jr nz, @loop
	endm 

	;; Compute the crc16 sum of a data bloc
	function crc16_sum bytes
		return update_crc16_sum(0, {bytes})
	endfunction

	function update_crc16_sum crc_init, bytes
		crc = {crc_init}
		iterate val in {bytes}
			crc = (crc + {val}) & 0xffff
		enditerate
		return crc
	endfunction


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;          ERROR HANDLING            ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


	;; Check if HL == {expected}
	macro DS_Z80_ASSERT_EQU_HL expected
		DS_Z80_ASSERT_EQU_R16 hl, {expected}
	endm


	;; Check if DE == {expected}
	macro DS_Z80_ASSERT_EQU_DE expected
		DS_Z80_ASSERT_EQU_R16 de, {expected}
	endm



	macro DS_Z80_ASSERT_EQU_R16 r16, expected
		ld (@restore), a ; save A

		ld a, high({expected})
		cp {r16}.high
		jr nz, @err
		ld a, low({expected})
		cp {r16}.low
		jr z, @ok

@err
		ld bc, 0xbc00 + 1 : out (c), c : inc b : dec c : out (c), c  ; no pixels
		ld bc, 0x7f10 : out (c), c : ld c, DS_ASSERT_ERROR_GA : out (c), c 
		jr $ ; infinite loop
@ok 	
		ld a, 0 : @restore equ $-1 ; restore A
	endm


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;          KEYBOARD HANDLING         ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;
;; Generate the routine to check if the user pressed space
macro DS_PRODUCE_KEYSPACE_ROUTINE
    ;;
    ; Check if user pressed space
    ds_keyspace
		DS_KEYSPACE()
		ret

endm

;;
;; Generate the code to check if the user pressed space
macro DS_KEYSPACE
        LD	BC,#F40E
        OUT	(C),C
        LD	BC,#F6C0
        OUT	(C),C
;  XOR	A
;  OUT	(C),A
  		defb &ed,&71
        LD	BC,#F792
        OUT	(C),C
        LD	BC,#F645
        OUT	(C),C
        LD	B,#F4
        IN	A,(C)
        LD	BC,#F782
        OUT	(C),C
;  LD	BC,#F600
;  OUT	(C),C
		dec b
		defb &ed,&71
;		
        RLA	
endm


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;          SOUND  HANDLING           ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;





;; Generate the routine to stop any sound.
;; Direct access to AY is done, not to firmware
macro DS_PRODUCE_STOP_SOUND_ROUTINE
ds_stop_sound
;
 	ld bc,#f680 
	ld a,&c0
	ld de,#f4f6
	out (c),a
; H= PSG register L=value	
	ld hl,&0700+%00111111                ; &07 = Mixer 
	call SendPsgRegister
	ld hl,&0800			    ; &08 = Volume Voice 1
	call SendPsgRegister
	inc h				    ; &09 = Volume Voice 2
	call SendPsgRegister
	inc h			            ; &10 = Volume Voice 3
;	call SendPsgRegister
        

            ;    ld l,%00111111          ;On CPC, bit 6 must be 0. Other platforms don't care.
SendPsgRegister:
    
        ld b,d
        out (c),h       ;#f400 + register.
        ld b,e
        out (c),0       ;#f600
        ld b,d
        out (c),l       ;#f400 + value.
        ld b,e
        out (c),c       ;#f680
        out (c),a       ;#f6c0
		ret
;

endm



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;            VSYNC HANDLING          ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;; Generate the routine to wait the beginning of the next VSYNC,
;; ensuring we are not already in VSYNC
macro DS_PRODUCE_SECURE_WAIT_VSYNC_ROUTINE
ds_secure_wait_vsync
	DS_SECURE_WAIT_VSYNC()
	ret
endm


;;
;; Wait the beginning of the next VSYNC, ensuring we are not already in VSYNC
macro DS_SECURE_WAIT_VSYNC
	ld b, 0xf5
@wait_novsync
	in a, (c)
	rra
	jr c, @wait_novsync

@wait_vsync
	in a, (c)
	rra
	jr nc, @wait_vsync
endm


;; Generate the routine to wait the beginning of the next VSYNC
macro DS_PRODUCE_WAIT_VSYNC_ROUTINE
ds_wait_vsync
	DS_WAIT_VSYNC()
	ret
endm


;; Wait VSYNC, even if it is already started
macro DS_WAIT_VSYNC
	ld b, 0xf5
@wait_vsync
	in a, (c)
	rra
	jr nc, @wait_vsync
endm

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;           WAIT HANDLING            ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;
	;; Wait N microseconds (max wait 1021 ms / length 4 - 7 bytes)
	;; Initial code from @Syx
	MACRO DS_WAIT_MICROSEG duration
@k EQU {duration} - 1
		LD   B,@k / 4                      ; (2 = 1 that we subtracted and 1 that is missing from the DJNZ)
		DJNZ $                              ; (4 * [N - 1] + 3 = 4 * N - 1)
		DEFS @k % 4                        ; (1 * [4 * N - 1] % 4)
	ENDM





	;;  Wait a number of CPU cycles (max wait 1024 cycles) 
    MACRO   WAIT_CYCLES cycles
		assert {cycles} <= 1024, 'Too many nops'
		assert {cycles} > 0, 'Wait time must be positive'

		; Compute the number of loops and extra nop
	@loops     equ ({cycles}-1)/4 
	@loopsx4   equ @loops*4
	@nops      equ {cycles}-@loopsx4-1

		; Produce a loop only if required
		if @loops != 0
			ld  b, @loops
	@change_waitLoop
			djnz    @change_waitLoop
		endif

		; Produce extra nops
		defs    @nops, 0

    endm


    ;;
    ;; Macro able to wait more than 1024 nops. Relay on WAIT_CYCLES
    MACRO LONG_WAIT_CYCLES cycles

        if {cycles} <= 1024
            WAIT_CYCLES {cycles}
        else
            WAIT_CYCLES 1024
            LONG_WAIT_CYCLES {eval}({cycles} - 1024)
        endif
    ENDM



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;             CRTC HANDLING          ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;
;; WRITE_CRTC: Writes a value to a CRTC register
;; Corrupts: BC
;; XXX we need to keep this slow and long code for crunch and duration purpose
MACRO DS_WRITE_CRTC register, value
        LD   BC, &bc00 + {register}
        OUT  (C),C
        LD   BC, &bd00 + {value}
        OUT  (C),C
ENDM


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;     CRTC TRANSITIONS HANDLING      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; This allows to move the transisition forwards or backwards on the line. This value is a good
; compromise to have it near the middle of the line, far from the HBL
        ifndef __DS_HT_delay1
__DS_HT_delay1 equ 26
        endif

	;; Original code: pulko mandy
	;; Horizontal CRTC transition from R2=from to R2=to
	;; Valeur limites:
	;; - New R6 >= 2
	;; - New R6 - Old R6 >= 31
	;; ça devrait être suffisant dans la plupart des cas?
	;; Pour les transitions avec New R6 - Old R6 plus grand que 31, on peut appeler la macro 2 fois,
	;; par exemple pour transitionner de R2=2 à R2=46 en douceur:
	;; HT 2, 31
	;; HT 31, 46
	;
	;; Il doit être possible de déterminer ce qu'il se passe exactement et d'écrire un cas particulier
	;; de la macro si on veut.
	;;
	;; Music MUST not play under interruption for timing reasons
	;; XXX no deeply tested yet
	MACRO DS_CRTC_HORIZONTAL_TRANSITION_ONLY from, to
@delta EQU ({to}) - ({from})
		DS_WAIT_MICROSEG(__DS_HT_delay1)

		; START OF CRTC TRANSITION, WRITE TEMP R0 ---------------------------------+
		DS_WRITE_CRTC(0, {eval}63 - @delta)  	; 14 NOPs
		DS_WAIT_MICROSEG(64 - 14 - 14)
		xor a                    		; 1 NOP  XXX initial code of Pulko was tagged 1 NOP but using ld a, 0
		DS_WRITE_CRTC(2, {to})         	; 14 NOPs
		DEC B                    		; 13 remaining NOPs of CRTC write
		OUT (C),A
		LD BC, &bd00+63
		; END OF CRTC TRANSITION, RESTORE R0 exactly 64us later -------------------+
		OUT (C), C
	ENDM



	;; Vertical CRTC transition from R7=from to R7=to
	;; Music MUST not play under interruption for timing reasons
	;; XXX no deeply tested yet
	MACRO DS_CRTC_VERTICAL_TRANSITION_ONLY, from, to
		DS_WAIT_VSYNC()
		DS_WRITE_CRTC(4, 38 + {from} - {to})
		DS_WRITE_CRTC(7, {to})
		DS_PLAY_MUSIC()

		HALT
		HALT

		DS_WAIT_VSYNC()
		DS_WRITE_CRTC(4, 38)
		DS_PLAY_MUSIC()
	ENDM



	MACRO DS_CRTC_VERTICAL_TRANSITION_ONLY_NO_MUSIC, from, to
		DS_SECURE_WAIT_VSYNC()

		; Here, C4=({from})

		DS_WRITE_CRTC(4, 38 + ({from}) - ({to}))

		if ({to}) > ({from})
			halt
			halt
			DS_WRITE_CRTC(7, ({to}))
		else
			DS_WRITE_CRTC(7, ({to}))
			HALT
			HALT
		endif

		DS_WAIT_VSYNC()
		DS_WRITE_CRTC(4, 38)
	ENDM



	; XXX no deeply tested yet
	MACRO DS_CRTC_VERTICAL_AND_HORIZONTAL_TRANSITIONS, vert_from, vert_to, horiz_from, horiz_to
		DS_WAIT_VSYNC()
		DS_WRITE_CRTC(4, 38 + {vert_from} - {vert_to})
		DS_WRITE_CRTC(7, {vert_to})
		DS_PLAY_MUSIC()

		HALT

		DS_HORIZONTAL_TRANSITION_ONLY(horiz_from, horiz_to)

		HALT


		DS_WAIT_VSYNC()
		DS_WRITE_CRTC(4, 38)
		DS_PLAY_MUSIC()
	ENDM


	MACRO DS_CRTC_VERTICAL_AND_HORIZONTAL_TRANSITIONS_NO_MUSIC, vert_from, vert_to, horiz_from, horiz_to
		DS_SECURE_WAIT_VSYNC()
		DS_WRITE_CRTC(4, 38 + {vert_from} - {vert_to})
		DS_WRITE_CRTC(7, {vert_to})

		HALT

		DS_CRTC_HORIZONTAL_TRANSITION_ONLY({eval}{horiz_from}, {eval}{horiz_to})

		HALT


		DS_WAIT_VSYNC()
		DS_WRITE_CRTC(4, 38)
	ENDM


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;       CRTC DETECTION HANDLING      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


macro DS_PRODUCE_CRTC_DETECTOR_ROUTINE
ds_crtc_detector
	DS_CRTC_DETECTOR()
	ret
endm

macro DS_CRTC_DETECTOR

; Source: https://amstradplus.forumactif.com/t22-detecter-son-crtc
; - Last Update : 22/04/2022
;
; On commence en premier lieu par tester si on est sur Amstrad Plus ou pas
;
ld bc,#f782 ; bc=#f782 ; Port B du PPi en entrée
ld e,c      ; e=#82 ; le test est basé sur le bug du ppi
out (c),c   ; de l'Amstrad Plus
dec b       ; b=#f6
ld c,#0f    ; bc=#F60f
out (c),c   ; on envoie une valeur bidon au port #f6 (#0f)
inc  b      ; b=#f7
ld a,e      ; a=#82
out (c),a   ; Port B du PPi en entrée
dec b       ; b=#f6
in a,(c)    ; a=val du port #f6
cp c        ; si la val du port #f6 est égale à #0f
jr z,@crtc3  ; c'est un Amstrad Plus (Crtc 3)
;
; On est pas sur Amstrad Plus
; Les tests crtc 4 et 0 sont basés sur la lecture du poids fort
; du reg12 du crtc
;
ld e,#30 ; on positionne le poids fort de la vRam en #30 (#cxxx)
ld bc,#bc0c
out (c),c ; selection du r12
inc b
out (c),e ; envoie de la valeur au port 12 du crtc
;
; Est-ce un Amstrad Cpc Crtc 4 ?
; On lit le port #be
; Si le résultat obtenu est égal à la valeur de e (vRam)
; Alors c'est un Amstrad Cpc Crtc 4
;
ld b,#be ; detection crtc 4
in a,(c)
cp e ; e=poids fort vRam
jr z,@crtc4
;
; Si ce n'est pas un Amstrad Cpc Crtc 4
; Est ce un Amstrad Cpc Crtc 0 ?
; Pour cela on utilise le port #bf du Crtc
; Si le résultat obtenu est égal à la valeur de e (vRam)
; alors c'est un Amsttrad Cpc Crtc 0
;
ld b,#bf ; detection crtc 0
in a,(c)
cp e ; e=poids fort vRam
jr z,@crtc0
;
; Ce n'est pas un Amstrad Cpc Crtc 0
; Serait-ce par hasard un Amstrad Cpc Crtc 1 ?
;
ld bc,#bc1F ; on teste si c'est un crtc 1
out (c),c ; a sera différent de 0
;
ld b,#bf ; si a=0, ce sera un crtc 2 par élimination.
in a,(c)
jr z,@crtc2
;
; Ce n'est pas un Amstrad Cpc Crtc 2
; c'est donc forcément par élimination, un Amstrad Cpc Crtc 1
;
jr @crtc1
;
; it's a crtc 0
;
@crtc0 xor a : jr @leave
@crtc1 ld a, 1 : jr @leave
@crtc2 ld a, 2 : jr @leave
@crtc3 ld a, 3 : jr @leave
@crtc4 ld a, 4 : jr @leave

@leave
endm