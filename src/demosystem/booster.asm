;;;
;;; Mini booster handling stuff
;;; https://cpcrulez.fr/hardware-serie-interface_minibooster.htm
;;; v0 come from CRTC demo. But has not been updated since

	ifndef __DS__BOOSTER__
__DS__BOOSTER__
	
	ifndef BOOSTER_COMMUNICATION_PORT
		;; The booster communication port used by default
		BOOSTER_COMMUNICATION_PORT equ 0xFF08
	endif
	
	;;
	;; Properly parametrize the CPC booster serial communication
	;; The code is adapted for cpcbooster or minibooster
	macro DS_PRIVATE_CPCBOOSTER_INIT_COMMUNICATION
		if USE_CPCBOOSTER
			;Is the card present?
			ld bc,#ff00
			in a,(c)
			cp 170
			jr nz,@Initialize_Failure
			inc c
			in a,(c)
			cp 85           ;CPC Booster.
			jr z,@Initialize_CPCBooster
			cp 238          ;Mini Booster.
			jr z,@Initialize_MiniBooster
@Initialize_Failure:
			; TODO setup a flag to inform the booster is not here
        	jr @End
@Initialize_CPCBooster:
			ld a,#05                ;Sets Baudrate to 115200 (5). 2 = 230400bps
        	jr @Initialize_Common
@Initialize_MiniBooster:
			ld a,#07       
@Initialize_Common

            ld c,#04
            out (c),c
            out (c),a
                
            ld c,#07		;Asynchronous, no Parity, 1 bit stop, 8 bits carac.
            ld a,%00000110
            out (c),c
            out (c),a

            ld c,#0b		;Enables buffer.
            in a,(c)
            set 4,a
            out (c),a

            ld c,#1c		;Resets buffer.
            xor a
            out (c),a
@End
		endif
	endm


	;; Macro to send a 16-bit register value to the CPC booster communication port
	macro DS_PRIVATE_CPCBOOSTER_SEND_16 reg16
		if USE_CPCBOOSTER
            LD BC, BOOSTER_COMMUNICATION_PORT
            OUT (C), {reg16}.low
            OUT (C), {reg16}.high
		endif
	endm


endif
