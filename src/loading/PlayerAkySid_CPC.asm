;       AKY SID music player.
;       By Julien Névo a.k.a. Targhan/Arkos.
;       January 2026.
;
;       Requires Rasm >= 3.0.8!
;
;       This players can play SID, on one channel only at a time.
;       It targets only Amstrad CPC for now.
;       It is highly specialized. One PSG only, RAM only, no SFX, no player configuration.
;
;       The init code is not stabilized (is it a problem?).
;
;       See the SIDTester_CPC.asm on how to use it. SID is *very* tricky on CPC old. Please do not include them lightly.
;
;       - The caller *must* include PlayerAkySidMacros_CPC.asm, since its macros will surely be used to sync all this.
;       - The Stack must NOT be used in your code (unless you save it), as a RET table is used to manage SID.
;       - IY is used by the macros to run the SID.
;       - HL', DE', BC', A' are used by the SID code, do NOT modify them.
;       - Call the AKY_SID_WAIT_AND_CALL_TIMER_CODE at worst every 37 NOPs.
;         or AKY_SID_WAIT_AND_CALL_TIMER_CODE_AND_JUMP_TO to perform a jump automatically after.
;       - The player is SLOW, because is is interrupted very often to handle the SID. A more straightforward player may be created in the future.
;       - At the end of the player, H' contains how many scanlines were spent. Use this to synchronize your effect, or wait for the next frame.


PLY_AKYsid_RET_TABLE_CAPACITY = 256 * 2    ;Because the "loop" may be after a 255 low-shelf.

PLY_AKYsid_RetTable1               equ PLY_AKYsid_RET_TABLES
PLY_AKYsid_RetTable1End            equ PLY_AKYsid_RetTable1 + 2 * PLY_AKYsid_RET_TABLE_CAPACITY
PLY_AKYsid_RetTable2               equ PLY_AKYsid_RET_TABLES + 2 * PLY_AKYsid_RET_TABLE_CAPACITY
PLY_AKYsid_RetTable2End            equ PLY_AKYsid_RetTable2 + 2 * PLY_AKYsid_RET_TABLE_CAPACITY
PLY_AKYsid_RET_TABLES_END          equ PLY_AKYsid_RetTable2End

PLY_AKYsid_RetTable_InitialLowShelf_Offset equ 2 * 2
PLY_AKYsid_RetTable_InitialLoop_Offset equ 3 * 2

PLY_AKYsid_RetTable1_InitialLowShelf equ PLY_AKYsid_RetTable1 + PLY_AKYsid_RetTable_InitialLowShelf_Offset
PLY_AKYsid_RetTable1_InitialLoop equ PLY_AKYsid_RetTable1 + PLY_AKYsid_RetTable_InitialLoop_Offset

PLY_AKYsid_RET_TABLE_SIZE equ PLY_AKYsid_RetTable1End - PLY_AKYsid_RetTable1
        ASSERT (PLY_AKYsid_RetTable2End - PLY_AKYsid_RetTable2) == (PLY_AKYsid_RetTable1End - PLY_AKYsid_RetTable1)         ;Both RET Table must have the same size!



PLY_AKYsid_SidChannelWhenOff equ 3                 ;Channel index when SID is off. Do not change it unless the related table is also changed!
PLY_AKYsid_SidVolumeRegisterOff equ 16             ;PSG channel when SID is not used. Values are still sent to this channel.

PLY_AKYsid_OPCODE_OR_A equ #b7                        ;Opcode for "or a".
PLY_AKYsid_OPCODE_SCF equ #37                         ;Opcode for "scf".


PLY_AKYsid_Start


        ;Disark macro: Word region Start.
        IFNDEF dkws
        disarkCounter = 0       ;Consider this macro is always declared when others are, so reset the counter for all of them.
        MACRO dkws
PLY_AKYsid_DisarkWordRegionStart_{disarkCounter}
        ENDM
        ENDIF
        ;Disark macro: Word region End.
        IFNDEF dkwe
        MACRO dkwe
PLY_AKYsid_DisarkWordRegionEnd_{disarkCounter}:
        disarkCounter = disarkCounter + 1
        ENDM
        ENDIF
        
        ;Disark macro: Pointer region Start.
        IFNDEF dkps
        MACRO dkps
PLY_AKYsid_DisarkPointerRegionStart_{disarkCounter}
        ENDM
        ENDIF
        ;Disark macro: Pointer region End.
        IFNDEF dkpe
        MACRO dkpe
PLY_AKYsid_DisarkPointerRegionEnd_{disarkCounter}:
        disarkCounter = disarkCounter + 1
        ENDM
        ENDIF
        
        ;Disark macro: Byte region Start.
        IFNDEF dkbs
        MACRO dkbs
PLY_AKYsid_DisarkByteRegionStart_{disarkCounter}
        ENDM
        ENDIF
        ;Disark macro: Byte region End.
        IFNDEF dkbe
        MACRO dkbe
PLY_AKYsid_DisarkByteRegionEnd_{disarkCounter}:
        disarkCounter = disarkCounter + 1
        ENDM
        ENDIF

        ;Disark macro: Force "No Reference Area" for 3 bytes (ld hl,xxxx).
        IFNDEF dknr3
        MACRO dknr3
PLY_AKYsid_DisarkForceNonReferenceDuring3_{disarkCounter}:
        disarkCounter = disarkCounter + 1
        ENDM
        ENDIF
        
        ;Hooks for external calls. Can be removed if not needed.
        IFNDEF PLY_AKYsid_REMOVE_HOOKS
                assert PLY_AKYsid_Start == $               ;Makes sure no byte has been added before the hooks.
                jp PLY_AKYsid_Init             ;Player + 0.
                jp PLY_AKYsid_Play             ;Player + 3.
        ENDIF





;       Initializes the player.
;       HL = music address.
;       DE = return address for the Play method.
PLY_AKYsid_InitDisarkGenerateExternalLabel:
PLY_AKYsid_Init:
        ld (PLY_AKYsid_Play_ReturnJp + 1),de

        ;Skips the header.
        inc hl                          ;Skips the format version.
        ld a,(hl)                       ;Channel count.
        inc hl
dknr3 (void): ld de,4
PLY_AKYsid_Init_SkipHeaderLoop:                ;There is always at least one PSG to skip.
        add hl,de
        sub 3                           ;A PSG is three channels.
        jr z,PLY_AKYsid_Init_SkipHeaderEnd
        jr nc,PLY_AKYsid_Init_SkipHeaderLoop   ;Security in case of the PSG channel is not a multiple of 3.
PLY_AKYsid_Init_SkipHeaderEnd:
        ld (PLY_AKYsid_PtLinker + 1),hl        ;HL now points on the Linker.

        ld a,PLY_AKYsid_OPCODE_OR_A
        ld (PLY_AKYsid_Channel1_RegisterBlockLineState_Opcode),a
        ld (PLY_AKYsid_Channel2_RegisterBlockLineState_Opcode),a
        ld (PLY_AKYsid_Channel3_RegisterBlockLineState_Opcode),a
dknr3 (void): ld hl,1
        ld (PLY_AKYsid_PatternFrameCounter + 1),hl

        ;Builds the player RET table.
        ld hl,PLY_AKYsid_CodeNothing                       ;Fills with "nothing".
        ld (PLY_AKYsid_RET_TABLES),hl
        ld hl,PLY_AKYsid_RET_TABLES
        ld de,PLY_AKYsid_RET_TABLES + 2
        ld bc,PLY_AKYsid_RET_TABLE_CAPACITY * 2 * 2        ;Two tables, words.
        ldir
        ld hl,PLY_AKYsid_SidHighShelf
        ld (PLY_AKYsid_RetTable1 + 0 * 2),hl
        ld (PLY_AKYsid_RetTable2 + 0 * 2),hl
        ld hl,PLY_AKYsid_SidLowShelf
        ld (PLY_AKYsid_RetTable1 + PLY_AKYsid_RetTable_InitialLowShelf_Offset),hl
        ld (PLY_AKYsid_RetTable2 + PLY_AKYsid_RetTable_InitialLowShelf_Offset),hl
        ld hl,PLY_AKYsid_CodeLoopRetTable1
        ld (PLY_AKYsid_RetTable1 + PLY_AKYsid_RetTable_InitialLoop_Offset),hl
        ld (PLY_AKYsid_RetTable2 + PLY_AKYsid_RetTable_InitialLoop_Offset),hl

        ret
        




        IFDEF PLY_AKY_SID_ADD_STOP_SOUNDS
