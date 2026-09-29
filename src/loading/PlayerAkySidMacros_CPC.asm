PLY_AKY_SID_MICROCODE_DURATION equ 21
PLY_AKY_SID_DURATION_TIMER_CODE equ PLY_AKY_SID_MICROCODE_DURATION + 7              ;+7 for the LD IX,return and RET.



        ;Waits for "nopCount" NOPs, using various opcodes.
        ;WARNING, flags may be changed!
        MACRO AKY_SID_WAIT_NOPS nopCount
                IF {nopCount} < 0
                        FAIL "Negative nop count!"
                ENDIF

                localNop = {nopCount}

                WHILE localNop > 0
                        ; ********** These are too dangerous, depending on HL!!!!
                        ;IF localNop >= 12
                        ;        ex (sp),hl
                        ;        ex (sp),hl
                        ;        localNop = localNop - 12
                        ;ELSEIF localNop >= 6
                        ;        inc (hl)
                        ;        dec (hl)
                        ;        localNop = localNop - 6
                        IF localNop >= 5
                                cp (ix)
                                localNop = localNop - 5
                        ELSEIF localNop >= 3
                                jr $ + 2
                                localNop = localNop - 3
                        ELSEIF localNop >= 2
                                cp (hl)
                                localNop = localNop - 2
                        ELSE
                                nop
                                localNop = localNop - 1
                        ENDIF
                WEND
        ENDM

        
        ;Waits for 64-"pastNops" NOPs, and call the Timer Code via RET.
        ;IX is automatically set after the declaration of the macro.
        MACRO AKY_SID_WAIT_AND_CALL_TIMER_CODE pastNops
                IF {pastNops} < 3
                        FAIL "A bit low to wait. Normal?", {pastNops}
                ELSEIF {pastNops} > (64 - PLY_AKY_SID_DURATION_TIMER_CODE)
                        FAIL "Waited too much!", {pastNops}
                ENDIF

                AKY_SID_WAIT_NOPS 64 - PLY_AKY_SID_DURATION_TIMER_CODE - {pastNops}

                ld iy,$ + 4 + 1         ;Skips the ld and ret.
                ret
        ENDM

        ;Waits for 64-"pastNops" NOP, and call the Timer Code via RET.
        ;IX is automatically set to the given return address.
        MACRO AKY_SID_WAIT_AND_CALL_TIMER_CODE_AND_JUMP_TO returnAddress, pastNops
                IF {pastNops} < 3
                        FAIL "A bit low to wait. Normal?", {v}
                ELSEIF {pastNops} > (64 - PLY_AKY_SID_DURATION_TIMER_CODE)
                        FAIL "Waited too much!", {pastNops}
                ENDIF

                AKY_SID_WAIT_NOPS 64 - PLY_AKY_SID_DURATION_TIMER_CODE - {pastNops}

                ld iy,{returnAddress}
                ret
        ENDM