;Stops the sounds. It ONLY stops the sounds and is not made to pause the music.
PLY_AKYsid_Stop:
        ld hl,#0700 + %00111111
        call PLY_AKYsid_SendPsg
        ;Volume registers to 0 too.
        ld hl,#0800
        call PLY_AKYsid_SendPsg
        inc h
        call PLY_AKYsid_SendPsg
        inc h
        jr PLY_AKYsid_SendPsg

;Sends a value to a PSG register.
;IN:    H = register
;       L = value
;MOD:   BC.
PLY_AKYsid_SendPsg
        ld b,#f4
        out (c),h       ;f400 + register.
        ld bc,#f6c0
        out (c),c       ;f6c0.
        out (c),0       ;f600.
        ld b,#f4
        out (c),l       ;f400 + value.
        ld bc,#f680
        out (c),c       ;f680
        out (c),0       ;f600.
        ret

        ENDIF ;PLY_AKY_ADD_STOP_SOUNDS




;Plays the music. It must have been initialized before.
;The interruption MUST be disabled (DI), and the stack not used.
;CALL THIS METHOD WITH A JUMP!
PLY_AKYsid_PlayDisarkGenerateExternalLabel:
PLY_AKYsid_Play:

;Linker.
;----------------------------------------

                ;Nops: 0.
dknr3 (void):
PLY_AKYsid_PatternFrameCounter: ld hl,1                ;How many frames left before reading the next Pattern.
        dec hl
        ld a,l
        or h
        jr z,PLY_AKYsid_PatternFrameCounter_Over
        ;The pattern is not over.
        ld (PLY_AKYsid_PatternFrameCounter + 1),hl
                AKY_SID_WAIT_AND_CALL_TIMER_CODE_AND_JUMP_TO PLY_AKYsid_PatternFrameManagement_End, 14
        ;jr PLY_AKYsid_PatternFrameManagement_End

;The pattern is over. Reads the next one.
PLY_AKYsid_PatternFrameCounter_Over
                ;Nops: 10.
dknr3 (void):
PLY_AKYsid_PtLinker: ld hl,0                             ;Points on the Pattern of the linker.
        ld e,(hl)                                        ;Gets the duration of the Pattern, or 0 if end of the song.
        inc hl
        ld d,(hl)
        ld a,e
                AKY_SID_WAIT_AND_CALL_TIMER_CODE 20
        or d
        jr z,PLY_AKYsid_LinkerEndSong
                ;Nops: 3.
                AKY_SID_WAIT_NOPS 19-3-3
        jr PLY_AKYsid_LinkerNotEndSong_After
PLY_AKYsid_LinkerEndSong
                ;Nops: 4.
        ;End of the song. Where to loop?
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ;We directly point on the frame counter of the pattern to loop to.
        ex de,hl
        ;Gets the duration again. No need to check the end of the song,
        ;we know it contains at least one pattern.
        ld e,(hl)
        inc hl
        ld d,(hl)
PLY_AKYsid_LinkerNotEndSong_After:
                AKY_SID_WAIT_AND_CALL_TIMER_CODE 19

                ;Nops: 0.
        inc hl
        ld (PLY_AKYsid_PatternFrameCounter + 1),de

        ld de,PLY_AKYsid_Channel1_PtTrack + 1
        ldi
        ldi
        ld de,PLY_AKYsid_Channel2_PtTrack + 1
        ldi
        ldi
                AKY_SID_WAIT_AND_CALL_TIMER_CODE 34
                ;Nops: 0.
        ld de,PLY_AKYsid_Channel3_PtTrack + 1
        ldi
        ldi
        ld (PLY_AKYsid_PtLinker + 1),hl

        ;Resets the RegisterBlocks of the channels.
        ld a,1
        ld (PLY_AKYsid_Channel1_WaitBeforeNextRegisterBlock + 1),a  ;We shouldn't need this because always 1, but this reduces the stabilization complexity.
        ld (PLY_AKYsid_Channel2_WaitBeforeNextRegisterBlock + 1),a
        ld (PLY_AKYsid_Channel3_WaitBeforeNextRegisterBlock + 1),a
                
                AKY_SID_WAIT_AND_CALL_TIMER_CODE 32
PLY_AKYsid_PatternFrameManagement_End:
                ;Nops: 0.





;Reading the Track - channel 1.
;----------------------------------------
                ;Declares a macro used by every channel.
                MACRO PLY_AKYSID_READ_TRACK channelNumber            ; ---------------------------------------------------------------
        channelIndex = {channelNumber} - 1
PLY_AKYsid_Channel{channelNumber}_WaitBeforeNextRegisterBlock: ld a,1        ;Frames to wait before reading the next RegisterBlock. 0 = finished.
        dec a
        jr z,PLY_AKYsid_Channel{channelNumber}_RegisterBlock_Finished
        ld (PLY_AKYsid_Channel{channelNumber}_WaitBeforeNextRegisterBlock + 1),a
                ;Nops: 9.
                AKY_SID_WAIT_NOPS 18-9-3
        jr PLY_AKYsid_Channel{channelNumber}_RegisterBlock_Process

PLY_AKYsid_Channel{channelNumber}_RegisterBlock_Finished:
                ;Nops: 6.
        ;This RegisterBlock is finished. Reads the next one from the Track.
        ;Obviously, starts at the initial state.
        ld a,PLY_AKYsid_OPCODE_OR_A
        ld (PLY_AKYsid_Channel{channelNumber}_RegisterBlockLineState_Opcode),a
        ;Also, considers there is no SID on this channel. It will be set again on the IS if needed.
        xor a
        ld (PLY_AKYsid_Channel{channelIndex}IsSidActivated),a
dknr3 (void):
PLY_AKYsid_Channel{channelNumber}_PtTrack: ld hl,0            ;Points on the Track.
        ld de,PLY_AKYsid_Channel{channelNumber}_WaitBeforeNextRegisterBlock + 1                               ;Gets the duration.
        ldi
                AKY_SID_WAIT_AND_CALL_TIMER_CODE 28
                ;Nops: 0.
        ld de,PLY_AKYsid_Channel{channelNumber}_PtRegisterBlock + 1   ;Reads the RegisterBlock address.
        ldi
        ldi
        ld (PLY_AKYsid_Channel{channelNumber}_PtTrack + 1),hl

        ;A is the duration of the block.
PLY_AKYsid_Channel{channelNumber}_RegisterBlock_Process:
                AKY_SID_WAIT_AND_CALL_TIMER_CODE 18
                ENDM            ; ---------------------------------------------------------------


        PLY_AKYSID_READ_TRACK 1
        PLY_AKYSID_READ_TRACK 2
        PLY_AKYSID_READ_TRACK 3







;Reading the RegisterBlock.
;----------------------------------------

;Reading the RegisterBlock - Channel 1
;----------------------------------------

        
                ;Nops: 0.

        ;In B, R7 with default values: fully sound-open but noise-close.
        ;R7 has been shift twice to the left, it will be shifted back as the channels are treated.
dknr3 (void): ld bc,%11100000 * 256 + 255                     ;C is 255 to prevent the following LDIs to decrease B.

                ;Declares a macro used by every channel.
                MACRO PLY_AKYSID_READ_REGISTER_BLOCK channelNumber,lsbRegisterInArray           ; ---------------------------------------------------------------

                ;Nops: 3.
        ld hl,PLY_AKYsid_Channel{channelNumber}_RegisterBlock_Return
        ld (PLY_AKYsid_ReadRegisterBlock_ReturnJp + 1),hl
dknr3 (void):
PLY_AKYsid_Channel{channelNumber}_PtRegisterBlock: ld hl,0                   ;Points on the data of the RegisterBlock to read.
                AKY_SID_WAIT_AND_CALL_TIMER_CODE 14
                ;Nops: 0.
PLY_AKYsid_Channel{channelNumber}_RegisterBlockLineState_Opcode: or a        ;"or a" if initial state, "scf" (#37) if non-initial state.
        ld ix,PLY_AKYsid_RegisterArray_{lsbRegisterInArray}
        nop : nop
        jp PLY_AKYsid_ReadRegisterBlock                 ;The subroutine must exit with nop 3 (because of the last return).
PLY_AKYsid_Channel{channelNumber}_RegisterBlock_Return:
                ;Nops: 3 (because of the return).
        ld a,PLY_AKYsid_OPCODE_SCF
        ld (PLY_AKYsid_Channel{channelNumber}_RegisterBlockLineState_Opcode),a
        ld (PLY_AKYsid_Channel{channelNumber}_PtRegisterBlock + 1),hl        ;This is new pointer on the RegisterBlock.
                
                AKY_SID_WAIT_AND_CALL_TIMER_CODE 14         ;Must end with nops: 0.


                ENDM            ; ---------------------------------------------------------------

        PLY_AKYSID_READ_REGISTER_BLOCK 1,R0

        ;Shifts the R7 for the next channels.
        srl b           ;Not RR, because we have to make sure the b6 is 0, else no more keyboard (on CPC)!
        nop             ;To match the "ld bc" of channel 1.
        PLY_AKYSID_READ_REGISTER_BLOCK 2,R2

        ;Shifts the R7 for the next channels.
        rr b            ;Safe to use RR, we don't care if b7 of R7 is 0 or 1.
        nop
        PLY_AKYSID_READ_REGISTER_BLOCK 3,R4

                ;Nops: 0.

        ;Register 7 is in B.
        ld a,b
        ld (PLY_AKYsid_RegisterArray_R7),a


        ;Which channel has SID activated? (0, 1, 2, PLY_AKYsid_SidChannelWhenOff for none).
        ld b,PLY_AKYsid_SidChannelWhenOff  ;End result.
        ld c,0
        ld a,(PLY_AKYsid_Channel0IsSidActivated)
        or a
        jr z,.noChannel0
        ld b,c
.noChannel0
        inc c
        ld a,(PLY_AKYsid_Channel1IsSidActivated)
        or a
        jr z,.noChannel1
        ld b,c
.noChannel1
        inc c
        ld a,(PLY_AKYsid_Channel2IsSidActivated)
        or a
        jr z,.noChannel2
        ld b,c
.noChannel2
                AKY_SID_WAIT_AND_CALL_TIMER_CODE(35)
.afterChannelTest
        TICKER START afterChannelTestDuration
        ld a,b          ;The channel (0, 1, 2) register where to play SID, or PLY_AKYsid_SidChannelWhenOff if not used.
        add a,a
        add a,a
        ld hl,PLY_AKYsid_SIDRegisterVolumeTable
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)               ;The register of SID (or a fake one).
        ld (PLY_AKYsid_SidPsgRegister),a        ;Only useful for external programs, if needed a keyboard test, to select back the SID PSG register.
        ld ixl,a
        inc hl
        ld e,(hl)               ;Gets where to get the SID high-shelf volume from (R8, R9, R10).
        inc hl
        ld d,(hl)
        ld (PLY_AKYsid_SIDRegisterArrayPt + 1),de
        TICKER STOP
                AKY_SID_WAIT_AND_CALL_TIMER_CODE(afterChannelTestDuration)
                ;AKY_SID_WAIT_AND_CALL_TIMER_CODE COUNTNOPS(".afterChannelTest", "$")

;Play the PSG registers.
;----------------------------------------

        ld h,#f4
        ld de,#f680
        ld bc,#f6c0

        AKY_SID_WAIT_AND_CALL_TIMER_CODE 8

        MACRO PLY_AKYsid_SendRegister register,compensate
                ld a,(PLY_AKYsid_RegisterArray_R{register})
                ld l,a
PLY_AKYsid_SendRegister_Register{register} ld a,{register}
                ld b,h
                        IF {compensate} > 0
                                ;We went too far. Add a shorter compensation for one exact line.
                                AKY_SID_WAIT_AND_CALL_TIMER_CODE 15
                        ELSE
                                AKY_SID_WAIT_AND_CALL_TIMER_CODE 8
                        ENDIF
                out (c),a       ;f400 + register.
                ld b,d
                out (c),c       ;f6c0.
                out (c),0       ;f600.
                ld b,h
                out (c),l       ;f400 + value.
                ld b,d
                out (c),e       ;f680
                out (c),0       ;f600.
                ;27
                ;Switches back to SID volume register... Sadly, a tad too slow, hence the compensation above.
                ld b,h
                ld a,ixl
                out (c),a       ;f400 + register.
                ld b,d
                out (c),c       ;f6c0
                out (c),0       ;f600.
                
                ld iy,$ + 5
                ret
        ENDM

                ;Nops: 0.

        PLY_AKYsid_SendRegister 0,0
        PLY_AKYsid_SendRegister 1,1
        PLY_AKYsid_SendRegister 2,1
        PLY_AKYsid_SendRegister 3,1
        PLY_AKYsid_SendRegister 4,1
        PLY_AKYsid_SendRegister 5,1
        PLY_AKYsid_SendRegister 6,1
        PLY_AKYsid_SendRegister 7,1

                ;Nops: 7.



        ;When sid is on, gets the related volume (it could set the hardware envelope!) and sets it to the SID microcode.
PLY_AKYsid_SIDRegisterArrayPt ld a,(PLY_AKYsid_RegisterArray_R8)
        set 7,a         ;For PSG optimisation.
        ld (PLY_AKYsid_SidHighShelf.volume + 1),a


        ;In order to remove an ugly perturbation, the PSG register related to the SID volume must NOT be double-set.
        ;To manage this simply, direct the register to a dummy PSG register.
        ld b,PLY_AKYsid_SidVolumeRegisterOff

        ld a,8
        cp ixl
        jr nz,.pastR8TestIfSid          ;If this register IS the SID, do NOT write values to it.
        ld a,b
.pastR8TestIfSid
        ld (PLY_AKYsid_SendRegister_Register8 + 1),a

                AKY_SID_WAIT_AND_CALL_TIMER_CODE 30

        ld b,PLY_AKYsid_SidVolumeRegisterOff       ;B has been modified by the alt code.
        ld a,9
        cp ixl
        jr nz,.pastR9TestIfSid
        ld a,b
.pastR9TestIfSid
        ld (PLY_AKYsid_SendRegister_Register9 + 1),a

        ld a,10
        cp ixl
        jr nz,.pastR10TestIfSid
        ld a,b
.pastR10TestIfSid
        ld (PLY_AKYsid_SendRegister_Register10 + 1),a




                ;Nops: 24.

        ;Any new data? If yes, prepares the next RET table and then switches to it.
PLY_AKYsid_SidHash ld a,0
PLY_AKYsid_SidPreviousHash cp 0
        jr nz,.newData
                AKY_SID_WAIT_AND_CALL_TIMER_CODE_AND_JUMP_TO PLY_AKYsid_AfterNewSid, 30
.newData
        ld (PLY_AKYsid_SidPreviousHash + 1),a

                AKY_SID_WAIT_AND_CALL_TIMER_CODE 35


PLY_AKYsid_RetTableUsed ld a,0             ;0 = RetTable1, else RetTable2.
        or a
        jp z,PLY_AKYsid_RetTable1Used   ;JP, not JR, to have the same nops.

        MACRO PLY_AKYsid_MANAGE_SWITCH_RET_TABLE currentRetTableIndex,nextRetTableIndex
                ;Nops: 6.

        ;Clears the previously encoded low-shelf/loop before writing the new ones.
PLY_AKYsid_LowShelfAddressInTabRet{nextRetTableIndex} ld hl,PLY_AKYsid_RetTable1_InitialLowShelf - PLY_AKYsid_RetTable1 + PLY_AKYsid_RetTable{nextRetTableIndex}
        ld bc,PLY_AKYsid_CodeNothing               ;Could be optimized by CodeNothing in 0...
        ld (hl),c
        inc hl
        ld (hl),b
PLY_AKYsid_LoopAddressInTabRet{nextRetTableIndex} ld hl,PLY_AKYsid_RetTable1_InitialLoop - PLY_AKYsid_RetTable1 + PLY_AKYsid_RetTable{nextRetTableIndex}
        ld (hl),c
        inc hl
        ld (hl),b

        ;Encodes the new periods.
        ld hl,(PLY_AKYsid_PendingLowShelfDoublePeriod)          ;The period is already doubled.
        ld de,PLY_AKYsid_RetTable{nextRetTableIndex}
                AKY_SID_WAIT_AND_CALL_TIMER_CODE 35
        add hl,de
        ld (PLY_AKYsid_LowShelfAddressInTabRet{nextRetTableIndex} + 1),hl         ;Stores to clean later.
        ld (hl),lo(PLY_AKYsid_SidLowShelf)
        inc hl
        ld (hl),hi(PLY_AKYsid_SidLowShelf)

        ld hl,(PLY_AKYsid_PendingLoopDoublePeriod)              ;The period is already doubled.
        add hl,de
        ld (PLY_AKYsid_LoopAddressInTabRet{nextRetTableIndex} + 1),hl             ;Stores to clean later.
        ld (hl),lo(PLY_AKYsid_CodeLoopRetTable{nextRetTableIndex})
        inc hl
                        AKY_SID_WAIT_AND_CALL_TIMER_CODE 34
        ld (hl),hi(PLY_AKYsid_CodeLoopRetTable{nextRetTableIndex})
       
        ld hl,(PLY_AKYsid_LoopAddressInTabRet{currentRetTableIndex} + 1)
        ld (hl),lo(PLY_AKYsid_CodeGotoBeginningOfRetTable{nextRetTableIndex})
        inc hl
        ld (hl),hi(PLY_AKYsid_CodeGotoBeginningOfRetTable{nextRetTableIndex})

        ENDM            ;----------------------------------------------------------------------


        ;The current RET Table is 1, so changes the 2 in the "background".
        PLY_AKYsid_MANAGE_SWITCH_RET_TABLE 2, 1

        AKY_SID_WAIT_AND_CALL_TIMER_CODE_AND_JUMP_TO PLY_AKYsid_AfterNewSid, 16

PLY_AKYsid_RetTable1Used

        ;The current RET Table is 1, so changes the 2 in the "background".
        PLY_AKYsid_MANAGE_SWITCH_RET_TABLE 1, 2
                                        
        AKY_SID_WAIT_AND_CALL_TIMER_CODE_AND_JUMP_TO PLY_AKYsid_AfterNewSid, 16


PLY_AKYsid_AfterNewSid
        ;Must be 0 nops.






        ;We can set the low-shelf volume at any time without interfering, so let's do it now.
PLY_AKYsid_PendingLowShelfVolume ld a,0         ;Bit 7 is already 1.
        ld (PLY_AKYsid_SidLowShelf.volume + 1),a           ;TO IMPROVE? Should be done only on the next TabRet, IF change, else now. Would be cleaner!

        ld h,#f4
        ld de,#f680
        ld bc,#f6c0

                AKY_SID_WAIT_AND_CALL_TIMER_CODE 14

        ;Must be 0 nops here.
        PLY_AKYsid_SendRegister 8,0
        PLY_AKYsid_SendRegister 9,1
        PLY_AKYsid_SendRegister 10,1
        PLY_AKYsid_SendRegister 11,1
        PLY_AKYsid_SendRegister 12,1
        ;Nops: 7.


;Register 13
PLY_AKYsid_PsgRegister13_Code
        ld a,(PLY_AKYsid_RegisterArray_R13)
        
PLY_AKYsid_PsgRegister13_Retrig: cp 255                         ;If IsRetrig?, force the R13 to be triggered.
        jr nz,.playR13

                AKY_SID_WAIT_AND_CALL_TIMER_CODE_AND_JUMP_TO PLY_AKYsid_Play_ReturnJp, 15

.playR13
        ld (PLY_AKYsid_PsgRegister13_Retrig + 1),a
        
                AKY_SID_WAIT_AND_CALL_TIMER_CODE 20
        PLY_AKYsid_SendRegister 13,0
                AKY_SID_WAIT_AND_CALL_TIMER_CODE 7

dknr3 (void)
PLY_AKYsid_Play_ReturnJp        jp 0

;Points on the volume registers to use, for each channel.
PLY_AKYsid_SIDRegisterVolumeTable
        ;Index 0.
        db 8
        dw PLY_AKYsid_RegisterArray_R8
        db 0    ;Padding.

        ;Index 1.
        db 9
        dw PLY_AKYsid_RegisterArray_R9
        db 0    ;Padding.

        ;Index 2.
        db 10
        dw PLY_AKYsid_RegisterArray_R10
        db 0    ;Padding.

        ;When SID is off.
        ;Index 3.
        ASSERT PLY_AKYsid_SidChannelWhenOff == 3
        db PLY_AKYsid_SidVolumeRegisterOff
        dw PLY_AKYsid_FakeValue

PLY_AKYsid_FakeValue db 0
PLY_AKYsid_SidPsgRegister db PLY_AKYsid_SidVolumeRegisterOff

;The stored PSG registers. Do NOT change the order!
dkbs (void):
PLY_AKYsid_RegisterArray
PLY_AKYsid_RegisterArray_R0 db 0
PLY_AKYsid_RegisterArray_R1 db 0
PLY_AKYsid_RegisterArray_R2 db 0
PLY_AKYsid_RegisterArray_R3 db 0
PLY_AKYsid_RegisterArray_R4 db 0
PLY_AKYsid_RegisterArray_R5 db 0
PLY_AKYsid_RegisterArray_R6 db 0

PLY_AKYsid_RegisterArray_R8 db 0
PLY_AKYsid_RegisterArray_R7 db 0     ;Also used as padding.
PLY_AKYsid_RegisterArray_R9 db 0
PLY_AKYsid_RegisterArray_R11 db 0    ;Indirect padding.
PLY_AKYsid_RegisterArray_R10 db 0
PLY_AKYsid_RegisterArray_R12 db 0    ;Indirect padding.

PLY_AKYsid_Channel0Index db 0        ;To reach the PSG channel from the generic ReadBlock methods.
PLY_AKYsid_RegisterArray_R13 db 0    ;Indirect padding.
PLY_AKYsid_Channel1Index db 1
        db 0    ;Padding.
PLY_AKYsid_Channel2Index db 2
        db 0    ;Padding.

PLY_AKYsid_Channel0IsSidActivated db 0     ;0 if not activated on this channel.
        db 0    ;Padding.
PLY_AKYsid_Channel1IsSidActivated db 0
        db 0    ;Padding.
PLY_AKYsid_Channel2IsSidActivated db 0







PLY_AKYsid_RegisterArray_LsbSoftwarePeriod_Offset equ PLY_AKYsid_RegisterArray_R0 - PLY_AKYsid_RegisterArray
PLY_AKYsid_RegisterArray_MsbSoftwarePeriod_Offset equ PLY_AKYsid_RegisterArray_R1 - PLY_AKYsid_RegisterArray_R0
PLY_AKYsid_RegisterArray_Volume_Offset equ PLY_AKYsid_RegisterArray_R8 - PLY_AKYsid_RegisterArray_R0
PLY_AKYsid_RegisterArray_ChannelIndex_Offset equ PLY_AKYsid_Channel0Index - PLY_AKYsid_RegisterArray_R0
PLY_AKYsid_RegisterArray_IsSidActivated_Offset equ PLY_AKYsid_Channel0IsSidActivated - PLY_AKYsid_RegisterArray_R0
        ASSERT PLY_AKYsid_RegisterArray_LsbSoftwarePeriod_Offset == 0
        ASSERT PLY_AKYsid_RegisterArray_MsbSoftwarePeriod_Offset == 1

        ;Offset between each volume and software period must be the same.
        ASSERT PLY_AKYsid_RegisterArray_R9 - PLY_AKYsid_RegisterArray_R2 == PLY_AKYsid_RegisterArray_Volume_Offset
        ASSERT PLY_AKYsid_RegisterArray_R10 - PLY_AKYsid_RegisterArray_R4 == PLY_AKYsid_RegisterArray_Volume_Offset
        ;The same for the channels.
        ASSERT PLY_AKYsid_Channel1Index - PLY_AKYsid_RegisterArray_R2 == PLY_AKYsid_Channel0Index - PLY_AKYsid_RegisterArray_R0
        ASSERT PLY_AKYsid_Channel2Index - PLY_AKYsid_RegisterArray_R4 == PLY_AKYsid_Channel0Index - PLY_AKYsid_RegisterArray_R0
        ;The same for the SID activated?.
        ASSERT PLY_AKYsid_Channel1IsSidActivated - PLY_AKYsid_RegisterArray_R2 == PLY_AKYsid_Channel0IsSidActivated - PLY_AKYsid_RegisterArray_R0
        ASSERT PLY_AKYsid_Channel2IsSidActivated - PLY_AKYsid_RegisterArray_R4 == PLY_AKYsid_Channel0IsSidActivated - PLY_AKYsid_RegisterArray_R0








;Generic code interpreting the RegisterBlock
;IN:    HL = First byte.
;       B  = Shift R7.
;       Carry = 0 = initial state, 1 = non-initial state.
;----------------------------------------------------------------

PLY_AKYsid_ReadRegisterBlock:
                ;Nops: 10.

        ;Gets the first byte of the line. What type? Jump to the matching code thanks to the carry.
        ld a,(hl)
        inc hl
        jp c,PLY_AKYsid_RRB_NonInitialState

        ;Initial state.
        ;SID?
        ld d,a                  ;A must be saved!
        and %10000011
        cp %10000000
        jr z,PLY_AKYsid_IS_SID

        ;No SID.
        ld a,d
        and %00000011
        add a,a
        add a,a
        ld e,a
        ld a,d                  ;Retrieves A, which is supposed to be shifted in the original code.
        rra
        rra
        ld d,0
                AKY_SID_WAIT_AND_CALL_TIMER_CODE 35
                ;Nops: 0.
        ld iy,PLY_AKYsid_IS_JPTable
        add iy,de
        jp (iy)
PLY_AKYsid_IS_JPTable:
        jp PLY_AKYsid_RRB_IS_NoSoftwareNoHardware          ;%00
        nop
        jp PLY_AKYsid_RRB_IS_SoftwareOnly                  ;%01
        nop
        jp PLY_AKYsid_RRB_IS_HardwareOnly                  ;%10
        nop
        jp PLY_AKYsid_RRB_IS_SoftwareAndHardware           ;%11

;SID is present for IS.
PLY_AKYsid_IS_SID
                AKY_SID_WAIT_AND_CALL_TIMER_CODE 25
        ;Gets the low-shelf volume, b2-b5.
        ld a,d
        rra
        rra
        and %1111

        ld (.saveBC + 1),bc             ;Shit code...
        ld bc,.return
        AKY_SID_WAIT_AND_CALL_TIMER_CODE_AND_JUMP_TO PLY_AKYsid_SID_Common_ReadDuration,14
.return
.saveBC ld bc,0

        ;10 Nops after the JP.

        or a                    ;Because still on IS.
        jp PLY_AKYsid_ReadRegisterBlock

        ;Common code to read the SID parameter, common to BOTH by IS and NIS.
        ;HL = music data, pointing after the low-shelf volume.
        ;A  = low-shelf volume, 4 bits.
        ;BC = return address.
PLY_AKYsid_SID_Common_ReadDuration
        TICKER START PLY_AKYsid_SID_Common_ReadDurationDuration
                ;Nops: 0.
        ld (.returnJp + 1),bc

        set 7,a         ;For PSG optimization.
        ld (PLY_AKYsid_PendingLowShelfVolume + 1),a
        ex de,hl        ;DE = pointer on data.

        ;Reads the high-shelf duration. The low-shelf code is encoded after this in the RET table.

        ld a,(de)
        inc de
        ld l,a
        ld h,0
        add hl,hl               ;*2.
        ;ld bc,RetTable1          ;Starts with the Fast RET table.
        ;add hl,bc
        ld (PLY_AKYsid_PendingLowShelfDoublePeriod),hl
        TICKER STOP

                AKY_SID_WAIT_AND_CALL_TIMER_CODE(PLY_AKYsid_SID_Common_ReadDurationDuration)
               ; AKY_SID_WAIT_AND_CALL_TIMER_CODE COUNTNOPS("PLY_AKYsid_SID_Common_ReadDuration", "$")
.part2
        TICKER START part2Duration
        ;The same for the low-shelf duration.
        ld a,(de)
        dec a                   ;Because the loop is written as an event, but it must not be part of the timing.
        ;inc de                 ;NOT decreased yet. See below.
        ld c,a
        ld b,0

        ;*2...
        add a,c
        ld c,a
        ld a,b
        adc a,0
        ld b,a
        add hl,bc               ;Adds the low-shelf duration to where the low-shelf was.
        ld (PLY_AKYsid_PendingLoopDoublePeriod),hl
        ex de,hl        ;HL points again on the next data.
        TICKER STOP
                AKY_SID_WAIT_AND_CALL_TIMER_CODE(part2Duration)
                ;                 AKY_SID_WAIT_AND_CALL_TIMER_CODE COUNTNOPS(".part2", "$")
.part3
        TICKER START part3Duration
        ;Calculates a "hash" for the engine to determine whether the new period is different from the current one.
        ;Useful in case of the same period triggered on/off/on.
        ld a,(hl)
        or a
        rra                   ;Great hash! :). This is quite fragile however...
        rra
        rra
        rra
        dec hl
        add a,(hl)
        inc hl
        inc hl
        ld (PLY_AKYsid_SidHash + 1),a
        ld (ix + PLY_AKYsid_RegisterArray_IsSidActivated_Offset),a         ;No period should be 0, so this is safe.
        TICKER STOP
                AKY_SID_WAIT_AND_CALL_TIMER_CODE(part3Duration)
                ;                AKY_SID_WAIT_AND_CALL_TIMER_CODE COUNTNOPS(".part3", "$")
                ;10 nops after the jump, restore BC, and the return to the loop. Close!
.returnJp jp 0





;Generic code interpreting the RegisterBlock - Initial state.
;----------------------------------------------------------------
;IN:    HL = Points after the first byte.
;       A = First byte, twice shifted to the right (type removed).
;       B = Register 7. All sounds are open (0) by default, all noises closed (1). The code must put ONLY bit 2 and 5 for sound and noise respectively. NOT any other bits!
;       C = May be used as a temp. BUT must NOT be 0, as ldi will decrease it, we do NOT want B to be decreased!!
;       D = channel index (0, 1, 2). Useful for SID, can be dismissed after SID is managed (watch out for loop+SID!).
;       IX = Points on a register array for THIS channel.
;       IY = May be used as a temp, but used for SID return.
;       SP = Used by SID (ret to call next SID signal).
;Do NOT modify HL', DE', BC'! Used by SID.

;OUT:   HL MUST point after the structure.
;       B = updated (ONLY bit 2 and 5).

PLY_AKYsid_RRB_NoiseChannelBit equ 5          ;Bit to modify to set/reset the noise channel.
PLY_AKYsid_RRB_SoundChannelBit equ 2          ;Bit to modify to set/reset the sound channel.


PLY_AKYsid_RRB_IS_NoSoftwareNoHardware:
                ;Nops: 13.

        ;No software no hardware.
        rra                     ;Noise?
        jr c,PLY_AKYsid_RRB_IS_NoSoftwareNoHardware_ReadNoise
                AKY_SID_WAIT_NOPS 13 - 5
        jr PLY_AKYsid_RRB_IS_NoSoftwareNoHardware_ReadNoise_End
PLY_AKYsid_RRB_IS_NoSoftwareNoHardware_ReadNoise:
        ;There is a noise. Reads it.
        ld de,PLY_AKYsid_RegisterArray_R6
        ldi                     ;Safe for B, C is not 0. Preserves A.

        ;Opens the noise channel.
        res PLY_AKYsid_RRB_NoiseChannelBit, b
PLY_AKYsid_RRB_IS_NoSoftwareNoHardware_ReadNoise_End:
                ;Nops: 27.
                
PLY_AKYsid_RRB_IS_NoSoftwareNoHardware_ReadVolume:
        ;The volume is now in b0-b3.
        ;and %1111      ;No need, the bit 7 was 0.

        ;Sends the volume.
        ld (ix + PLY_AKYsid_RegisterArray_Volume_Offset),a

        ;Closes the sound channel.
        set PLY_AKYsid_RRB_SoundChannelBit, b

                AKY_SID_WAIT_AND_CALL_TIMER_CODE_AND_JUMP_TO PLY_AKYsid_ReadRegisterBlock_ReturnJp, 34
        ;jp PLY_AKYsid_ReadRegisterBlock_ReturnJp


;---------------------
PLY_AKYsid_RRB_IS_HardwareOnly
                ;Nops: 13.

        ;Retrig?
        rra
        jr c,PLY_AKYsid_RRB_IS_HO_Retrig
                AKY_SID_WAIT_NOPS 4
        jr PLY_AKYsid_RRB_IS_HO_AfterRetrig
PLY_AKYsid_RRB_IS_HO_Retrig:
        set 7,a                         ;A value to make sure the retrig is performed, yet A can still be use.
        ld (PLY_AKYsid_PsgRegister13_Retrig + 1),a
PLY_AKYsid_RRB_IS_HO_AfterRetrig:
                AKY_SID_WAIT_AND_CALL_TIMER_CODE 23

        ;Noise?
        rra
        jr c,PLY_AKYsid_RRB_IS_HO_Noise
                AKY_SID_WAIT_NOPS (10 - 3 + 1)
        jr PLY_AKYsid_RRB_IS_HO_AfterNoise
PLY_AKYsid_RRB_IS_HO_Noise        ;Reads the noise.
        ld de,PLY_AKYsid_RegisterArray_R6
        ldi                     ;Safe for B, C is not 0. Preserves A.
        ;Opens the noise channel.
        res PLY_AKYsid_RRB_NoiseChannelBit, b
PLY_AKYsid_RRB_IS_HO_AfterNoise:
                AKY_SID_WAIT_AND_CALL_TIMER_CODE 14

        ;The envelope.
        and %1111
        ld (PLY_AKYsid_RegisterArray_R13),a

        ;Copies the hardware period.
        ld de,PLY_AKYsid_RegisterArray_R11
        ldi
        ldi

        ;Closes the sound channel.
        set PLY_AKYsid_RRB_SoundChannelBit, b

        ;Sets the hardware volume.
        ld (ix + PLY_AKYsid_RegisterArray_Volume_Offset),#10

        AKY_SID_WAIT_AND_CALL_TIMER_CODE_AND_JUMP_TO PLY_AKYsid_ReadRegisterBlock_ReturnJp, 27


;---------------------
PLY_AKYsid_RRB_IS_SoftwareOnly:
                ;Nops: 13.

        ;Software only. Structure: 0vvvvntt.
        ;Noise?
        rra
        jr c,PLY_AKYsid_RRB_IS_SoftwareOnly_Noise
                AKY_SID_WAIT_NOPS 8
        jr PLY_AKYsid_RRB_IS_SoftwareOnly_AfterNoise
PLY_AKYsid_RRB_IS_SoftwareOnly_Noise:
        ;Noise. Reads it.
        ld de,PLY_AKYsid_RegisterArray_R6
        ldi                     ;Safe for B, C is not 0. Preserves A.

        ;Opens the noise channel.
        res PLY_AKYsid_RRB_NoiseChannelBit, b
PLY_AKYsid_RRB_IS_SoftwareOnly_AfterNoise:
                ;Nops: 27.

        ;Reads the volume (now b0-b3).
        and %1111
        ld (ix + PLY_AKYsid_RegisterArray_Volume_Offset),a
                AKY_SID_WAIT_AND_CALL_TIMER_CODE 34
                ;Nops: 0.

        ;Reads the software period.
        ld a,(hl)
        inc hl
        ld (ix + PLY_AKYsid_RegisterArray_LsbSoftwarePeriod_Offset),a

        ld a,(hl)
        inc hl
        ld (ix + PLY_AKYsid_RegisterArray_MsbSoftwarePeriod_Offset),a

                AKY_SID_WAIT_AND_CALL_TIMER_CODE_AND_JUMP_TO PLY_AKYsid_ReadRegisterBlock_ReturnJp, 18
        ;jp PLY_AKYsid_ReadRegisterBlock_ReturnJp





;---------------------
PLY_AKYsid_RRB_IS_SoftwareAndHardware:
                ;Nops: 13.

        ;Retrig?
        rra
        jr c,PLY_AKYsid_RRB_IS_SAH_Retrig
                AKY_SID_WAIT_NOPS 4
        jr PLY_AKYsid_RRB_IS_SAH_AfterRetrig
PLY_AKYsid_RRB_IS_SAH_Retrig:
        set 7,a                         ;A value to make sure the retrig is performed, yet A can still be use.
        ld (PLY_AKYsid_PsgRegister13_Retrig + 1),a
PLY_AKYsid_RRB_IS_SAH_AfterRetrig:
                AKY_SID_WAIT_AND_CALL_TIMER_CODE 23

        ;Noise?
        rra
        jr c,PLY_AKYsid_RRB_IS_SAH_Noise
                AKY_SID_WAIT_NOPS 8
        jr PLY_AKYsid_RRB_IS_SAH_AfterNoise
PLY_AKYsid_RRB_IS_SAH_Noise:
        ;Reads the noise.
        ld de,PLY_AKYsid_RegisterArray_R6
        ldi                     ;Safe for B, C is not 0. Preserves A.
        ;Opens the noise channel.
        res PLY_AKYsid_RRB_NoiseChannelBit, b
PLY_AKYsid_RRB_IS_SAH_AfterNoise:
                ;Nops: 14.

        ;The envelope.
        and %1111
        ld (PLY_AKYsid_RegisterArray_R13),a

        ;Reads the software period.
        ld a,(hl)
        inc hl
        ld (ix + PLY_AKYsid_RegisterArray_LsbSoftwarePeriod_Offset),a

        ld a,(hl)
        inc hl
                AKY_SID_WAIT_AND_CALL_TIMER_CODE 33
        ld (ix + PLY_AKYsid_RegisterArray_MsbSoftwarePeriod_Offset),a

        ;Sets the hardware volume.
        ld (ix + PLY_AKYsid_RegisterArray_Volume_Offset),#10

        ;Copies the hardware period.
        ld de,PLY_AKYsid_RegisterArray_R11
        ldi
        ldi

                AKY_SID_WAIT_AND_CALL_TIMER_CODE_AND_JUMP_TO PLY_AKYsid_ReadRegisterBlock_ReturnJp, 24
        ;jp PLY_AKYsid_ReadRegisterBlock_ReturnJp






;Generic code interpreting the RegisterBlock - Non initial state. See comment about the Initial state for the registers ins/outs.
;----------------------------------------------------------------
PLY_AKYsid_RRB_NonInitialState:
                ;Nops: 17.
                AKY_SID_WAIT_AND_CALL_TIMER_CODE 17
                ;Nops: 0
.start
        ;SID?
        cp %00010000
        jr z,PLY_AKYsid_NIS_SID

        ;Tests directly if loop, which simplifies the stabililization.
        cp %00001000
        jr nz,.noLoop
        ;Loops. Reads the next pointer to this RegisterBlock.
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a

        ;Makes another iteration to read the new data. It may be a SID!
        ld a,(hl)
        inc hl
        AKY_SID_WAIT_AND_CALL_TIMER_CODE_AND_JUMP_TO .start, 19

.noLoop
        ld d,a                          ;A must be saved!
        and %00000011
        add a,a
        add a,a
        ld e,a

        ld a,d                          ;Retrieves A, which is supposed to be shifted in the original code.
        rra
        rra
        ld d,0
                AKY_SID_WAIT_AND_CALL_TIMER_CODE 20
                ;Nops: 0.
        ld iy,PLY_AKYsid_NIS_JPTable
        add iy,de
        jp (iy)
        ;All these codes consider there is no loop, so have a "wait" at the beginning. Except the "loop" code in %1000, which manages the loop...
PLY_AKYsid_NIS_JPTable:
        jp PLY_AKYsid_RRB_NIS_NoSoftwareNoHardware          ;%00
        nop
        jp PLY_AKYsid_RRB_NIS_SoftwareOnly                  ;%01
        nop
        jp PLY_AKYsid_RRB_NIS_HardwareOnly                  ;%10
        nop
        jp PLY_AKYsid_RRB_NIS_SoftwareAndHardware           ;%11
       

PLY_AKYsid_NIS_SID
                ;Nops: 5.
        ld a,(hl)       ;Reads the low-shelf volume (b4-b1) + isSID on bit 0.
        inc hl
        srl a
        jr c,.sidPresent
        ;Sid must be stopped.
        ld (ix + PLY_AKYsid_RegisterArray_IsSidActivated_Offset),a         ;A is 0.

                AKY_SID_WAIT_AND_CALL_TIMER_CODE 18

                AKY_SID_WAIT_NOPS (10-4)        ;To land on 10 nops after the jump.
        scf     ;NIS.
        jp PLY_AKYsid_ReadRegisterBlock

.sidPresent
        ;No need to AND A.
        ld (.saveBC + 1),bc
        ld bc,.sidReturn
        AKY_SID_WAIT_AND_CALL_TIMER_CODE_AND_JUMP_TO PLY_AKYsid_SID_Common_ReadDuration,23
.sidReturn
.saveBC ld bc,0

        scf     ;NIS.
        jp PLY_AKYsid_ReadRegisterBlock




PLY_AKYsid_RRB_NIS_NoSoftwareNoHardware:
                ;Nops: 13.

        ;No software, no hardware.
        ;No need to test the loop! It has been tested before. We can optimize from the original code.
        ld e,a                  ;Used below.

        ;Closes the sound channel.
        set PLY_AKYsid_RRB_SoundChannelBit, b

        ;Volume? bit 2 - 2.
        rra
        jr c,PLY_AKYsid_RRB_NIS_Volume
                AKY_SID_WAIT_NOPS 9 - 5
        jr PLY_AKYsid_RRB_NIS_AfterVolume
PLY_AKYsid_RRB_NIS_Volume:
        and %1111
        ld (ix + PLY_AKYsid_RegisterArray_Volume_Offset),a
PLY_AKYsid_RRB_NIS_AfterVolume:
                ;Nops: 27.
                AKY_SID_WAIT_AND_CALL_TIMER_CODE_AND_JUMP_TO PLY_AKYsid_ReadRegisterBlock_ReturnJp, 27
                ;Nops: 0.

        ;Noise? Was on bit 7, but there has been two shifts. We can't use A, it may have been modified by the volume AND.
        bit 7 - 2, e
        jr nz,PLY_AKYsid_RRB_NIS_Noise
                AKY_SID_WAIT_NOPS 13 - 5
        jp PLY_AKYsid_RRB_NIS_End
PLY_AKYsid_RRB_NIS_Noise:
        ;Noise.
        ld a,(hl)
        ld (PLY_AKYsid_RegisterArray_R6),a
        inc hl
        ;Opens the noise channel.
        res PLY_AKYsid_RRB_NoiseChannelBit, b
                ;Nops: 15
PLY_AKYsid_RRB_NIS_End
                AKY_SID_WAIT_AND_CALL_TIMER_CODE_AND_JUMP_TO PLY_AKYsid_ReadRegisterBlock_ReturnJp, 35
        ;jp PLY_AKYsid_ReadRegisterBlock_ReturnJp







;---------------------
PLY_AKYsid_RRB_NIS_SoftwareOnly
                ;Nops: 13.
        
        ;Software only. Structure: mspnoise lsp v  v  v  v  (0  1).
        ld e,a
        ;Gets the volume (already shifted).
        and %1111
        ld (ix + PLY_AKYsid_RegisterArray_Volume_Offset),a

        ;LSP? (Least Significant byte of Period). Was bit 6, but now shifted.
        bit 6 - 2, e
        jr nz,PLY_AKYsid_RRB_NIS_SoftwareOnly_LSP
                AKY_SID_WAIT_NOPS 10 - 3
        jr PLY_AKYsid_RRB_NIS_SoftwareOnly_AfterLSP
PLY_AKYsid_RRB_NIS_SoftwareOnly_LSP:
        ld a,(hl)
        inc hl
        ld (ix + PLY_AKYsid_RegisterArray_LsbSoftwarePeriod_Offset),a
PLY_AKYsid_RRB_NIS_SoftwareOnly_AfterLSP:
                ;Nops: 35.
                AKY_SID_WAIT_AND_CALL_TIMER_CODE 35
                ;Nops: 0.

        ;MSP AND/OR (Noise and/or new Noise)? (Most Significant byte of Period).
        bit 7 - 2, e
        jr nz,PLY_AKYsid_RRB_NIS_SoftwareOnly_MSPAndMaybeNoise
                AKY_SID_WAIT_AND_CALL_TIMER_CODE_AND_JUMP_TO PLY_AKYsid_ReadRegisterBlock_ReturnJp, 4
        ;jp PLY_AKYsid_ReadRegisterBlock_ReturnJp
        
PLY_AKYsid_RRB_NIS_SoftwareOnly_MSPAndMaybeNoise:
                ;Nops: 5.
        ;MSP and noise?, in the next byte. in--pppp (i = isNoise? n = newNoise? p = MSB period).
        ld a,(hl)       ;Useless bits at the end, not a problem.
        inc hl
        
        ;Sends the MSB software frequency.
        ld (ix + PLY_AKYsid_RegisterArray_MsbSoftwarePeriod_Offset),a
        
        rla     ;Carry is isNoise?
        jr c,PLY_AKYsid_RRB_NIS_SoftwareOnly_NoisePresent
                AKY_SID_WAIT_AND_CALL_TIMER_CODE_AND_JUMP_TO PLY_AKYsid_ReadRegisterBlock_ReturnJp, 17
        ;jp PLY_AKYsid_ReadRegisterBlock_ReturnJp
PLY_AKYsid_RRB_NIS_SoftwareOnly_NoisePresent:
                ;Nops: 18.
        ;Opens the noise channel.
        res PLY_AKYsid_RRB_NoiseChannelBit, b
       
        ;Is there a new noise value? If yes, gets the noise.
        rla
        jr c,PLY_AKYsid_RRB_NIS_SoftwareOnly_Noise
                AKY_SID_WAIT_NOPS 9 - 3
        jr PLY_AKYsid_RRB_NIS_SoftwareOnly_End
PLY_AKYsid_RRB_NIS_SoftwareOnly_Noise:
                ;Nops: 24
        ;Gets the noise.
        ld de,PLY_AKYsid_RegisterArray_R6
        ldi

PLY_AKYsid_RRB_NIS_SoftwareOnly_End
                AKY_SID_WAIT_AND_CALL_TIMER_CODE_AND_JUMP_TO PLY_AKYsid_ReadRegisterBlock_ReturnJp, 32
        ;jp PLY_AKYsid_ReadRegisterBlock_ReturnJp



;---------------------
PLY_AKYsid_RRB_NIS_HardwareOnly
                ;Nops: 13.

        ;Gets the envelope (initially on b2-b4, but currently on b0-b2). It is on 3 bits, must be encoded on 4. Bit 3 must be 1.
        ld e,a
        and %111
        or %1000                ;To get envelope from 8 to 15.
        ld (PLY_AKYsid_RegisterArray_R13),a

        ;Closes the sound channel.
        set PLY_AKYsid_RRB_SoundChannelBit, b

        ;Hardware volume.
        ld (ix + PLY_AKYsid_RegisterArray_Volume_Offset),#10

        ld a,e
                AKY_SID_WAIT_AND_CALL_TIMER_CODE 31

        ;LSB for hardware period? Currently on b5.
        rla
        rla
        rla
        jr c,PLY_AKYsid_RRB_NIS_HardwareOnly_LSB
                AKY_SID_WAIT_NOPS 6
        jr PLY_AKYsid_RRB_NIS_HardwareOnly_AfterLSB
PLY_AKYsid_RRB_NIS_HardwareOnly_LSB:
        ld de,PLY_AKYsid_RegisterArray_R11
        ldi
PLY_AKYsid_RRB_NIS_HardwareOnly_AfterLSB:
                ;Nops: 14.

        ;MSB for hardware period?
        rla
        jr c,PLY_AKYsid_RRB_NIS_HardwareOnly_MSB
		AKY_SID_WAIT_NOPS 6
        jr PLY_AKYsid_RRB_NIS_HardwareOnly_AfterMSB
PLY_AKYsid_RRB_NIS_HardwareOnly_MSB:
        ld de,PLY_AKYsid_RegisterArray_R12
        ldi
PLY_AKYsid_RRB_NIS_HardwareOnly_AfterMSB:
                ;Nops: 26.
        
        ;Noise or retrig?
        rla
        jp c,PLY_AKYsid_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStop          ;The retrig/noise code is shared.
        
        AKY_SID_WAIT_AND_CALL_TIMER_CODE_AND_JUMP_TO PLY_AKYsid_ReadRegisterBlock_ReturnJp, 30



;---------------------
PLY_AKYsid_RRB_NIS_SoftwareAndHardware
                ;Nops: 13.

        ;Hardware volume.
        ld (ix + PLY_AKYsid_RegisterArray_Volume_Offset),#10

        ;LSB of hardware period?
        rra
        jr c,PLY_AKYsid_RRB_NIS_SAHH_LSBH
		AKY_SID_WAIT_NOPS 6
        jr PLY_AKYsid_RRB_NIS_SAHH_AfterLSBH
PLY_AKYsid_RRB_NIS_SAHH_LSBH:
        ld de,PLY_AKYsid_RegisterArray_R11
        ldi
PLY_AKYsid_RRB_NIS_SAHH_AfterLSBH:
                AKY_SID_WAIT_AND_CALL_TIMER_CODE 31

        ;MSB of hardware period?
        rra
        jr c,PLY_AKYsid_RRB_NIS_SAHH_MSBH
                AKY_SID_WAIT_NOPS 6
        jr PLY_AKYsid_RRB_NIS_SAHH_AfterMSBH
PLY_AKYsid_RRB_NIS_SAHH_MSBH:
        ld de,PLY_AKYsid_RegisterArray_R12
        ldi
PLY_AKYsid_RRB_NIS_SAHH_AfterMSBH:
                ;Nops: 12.
        
        ;LSB of software period?
        rra
        jr c,PLY_AKYsid_RRB_NIS_SAHH_LSBS
                AKY_SID_WAIT_NOPS 9
        jr PLY_AKYsid_RRB_NIS_SAHH_AfterLSBS
PLY_AKYsid_RRB_NIS_SAHH_LSBS:
        ld e,a
        ld a,(hl)
        inc hl

        ;Sends the LSB software frequency.
        ld (ix + PLY_AKYsid_RegisterArray_LsbSoftwarePeriod_Offset),a

        ld a,e
PLY_AKYsid_RRB_NIS_SAHH_AfterLSBS:
                AKY_SID_WAIT_AND_CALL_TIMER_CODE 27

        ;MSB of software period?
        rra
        jr c,PLY_AKYsid_RRB_NIS_SAHH_MSBS
                AKY_SID_WAIT_NOPS 9
        jr PLY_AKYsid_RRB_NIS_SAHH_AfterMSBS
PLY_AKYsid_RRB_NIS_SAHH_MSBS:
        ld e,a
        ld a,(hl)
        inc hl

        ;Sends the MSB software frequency.
        ld (ix + PLY_AKYsid_RegisterArray_MsbSoftwarePeriod_Offset),a
        
        ld a,e
PLY_AKYsid_RRB_NIS_SAHH_AfterMSBS:
                ;Nops: 15.

        ;New hardware envelope?
        rra
        jr c,PLY_AKYsid_RRB_NIS_SAHH_Envelope
                AKY_SID_WAIT_NOPS 6
        jr PLY_AKYsid_RRB_NIS_SAHH_AfterEnvelope
PLY_AKYsid_RRB_NIS_SAHH_Envelope:
        ld de,PLY_AKYsid_RegisterArray_R13
        ldi
PLY_AKYsid_RRB_NIS_SAHH_AfterEnvelope:
                ;Nops: 27.

        ;Retrig and/or noise?
        rra
        jr nc,PLY_AKYsid_RRB_NIS_NoRetrigNoNoise
                   ;Must be 30. Close one!


        ;This code is shared with the HardwareOnly. It reads the Noise/Retrig byte, interprets it and exits.
        ;------------------------------------------
PLY_AKYsid_RRB_NIS_Hardware_Shared_NoiseOrRetrig_AndStop:
                ;Nops: 30.

        ;Noise or retrig. Reads the next byte.
        ld a,(hl)
        inc hl
                AKY_SID_WAIT_AND_CALL_TIMER_CODE 34

        ;Retrig?
        rra
        jr c,PLY_AKYsid_RRB_NIS_S_NOR_Retrig
                AKY_SID_WAIT_NOPS 4
        jr PLY_AKYsid_RRB_NIS_S_NOR_AfterRetrig
PLY_AKYsid_RRB_NIS_S_NOR_Retrig:
        set 7,a                         ;A value to make sure the retrig is performed, yet A can still be use.
        ld (PLY_AKYsid_PsgRegister13_Retrig + 1),a
PLY_AKYsid_RRB_NIS_S_NOR_AfterRetrig:
                ;Nops: 10.

        ;Noise? If no, nothing more to do.
        rra
        jr c,PLY_AKYsid_RRB_NIS_S_NOR_Noise
                AKY_SID_WAIT_AND_CALL_TIMER_CODE_AND_JUMP_TO PLY_AKYsid_ReadRegisterBlock_ReturnJp, 13

PLY_AKYsid_RRB_NIS_S_NOR_Noise:
                ;Nops: 14.
        ;Noise. Opens the noise channel.
        res PLY_AKYsid_RRB_NoiseChannelBit, b
        ;Is there a new noise value? If yes, gets the noise.
        rra
        jr c,PLY_AKYsid_RRB_NIS_S_NOR_SetNoise
                AKY_SID_WAIT_AND_CALL_TIMER_CODE_AND_JUMP_TO PLY_AKYsid_ReadRegisterBlock_ReturnJp, 19

PLY_AKYsid_RRB_NIS_S_NOR_SetNoise:
                ;Nops: 20.
        ;Sets the noise.
        ld (PLY_AKYsid_RegisterArray_R6),a
                AKY_SID_WAIT_AND_CALL_TIMER_CODE_AND_JUMP_TO PLY_AKYsid_ReadRegisterBlock_ReturnJp, 24

        
PLY_AKYsid_RRB_NIS_NoRetrigNoNoise
        AKY_SID_WAIT_AND_CALL_TIMER_CODE_AND_JUMP_TO PLY_AKYsid_ReadRegisterBlock_ReturnJp, 31



;RET table for the Read RegisterBlock code to know where to return.
dkps (void)
PLY_AKYsid_ReadRegisterBlock_ReturnJp jp 0
dkpe (void)





PLY_AKYsid_PendingLowShelfDoublePeriod dw 0
PLY_AKYsid_PendingLoopDoublePeriod dw 0







;SID code.
;IN:    H' = line counter
;       L' = #f6
;       IY = Return address
;MOD:
;       BC = used as temp.
;       A' = used as temp (could probably be avoided, didn't find time to find how).

;PLY_AKYsid_BRK_Sid = 1


PLY_AKYsid_SidHighShelf
        IFDEF PLY_AKYsid_BRK_Sid
.BRK
        ENDIF
        exx
.volume         ld bc,#f480
                out (c),c
                ld b,l
                out (c),c
                out (c),0
                inc h
        exx
        jp (iy)                         ;21

PLY_AKYsid_SidLowShelf
        IFDEF PLY_AKYsid_BRK_Sid
.BRK
        ENDIF

        exx
.volume         ld bc,#f480
                out (c),c
                ld b,l
                out (c),c
                out (c),0
                inc h
        exx
        jp (iy)                         ;21


PLY_AKYsid_CodeNothing
        IFDEF PLY_AKYsid_BRK_Sid
.BRK
        ENDIF

        exx
                ds 16,0
                inc h
        exx
        jp (iy)

PLY_AKYsid_CodeLoopRetTable1
        IFDEF PLY_AKYsid_BRK_Sid
.BRK
        ENDIF

        exx
                ld sp,PLY_AKYsid_RetTable1
                ds 16-3,0
                inc h
        exx
        jp (iy)

PLY_AKYsid_CodeLoopRetTable2
        IFDEF PLY_AKYsid_BRK_Sid
.BRK
        ENDIF

        exx
                ld sp,PLY_AKYsid_RetTable2
                ds 16-3,0
                inc h
        exx
        jp (iy)



PLY_AKYsid_CodeGotoBeginningOfRetTable2
        TICKER START PLY_AKYsid_CodeGotoBeginningOfRetTable2Duration
        IFDEF PLY_AKYsid_BRK_Sid
.BRK
        ENDIF

        exx
                ld sp,PLY_AKYsid_RetTable2
                inc h

                ex af,af'
                        ld a,1
                        ld (PLY_AKYsid_RetTableUsed + 1),a
                ex af,af'

                ds 5,0
        exx
        jp (iy)
        TICKER stop

        ASSERT PLY_AKYsid_CodeGotoBeginningOfRetTable2Duration == PLY_AKY_SID_MICROCODE_DURATION
        ;ASSERT COUNTNOPS('PLY_AKYsid_CodeGotoBeginningOfRetTable2', '$') == PLY_AKY_SID_MICROCODE_DURATION




PLY_AKYsid_CodeGotoBeginningOfRetTable1
        TICKER START PLY_AKYsid_CodeGotoBeginningOfRetTable1Duration
        IFDEF PLY_AKYsid_BRK_Sid
.BRK
        ENDIF

        exx
                ld sp,PLY_AKYsid_RetTable1
                inc h

                ex af,af'
                        xor a
                        ld (PLY_AKYsid_RetTableUsed + 1),a
                ex af,af'

                ds 6,0
        exx
        jp (iy)
        TICKER stop

        ASSERT PLY_AKYsid_CodeGotoBeginningOfRetTable1Duration== PLY_AKY_SID_MICROCODE_DURATION
        ;ASSERT COUNTNOPS('PLY_AKYsid_CodeGotoBeginningOfRetTable1', '$') == PLY_AKY_SID_MICROCODE_DURATION






