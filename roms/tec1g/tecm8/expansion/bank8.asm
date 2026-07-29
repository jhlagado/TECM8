; TECM8 expansion ROM physical bank 8: bounded binary loader and runner.

        .include "bank_ops.asmi"

        .org    0x8000

EXP_BANK          .equ    0x08
EXP_VERSION       .equ    0x01

Tecm8ExpansionBank8Entry:
        cp RUN_SVC_RUN
        jp z,runArtifact
        cp RUN_SVC_SYMBOLS
        jp z,debugListSymbols
        cp RUN_SVC_DEBUG_START
        jp z,debugStart
        cp RUN_SVC_BREAK_SYMBOL
        jp z,debugSetBreakpointSymbol
        cp RUN_SVC_DEBUG_STEP
        jp z,debugStep
        cp RUN_SVC_DEBUG_CONTINUE
        jp z,debugContinue
        cp RUN_SVC_LISTING
        jp z,debugListSourceMap
        ld a,RUN_ERR_UNKNOWN
        scf
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
runArtifact:
        call runInitialize
        call runValidateTarget
        jp c,runBadTarget
        .rcignore definite_contract_violation "Target validation is complete; no pre-call HL or flag value remains live while the artifact path is copied."
        call runPrepareArtifactPath
        jp c,runBadTarget
        ld a,TFS_ARTIFACT_KIND_BINARY
        ld (TFS_PARAM_ARTIFACT_KIND),a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_LOAD_ARTIFACT
        jp c,runStorageError
        ld hl,(TFS_PARAM_ARTIFACT_LOAD_LO)
        ld (RUN_PARAM_LOAD_LO),hl
        ld de,(TFS_PARAM_ARTIFACT_SIZE_LO)
        ld (RUN_PARAM_BYTES_LO),de
        add hl,de
        ld (RUN_PARAM_END_LO),hl
        ld hl,(TFS_PARAM_ARTIFACT_RUN_LO)
        ld (RUN_PARAM_ENTRY_LO),hl
        call runValidateLoadedRange
        jp c,runBadRange
        ld hl,RUN_TRAMPOLINE_BASE
        ld (hl),0xCD
        inc hl
        ld de,(RUN_PARAM_ENTRY_LO)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),0xC9
        call RUN_TRAMPOLINE_BASE

runProgramReturned:
        ld a,(RUN_PARAM_RETURN_COUNT)
        inc a
        ld (RUN_PARAM_RETURN_COUNT),a
        ld a,(RUN_LOAD_MAX-0x10)
        ld (RUN_PARAM_MARKER),a
        xor a
        ld (RUN_PARAM_STATUS),a
        ld (RUN_PARAM_LAST_ERROR),a
        ld a,SHL_RESULT_OK
        ld (RUN_PARAM_RESULT_LO),a
        xor a
        ld (RUN_PARAM_RESULT_HI),a
        ld a,0x88
        or a
        ret

; ---------------------------------------------------------------------------
; Source-aware debugger.
;
; Programs execute natively on a private RAM stack. RST 38h is used as a
; reversible software trap through MON3's USER_INT vector. A trap snapshots
; registers and the program stack pointer, restores the replaced byte, and
; unwinds to the bank service caller. The debugger therefore returns to the
; shell at every stop without depending on MON3's LCD breakpoint UI.
; ---------------------------------------------------------------------------

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L,IX,IY
debugListSymbols:
        call debugLoadMap
        jp c,debugStorageOrMapError
        call debugFormatSymbols
        jp c,debugBadMap
        jp debugPublishInspection

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L,IX,IY
debugListSourceMap:
        call debugLoadMap
        jp c,debugStorageOrMapError
        call debugFormatSourceMap
        jp c,debugBadMap
debugPublishInspection:
        xor a
        ld (RUN_PARAM_STATUS),a
        ld (RUN_PARAM_LAST_ERROR),a
        ld a,SHL_RESULT_OK
        ld (RUN_PARAM_RESULT_LO),a
        ld a,(DBG_PARAM_OUTPUT_COUNT)
        ld (RUN_PARAM_RESULT_HI),a
        ld a,0x88
        or a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L,IX,IY
debugStart:
        call runInitialize
        call runValidateTarget
        jp c,runBadTarget
        .rcignore definite_contract_violation "Target validation is complete; runPrepareArtifactPath owns the target pointer while preparing the debugger load."
        call runPrepareArtifactPath
        jp c,runBadTarget
        ld a,TFS_ARTIFACT_KIND_BINARY
        ld (TFS_PARAM_ARTIFACT_KIND),a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_LOAD_ARTIFACT
        jp c,runStorageError
        ld hl,(TFS_PARAM_ARTIFACT_LOAD_LO)
        ld (RUN_PARAM_LOAD_LO),hl
        ld de,(TFS_PARAM_ARTIFACT_SIZE_LO)
        ld (RUN_PARAM_BYTES_LO),de
        add hl,de
        ld (RUN_PARAM_END_LO),hl
        ld hl,(TFS_PARAM_ARTIFACT_RUN_LO)
        ld (RUN_PARAM_ENTRY_LO),hl
        call runValidateLoadedRange
        jp c,runBadRange
        ld a,(DBG_STATE_ACTIVE)
        or a
        call nz,debugRestoreAllPatches
        ld hl,DBG_STATE_BASE
        ld de,DBG_STATE_BASE+1
        ld bc,0x0028
        xor a
        ld (hl),a
        ldir
        ld hl,(MON_USER_INT)
        ld (DBG_STATE_USER_INT_LO),hl
        ld hl,debugTrap
        ld (MON_USER_INT),hl
        ld hl,(RUN_PARAM_ENTRY_LO)
        ld (DBG_STATE_PC_LO),hl
        ld hl,DBG_STACK_TOP-2
        ld (DBG_STATE_SP_LO),hl
        ld de,debugProgramFinished
        ld (hl),e
        inc hl
        ld (hl),d
        ld a,0x01
        ld (DBG_STATE_ACTIVE),a
        ld a,DBG_STOP_ENTRY
        ld (DBG_STATE_STOP_REASON),a
        jp debugPublishStopped

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L,IX,IY
debugSetBreakpointSymbol:
        ld a,(DBG_STATE_ACTIVE)
        or a
        jp z,debugNotStopped
        call debugLoadMap
        jp c,debugStorageOrMapError
        call debugFindSymbol
        jp c,debugNoSymbol
        push hl
        ld de,0x0008
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        ld (DBG_STATE_SYMBOL_LINE),a
        inc hl
        ld a,(hl)
        and 0xF0
        rrca
        rrca
        rrca
        rrca
        ld (DBG_STATE_SYMBOL_FILE),a
        pop hl
        ex de,hl
        call debugValidateProgramAddress
        jp c,debugNoSymbol
        push hl
        call debugRestoreBreakpoint
        pop hl
        ld (DBG_STATE_BP_ADDR_LO),hl
        ld a,(hl)
        ld (DBG_STATE_BP_ORIG),a
        ld (hl),DBG_TRAP_OPCODE
        ld a,0x01
        ld (DBG_STATE_BP_ARMED),a
        jp debugPublishStopped

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L,IX,IY
debugStep:
        ld a,(DBG_STATE_ACTIVE)
        or a
        jp z,debugNotStopped
        ld a,(DBG_STATE_STOP_REASON)
        cp DBG_STOP_FINISHED
        jp z,debugNotStopped
        call debugPrepareSingleStep
        jp c,debugStepError
        ld a,(DBG_STATE_BP_ARMED)
        or a
        jr nz,debugStepOrdinary
        ld hl,(DBG_STATE_BP_ADDR_LO)
        ld de,(DBG_STATE_PC_LO)
        or a
        sbc hl,de
        jr nz,debugStepOrdinary
        ld a,DBG_MODE_REARM_STEP
        jr debugResumeModeReady
debugStepOrdinary:
        ld a,DBG_MODE_STEP
        jr debugResumeModeReady

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L,IX,IY
debugContinue:
        ld a,(DBG_STATE_ACTIVE)
        or a
        jp z,debugNotStopped
        ld a,(DBG_STATE_STOP_REASON)
        cp DBG_STOP_FINISHED
        jp z,debugNotStopped
        ld a,(DBG_STATE_BP_ARMED)
        or a
        jr nz,debugContinueOrdinary
        ld hl,(DBG_STATE_BP_ADDR_LO)
        ld de,(DBG_STATE_PC_LO)
        or a
        sbc hl,de
        jr nz,debugContinueOrdinary
        call debugPrepareSingleStep
        jp c,debugStepError
        ld a,DBG_MODE_REARM_RUN
        jr debugResumeModeReady
debugContinueOrdinary:
        ld a,DBG_MODE_RUN
debugResumeModeReady:
        ld (DBG_STATE_MODE),a
        ld (DBG_STATE_SERVICE_SP_LO),sp
        ld hl,debugTrap
        ld (MON_USER_INT),hl
        jp debugRestoreAndResume

; Compute the actual successor of the stopped instruction and replace it with
; the temporary RST 38h trap. The bounded architectural decoder supplies the
; sequential address; the control-flow cases below select a taken target.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L,IX,IY
debugPrepareSingleStep:
        call debugRestoreTemporary
        or a
        .rcignore definite_contract_violation "The sequential decoder owns HL; no pre-call pointer is consumed after it returns."
        call debugSequentialFallback
        ld (DBG_STATE_TEMP_ADDR_LO),hl
        ld de,(DBG_STATE_PC_LO)
        ld a,(de)
        cp 0x76
        jp z,debugPrepareStepBad
        cp 0xC3
        jr z,debugStepAbsoluteTarget
        cp 0xCD
        jr z,debugStepAbsoluteTarget
        cp 0xE9
        jr z,debugStepIndirectHl
        cp 0x18
        jr z,debugStepRelativeTarget
        cp 0x10
        jr z,debugStepDjnz
        cp 0xC9
        jr z,debugStepReturnTarget
        ld b,a
        and 0xC7
        cp 0xC2
        jr z,debugStepConditionalAbsolute
        ld a,b
        and 0xC7
        cp 0xC4
        jr z,debugStepConditionalAbsolute
        ld a,b
        and 0xC7
        cp 0xC0
        jr z,debugStepConditionalReturn
        ld a,b
        cp 0x20
        jr z,debugStepConditionalRelative
        cp 0x28
        jr z,debugStepConditionalRelative
        cp 0x30
        jr z,debugStepConditionalRelative
        cp 0x38
        jr z,debugStepConditionalRelative
        ld a,b
        and 0xC7
        cp 0xC7
        jr z,debugStepRstTarget
        jr debugInstallTemporary
debugStepAbsoluteTarget:
        ld hl,(DBG_STATE_PC_LO)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld (DBG_STATE_TEMP_ADDR_LO),hl
        jr debugInstallTemporary
debugStepIndirectHl:
        ld hl,(DBG_STATE_HL_LO)
        ld (DBG_STATE_TEMP_ADDR_LO),hl
        jr debugInstallTemporary
debugStepRelativeTarget:
        call debugSelectRelativeTarget
        jr debugInstallTemporary
debugStepDjnz:
        ld a,(DBG_STATE_BC_HI)
        cp 0x01
        jr z,debugInstallTemporary
        call debugSelectRelativeTarget
        jr debugInstallTemporary
debugStepReturnTarget:
        call debugSelectReturnTarget
        jr debugInstallTemporaryOrFinish
debugStepConditionalAbsolute:
        ld a,b
        call debugConditionTaken
        or a
        jr z,debugInstallTemporary
        jr debugStepAbsoluteTarget
debugStepConditionalReturn:
        ld a,b
        call debugConditionTaken
        or a
        jr z,debugInstallTemporary
        call debugSelectReturnTarget
        jr debugInstallTemporaryOrFinish
debugStepConditionalRelative:
        ld a,b
        call debugConditionTaken
        or a
        jr z,debugInstallTemporary
        call debugSelectRelativeTarget
        jr debugInstallTemporary
debugStepRstTarget:
        ld a,b
        and 0x38
        ld l,a
        ld h,0x00
        ld (DBG_STATE_TEMP_ADDR_LO),hl
debugInstallTemporary:
        ld hl,(DBG_STATE_TEMP_ADDR_LO)
        call debugValidateProgramAddress
        jr c,debugPrepareStepBad
        ld de,(DBG_STATE_BP_ADDR_LO)
        ld a,(DBG_STATE_BP_ARMED)
        or a
        jr z,debugInstallTemporaryWrite
        or a
        sbc hl,de
        jr z,debugPrepareStepDone
        ld hl,(DBG_STATE_TEMP_ADDR_LO)
debugInstallTemporaryWrite:
        ld a,(hl)
        ld (DBG_STATE_TEMP_ORIG),a
        ld (hl),DBG_TRAP_OPCODE
        ld a,0x01
        ld (DBG_STATE_TEMP_ARMED),a
debugPrepareStepDone:
        or a
        ret
debugInstallTemporaryOrFinish:
        ld hl,(DBG_STATE_TEMP_ADDR_LO)
        ld de,debugProgramFinished
        or a
        sbc hl,de
        jr z,debugPrepareStepDone
        jr debugInstallTemporary
debugPrepareStepBad:
        ld a,RUN_ERR_STEP
        scf
        ret

; Supply the architectural length, including the common indexed displacement
; forms. HL returns the sequential successor.
.routine out A,zero clobbers sign,parity,halfCarry,B,D,E,H,L
debugSequentialFallback:
        ld hl,(DBG_STATE_PC_LO)
        ld a,(hl)
        cp 0xCB
        jr z,debugSequentialLengthTwo
        cp 0xED
        jr z,debugSequentialEd
        cp 0xDD
        jr z,debugSequentialIndexed
        cp 0xFD
        jr z,debugSequentialIndexed
        call debugBaseLength
        ld b,a
        jr debugSequentialAddLength
debugSequentialLengthTwo:
        ld b,0x02
        jr debugSequentialAddLength
debugSequentialEd:
        inc hl
        ld a,(hl)
        and 0xC7
        cp 0x43
        ld b,0x02
        jr nz,debugSequentialAddLength
        ld b,0x04
        jr debugSequentialAddLength
debugSequentialIndexed:
        inc hl
        ld a,(hl)
        cp 0xCB
        ld b,0x04
        jr z,debugSequentialAddLength
        cp 0xED
        jr z,debugSequentialIndexedEd
        push af
        call debugBaseLength
        inc a
        ld b,a
        pop af
        cp 0x34
        jr z,debugSequentialIndexedDisplacement
        cp 0x35
        jr z,debugSequentialIndexedDisplacement
        cp 0x36
        jr z,debugSequentialIndexedDisplacement
        ld e,a
        and 0xC7
        cp 0x46
        jr z,debugSequentialIndexedDisplacement
        ld a,e
        and 0xF8
        cp 0x70
        jr z,debugSequentialIndexedDisplacement
        ld a,e
        and 0xC7
        cp 0x86
        jr nz,debugSequentialAddLength
debugSequentialIndexedDisplacement:
        inc b
        jr debugSequentialAddLength
debugSequentialIndexedEd:
        inc hl
        ld a,(hl)
        and 0xC7
        cp 0x43
        ld b,0x03
        jr nz,debugSequentialAddLength
        ld b,0x05
debugSequentialAddLength:
        ld hl,(DBG_STATE_PC_LO)
        ld e,b
        ld d,0x00
        add hl,de
        ret

.routine in A out A,zero clobbers sign,parity,halfCarry,D,E,H,L
debugBaseLength:
        ld e,a
        ld d,0x00
        ld hl,debugBaseLengthTable
        add hl,de
        ld a,(hl)
        ret

debugBaseLengthTable:
        .db 1,3,1,1,1,1,2,1,1,1,1,1,1,1,2,1
        .db 2,3,1,1,1,1,2,1,2,1,1,1,1,1,2,1
        .db 2,3,3,1,1,1,2,1,2,1,3,1,1,1,2,1
        .db 2,3,3,1,1,1,2,1,2,1,3,1,1,1,2,1
        .db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        .db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        .db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        .db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        .db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        .db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        .db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        .db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        .db 1,1,3,3,3,1,2,1,1,1,3,1,3,3,2,1
        .db 1,1,3,2,3,1,2,1,1,1,3,2,3,1,2,1
        .db 1,1,3,1,3,1,2,1,1,1,3,1,3,1,2,1
        .db 1,1,3,1,3,1,2,1,1,1,3,1,3,1,2,1

.routine out A,zero clobbers sign,parity,halfCarry,D,E,H,L
debugSelectRelativeTarget:
        ld hl,(DBG_STATE_PC_LO)
        inc hl
        ld e,(hl)
        ld d,0x00
        bit 7,e
        jr z,debugRelativeSignReady
        dec d
debugRelativeSignReady:
        ld hl,(DBG_STATE_TEMP_ADDR_LO)
        add hl,de
        ld (DBG_STATE_TEMP_ADDR_LO),hl
        ret

.routine out A,zero clobbers sign,parity,halfCarry,D,E,H,L
debugSelectReturnTarget:
        ld hl,(DBG_STATE_SP_LO)
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld (DBG_STATE_TEMP_ADDR_LO),hl
        ret

; A is a conditional JP/CALL/RET opcode or JR condition opcode.
.routine in A out A,zero clobbers sign,parity,halfCarry,B,C
debugConditionTaken:
        ld b,a
        cp 0x40
        jr nc,debugConditionEncoded
        rrca
        rrca
        rrca
        and 0x03
        jr debugConditionIndexReady
debugConditionEncoded:
        rrca
        rrca
        rrca
        and 0x07
debugConditionIndexReady:
        ld c,a
        ld a,(DBG_STATE_AF_LO)
        ld b,a
        ld a,c
        cp 0x00
        jr z,debugConditionNz
        cp 0x01
        jr z,debugConditionZ
        cp 0x02
        jr z,debugConditionNc
        cp 0x03
        jr z,debugConditionC
        cp 0x04
        jr z,debugConditionPo
        cp 0x05
        jr z,debugConditionPe
        cp 0x06
        jr z,debugConditionP
        ld a,b
        and 0x80
        jr debugConditionBoolean
debugConditionNz:
        ld a,b
        and 0x40
        jr z,debugConditionTrue
        xor a
        ret
debugConditionZ:
        ld a,b
        and 0x40
        jr debugConditionBoolean
debugConditionNc:
        ld a,b
        and 0x01
        jr z,debugConditionTrue
        xor a
        ret
debugConditionC:
        ld a,b
        and 0x01
        jr debugConditionBoolean
debugConditionPo:
        ld a,b
        and 0x04
        jr z,debugConditionTrue
        xor a
        ret
debugConditionPe:
        ld a,b
        and 0x04
        jr debugConditionBoolean
debugConditionP:
        ld a,b
        and 0x80
        jr z,debugConditionTrue
        xor a
        ret
debugConditionBoolean:
        ret z
debugConditionTrue:
        ld a,0x01
        ret

.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,D,E
debugValidateProgramAddress:
        push hl
        ld de,(RUN_PARAM_LOAD_LO)
        or a
        sbc hl,de
        pop hl
        ret c
        push hl
        ld de,(RUN_PARAM_END_LO)
        or a
        sbc hl,de
        pop hl
        ccf
        ret

; Trap entry reached through MON3 RST 38h. The RST return address is the only
; item added to the private program stack.
debugTrap:
        ld (DBG_STATE_HL_LO),hl
        ld (DBG_STATE_BC_LO),bc
        ld (DBG_STATE_DE_LO),de
        ld (DBG_STATE_IX_LO),ix
        ld (DBG_STATE_IY_LO),iy
        exx
        ld (DBG_STATE_BC_ALT_LO),bc
        ld (DBG_STATE_DE_ALT_LO),de
        ld (DBG_STATE_HL_ALT_LO),hl
        exx
        ex af,af'
        push af
        pop hl
        ld (DBG_STATE_AF_ALT_LO),hl
        ex af,af'
        push af
        pop hl
        ld (DBG_STATE_AF_LO),hl
        pop hl
        dec hl
        ld (DBG_STATE_PC_LO),hl
        ld (DBG_STATE_SP_LO),sp
        call debugClassifyTrap
        cp DBG_STOP_NONE
        jr z,debugTrapResume
        ld (DBG_STATE_STOP_REASON),a
        ld sp,(DBG_STATE_SERVICE_SP_LO)
        jp debugPublishStopped
debugTrapResume:
        jp debugRestoreAndResume

.routine out A,zero clobbers sign,parity,halfCarry,B,D,E,H,L
debugClassifyTrap:
        ld hl,(DBG_STATE_PC_LO)
        ld a,(DBG_STATE_TEMP_ARMED)
        or a
        jr z,debugClassifyBreakpoint
        ld de,(DBG_STATE_TEMP_ADDR_LO)
        or a
        sbc hl,de
        jr nz,debugClassifyBreakpoint
        call debugRestoreTemporary
        ld a,(DBG_STATE_MODE)
        cp DBG_MODE_REARM_RUN
        jr z,debugTrapRearmRun
        cp DBG_MODE_REARM_STEP
        jr z,debugTrapRearmStep
        ld a,DBG_STOP_STEP
        ret
debugTrapRearmRun:
        call debugTrapRearmBreakpoint
        ret nz
        ld a,DBG_MODE_RUN
        ld (DBG_STATE_MODE),a
        ld a,DBG_STOP_NONE
        ret
debugTrapRearmStep:
        call debugTrapRearmBreakpoint
        ret nz
        ld a,DBG_STOP_STEP
        ret
.routine out A,zero clobbers sign,parity,halfCarry,H,L,D,E
debugTrapRearmBreakpoint:
        ld hl,(DBG_STATE_PC_LO)
        ld de,(DBG_STATE_BP_ADDR_LO)
        or a
        sbc hl,de
        jr nz,debugTrapRearmWrite
        ld a,DBG_STOP_BREAKPOINT
        or a
        ret
debugTrapRearmWrite:
        call debugArmBreakpoint
        xor a
        ret
debugClassifyBreakpoint:
        ld hl,(DBG_STATE_PC_LO)
        ld a,(DBG_STATE_BP_ARMED)
        or a
        jr z,debugClassifyUnknown
        ld de,(DBG_STATE_BP_ADDR_LO)
        or a
        sbc hl,de
        jr nz,debugClassifyUnknown
        call debugRestoreBreakpoint
        ld a,DBG_STOP_BREAKPOINT
        ret
debugClassifyUnknown:
        ld a,DBG_STOP_STEP
        ret

.routine out A,zero clobbers sign,parity,halfCarry,H,L
debugArmBreakpoint:
        ld hl,(DBG_STATE_BP_ADDR_LO)
        ld a,(hl)
        ld (DBG_STATE_BP_ORIG),a
        ld (hl),DBG_TRAP_OPCODE
        ld a,0x01
        ld (DBG_STATE_BP_ARMED),a
        ret

.routine out A,zero clobbers sign,parity,halfCarry,H,L
debugRestoreBreakpoint:
        ld a,(DBG_STATE_BP_ARMED)
        or a
        ret z
        ld hl,(DBG_STATE_BP_ADDR_LO)
        ld a,(DBG_STATE_BP_ORIG)
        ld (hl),a
        xor a
        ld (DBG_STATE_BP_ARMED),a
        ret

.routine out A,zero clobbers sign,parity,halfCarry,H,L
debugRestoreTemporary:
        ld a,(DBG_STATE_TEMP_ARMED)
        or a
        ret z
        ld hl,(DBG_STATE_TEMP_ADDR_LO)
        ld a,(DBG_STATE_TEMP_ORIG)
        ld (hl),a
        xor a
        ld (DBG_STATE_TEMP_ARMED),a
        ret

.routine out A,zero clobbers sign,parity,halfCarry,H,L
debugRestoreAllPatches:
        call debugRestoreTemporary
        call debugRestoreBreakpoint
        ret

debugRestoreAndResume:
        ld sp,(DBG_STATE_SP_LO)
        ld hl,(DBG_STATE_PC_LO)
        push hl
        exx
        ld bc,(DBG_STATE_BC_ALT_LO)
        ld de,(DBG_STATE_DE_ALT_LO)
        ld hl,(DBG_STATE_HL_ALT_LO)
        exx
        ld hl,(DBG_STATE_AF_ALT_LO)
        push hl
        pop af
        ex af,af'
        ld bc,(DBG_STATE_BC_LO)
        ld de,(DBG_STATE_DE_LO)
        ld ix,(DBG_STATE_IX_LO)
        ld iy,(DBG_STATE_IY_LO)
        ld hl,(DBG_STATE_AF_LO)
        push hl
        pop af
        ld hl,(DBG_STATE_HL_LO)
        ret

debugProgramFinished:
        ld (DBG_STATE_HL_LO),hl
        ld (DBG_STATE_BC_LO),bc
        ld (DBG_STATE_DE_LO),de
        ld (DBG_STATE_IX_LO),ix
        ld (DBG_STATE_IY_LO),iy
        push af
        pop hl
        ld (DBG_STATE_AF_LO),hl
        call debugRestoreAllPatches
        ld hl,(DBG_STATE_USER_INT_LO)
        ld (MON_USER_INT),hl
        xor a
        ld (DBG_STATE_ACTIVE),a
        ld a,DBG_STOP_FINISHED
        ld (DBG_STATE_STOP_REASON),a
        ld sp,(DBG_STATE_SERVICE_SP_LO)
        jp debugPublishStopped

.routine out A,carry,zero clobbers sign,parity,halfCarry,H,L
debugPublishStopped:
        xor a
        ld (RUN_PARAM_STATUS),a
        ld (RUN_PARAM_LAST_ERROR),a
        ld a,SHL_RESULT_OK
        ld (RUN_PARAM_RESULT_LO),a
        ld a,(DBG_STATE_STOP_REASON)
        ld (RUN_PARAM_RESULT_HI),a
        ld a,0x88
        or a
        ret

debugNoSymbol:
        ld a,RUN_ERR_NO_SYMBOL
        jr debugPublishError
debugBadMap:
        ld a,RUN_ERR_BAD_MAP
        jr debugPublishError
debugNotStopped:
        ld a,RUN_ERR_NOT_STOPPED
        jr debugPublishError
debugStepError:
        ld a,RUN_ERR_STEP
        jr debugPublishError
debugStorageOrMapError:
        ld a,(TFS_PARAM_LAST_ERROR)
        or a
        jr nz,debugPublishStorageError
        ld a,RUN_ERR_BAD_MAP
        jr debugPublishError
debugPublishStorageError:
        ld a,RUN_ERR_STORAGE
debugPublishError:
        ld (RUN_PARAM_STATUS),a
        ld (RUN_PARAM_LAST_ERROR),a
        ld b,a
        ld a,SHL_RESULT_FILE_ERROR
        ld (RUN_PARAM_RESULT_LO),a
        ld a,b
        ld (RUN_PARAM_RESULT_HI),a
        scf
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L,IX,IY
debugLoadMap:
        call runValidateTarget
        ret c
        call runPrepareArtifactPath
        ret c
        or a
        call debugDeriveMapPath
        ret c
        or a
        ld hl,TFS_ARTIFACT_PATH_BUFFER
        ld (TFS_PARAM_PATH_LO),hl
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_FIND_PATH
        ret c
        ld a,(TFS_PARAM_ENTRY_FILE_TYPE)
        cp TFS_FILE_ASSET
        jr nz,debugLoadMapBad
        ld hl,(TFS_PARAM_ENTRY_SIZE_0)
        ld a,h
        cp 0x02
        jr nc,debugLoadMapBad
        ld a,h
        or a
        jr nz,debugLoadMapSizeReady
        ld a,l
        cp 0x08
        jr c,debugLoadMapBad
debugLoadMapSizeReady:
        ld (DBG_PARAM_MAP_SIZE_LO),hl
        ld a,(TFS_PARAM_ENTRY_FIRST_BLOCK_LO)
        ld (TFS_PARAM_BLOCK_INDEX_LO),a
        ld a,(TFS_PARAM_ENTRY_FIRST_BLOCK_HI)
        ld (TFS_PARAM_BLOCK_INDEX_HI),a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_MAP_BLOCK
        ret c
        ld hl,ASM_MAP_BASE
        ld (TFS_PARAM_BUFFER_LO),hl
        ld a,TFS_ARTIFACT_IO_MAP_DATA
        ld (TFS_PARAM_ARTIFACT_IO_KIND),a
        ld (TFS_PARAM_SOURCE_IO_KIND),a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_READ
        ret c
        call debugValidateMap
        ret
debugLoadMapBad:
        ld a,RUN_ERR_BAD_MAP
        ld (TFS_PARAM_LAST_ERROR),a
        scf
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,H,L
debugDeriveMapPath:
        ld hl,TFS_ARTIFACT_PATH_BUFFER
        ld b,TFS_ARTIFACT_PATH_CAPACITY
debugDeriveMapScan:
        ld a,(hl)
        or a
        jr z,debugDeriveMapEnd
        inc hl
        djnz debugDeriveMapScan
        scf
        ret
debugDeriveMapEnd:
        ld a,b
        cp TFS_ARTIFACT_PATH_CAPACITY-3
        jr nc,debugDeriveMapBad
        dec hl
        ld (hl),"p"
        dec hl
        ld (hl),"a"
        dec hl
        ld (hl),"m"
        or a
        ret
debugDeriveMapBad:
        scf
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,D,E,H,L
debugValidateMap:
        ld hl,ASM_MAP_BASE
        ld a,(hl)
        cp "T"
        jr nz,debugValidateMapBad
        inc hl
        ld a,(hl)
        cp "M"
        jr nz,debugValidateMapBad
        inc hl
        ld a,(hl)
        cp "A"
        jr nz,debugValidateMapBad
        inc hl
        ld a,(hl)
        cp "P"
        jr nz,debugValidateMapBad
        inc hl
        ld a,(hl)
        cp 0x01
        jr nz,debugValidateMapBad
        inc hl
        ld a,(hl)
        cp 0x0C
        jr nz,debugValidateMapBad
        inc hl
        ld a,(hl)
        cp ASM_SYMBOL_CAPACITY+1
        jr nc,debugValidateMapBad
        ld b,a
        ld hl,0x0008
        ld de,0x000C
debugValidateMapSizeLoop:
        ld a,b
        or a
        jr z,debugValidateMapSizeDone
        add hl,de
        djnz debugValidateMapSizeLoop
debugValidateMapSizeDone:
        ld de,(DBG_PARAM_MAP_SIZE_LO)
        or a
        sbc hl,de
        jr nz,debugValidateMapBad
        or a
        ret
debugValidateMapBad:
        ld a,RUN_ERR_BAD_MAP
        ld (TFS_PARAM_LAST_ERROR),a
        scf
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
debugFormatSourceMap:
        ld a,(ASM_MAP_BASE+6)
        ld (DBG_PARAM_OUTPUT_COUNT),a
        ld b,a
        ld hl,ASM_MAP_BASE+8
        ld de,EDT_BUFFER_BASE
debugFormatSourceMapNext:
        ld a,b
        or a
        jr z,debugFormatSourceMapDone
        push bc
        push hl
        push hl
        ld bc,0x0008
        add hl,bc
        ld c,(hl)
        inc hl
        ld a,(hl)
        call debugAppendHexByte
        ld a,c
        call debugAppendHexByte
        ld a," "
        ld (de),a
        inc de
        inc hl
        ld c,(hl)
        inc hl
        ld a,"F"
        ld (de),a
        inc de
        ld a,(hl)
        and 0xF0
        rrca
        rrca
        rrca
        rrca
        call debugAppendNibble
        ld a,":"
        ld (de),a
        inc de
        ld a,"L"
        ld (de),a
        inc de
        ld a,c
        call debugAppendHexByte
        ld a," "
        ld (de),a
        inc de
        pop hl
        ld c,0x08
debugFormatSourceMapName:
        ld a,(hl)
        or a
        jr z,debugFormatSourceMapNamePad
        ld (de),a
        inc de
debugFormatSourceMapNamePad:
        inc hl
        dec c
        jr nz,debugFormatSourceMapName
        ld a,0x0A
        ld (de),a
        inc de
        pop hl
        ld bc,0x000C
        add hl,bc
        pop bc
        djnz debugFormatSourceMapNext
debugFormatSourceMapDone:
        xor a
        ld (de),a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
debugFormatSymbols:
        ld a,(ASM_MAP_BASE+6)
        ld (DBG_PARAM_OUTPUT_COUNT),a
        ld b,a
        ld hl,ASM_MAP_BASE+8
        ld de,EDT_BUFFER_BASE
debugFormatSymbolNext:
        ld a,b
        or a
        jr z,debugFormatSymbolsDone
        push bc
        push hl
        ld c,0x08
debugFormatSymbolName:
        ld a,(hl)
        or a
        jr z,debugFormatSymbolNamePad
        ld (de),a
        inc de
debugFormatSymbolNamePad:
        inc hl
        dec c
        jr nz,debugFormatSymbolName
        ld a,"="
        ld (de),a
        inc de
        ld a,(hl)
        ld c,a
        inc hl
        ld a,(hl)
        call debugAppendHexByte
        ld a,c
        call debugAppendHexByte
        ld a," "
        ld (de),a
        inc de
        ld a,"F"
        ld (de),a
        inc de
        inc hl
        ld c,(hl)
        inc hl
        ld a,(hl)
        and 0xF0
        rrca
        rrca
        rrca
        rrca
        call debugAppendNibble
        ld a,":"
        ld (de),a
        inc de
        ld a,"L"
        ld (de),a
        inc de
        ld a,c
        call debugAppendHexByte
        ld a,0x0A
        ld (de),a
        inc de
        pop hl
        ld bc,0x000C
        add hl,bc
        pop bc
        djnz debugFormatSymbolNext
debugFormatSymbolsDone:
        xor a
        ld (de),a
        ret

.routine in A,DE out A,D,E,zero clobbers sign,parity,halfCarry,B
debugAppendHexByte:
        ld b,a
        rrca
        rrca
        rrca
        rrca
        and 0x0F
        call debugAppendNibble
        ld a,b
        and 0x0F
        jp debugAppendNibble

.routine in A,DE out A,D,E,zero clobbers sign,parity,halfCarry
debugAppendNibble:
        and 0x0F
        add a,"0"
        cp "9"+1
        jr c,debugAppendNibbleReady
        add a,"A"-"9"-1
debugAppendNibbleReady:
        ld (de),a
        inc de
        ret

.routine out A,carry,zero,H,L clobbers sign,parity,halfCarry,B,C,D,E
debugFindSymbol:
        ld hl,ASM_LINE_BUFFER
        ld de,ASM_LINE_BUFFER+1
        ld bc,0x0007
        xor a
        ld (hl),a
        ldir
        ld hl,(DBG_PARAM_SYMBOL_LO)
        ld a,h
        or l
        jr z,debugFindSymbolMissing
        ld de,ASM_LINE_BUFFER
        ld b,0x08
debugFindSymbolCopy:
        ld a,(hl)
        or a
        jr z,debugFindSymbolCopyDone
        cp "a"
        jr c,debugFindSymbolUpperReady
        cp "z"+1
        jr nc,debugFindSymbolUpperReady
        and 0xDF
debugFindSymbolUpperReady:
        ld (de),a
        inc hl
        inc de
        djnz debugFindSymbolCopy
        ld a,(hl)
        or a
        jr nz,debugFindSymbolMissing
debugFindSymbolCopyDone:
        ld a,(ASM_MAP_BASE+6)
        ld c,a
        ld hl,ASM_MAP_BASE+8
debugFindSymbolRecord:
        ld a,c
        or a
        jr z,debugFindSymbolMissing
        push hl
        ld de,ASM_LINE_BUFFER
        ld b,0x08
debugFindSymbolCompare:
        ld a,(de)
        cp (hl)
        jr nz,debugFindSymbolNoMatch
        inc de
        inc hl
        djnz debugFindSymbolCompare
        pop hl
        or a
        ret
debugFindSymbolNoMatch:
        pop hl
        ld de,0x000C
        add hl,de
        dec c
        jr debugFindSymbolRecord
debugFindSymbolMissing:
        ld a,RUN_ERR_NO_SYMBOL
        scf
        ret

.routine out A,zero clobbers sign,parity,halfCarry,H,L
runInitialize:
        ld a,EXP_BANK
        ld (RUN_PARAM_BANK),a
        ld a,EXP_VERSION
        ld (RUN_PARAM_VERSION),a
        xor a
        ld (RUN_PARAM_STATUS),a
        ld (RUN_PARAM_LAST_ERROR),a
        ld (RUN_PARAM_RESULT_LO),a
        ld (RUN_PARAM_RESULT_HI),a
        ld hl,RUN_STATE_BASE
        ld (hl),a
        ld de,RUN_STATE_BASE+1
        ld bc,0x0F
        ldir
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,H,L
runValidateTarget:
        ld hl,(RUN_PARAM_TARGET_LO)
        ld a,h
        or l
        scf
        ret z
        ld a,(hl)
        cp SHL_ACTION_RUN
        jr z,runValidateTargetActionReady
        cp SHL_ACTION_DEBUG
        scf
        ret nz
runValidateTargetActionReady:
        inc hl
        ld a,(hl)
        cp SHL_TARGET_KIND_PROJECT_OUTPUT
        scf
        ret nz
        or a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,D,E,H,L
runPrepareArtifactPath:
        ld hl,(RUN_PARAM_TARGET_LO)
        ld de,0x0002
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,d
        or e
        jr nz,runPrepareArtifactPathSourceReady
        ld de,runDefaultArtifactPath
runPrepareArtifactPathSourceReady:
        ex de,hl
        ld de,TFS_ARTIFACT_PATH_BUFFER
        ld b,TFS_ARTIFACT_PATH_CAPACITY-1
runPrepareArtifactPathCopy:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jr z,runPrepareArtifactPathDone
        djnz runPrepareArtifactPathCopy
        xor a
        ld (de),a
        scf
        ret
runPrepareArtifactPathDone:
        ld hl,TFS_ARTIFACT_PATH_BUFFER
        ld (TFS_PARAM_ARTIFACT_PATH_LO),hl
        ld a,(hl)
        cp "/"
        scf
        ret nz
        or a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,D,E,H,L
runValidateLoadedRange:
        ld hl,(RUN_PARAM_LOAD_LO)
        ld de,RUN_LOAD_MIN
        or a
        sbc hl,de
        ret c
        ld hl,(RUN_PARAM_END_LO)
        ld de,RUN_LOAD_MAX+1
        or a
        sbc hl,de
        ccf
        ret c
        ld hl,(RUN_PARAM_ENTRY_LO)
        ld de,(RUN_PARAM_LOAD_LO)
        or a
        sbc hl,de
        ret c
        ld hl,(RUN_PARAM_ENTRY_LO)
        ld de,(RUN_PARAM_END_LO)
        or a
        sbc hl,de
        ccf
        ret

runBadTarget:
        ld a,RUN_ERR_BAD_TARGET
        jr runPublishFileError
runStorageError:
        ld a,RUN_ERR_STORAGE
        jr runPublishFileError
runBadRange:
        ld a,RUN_ERR_BAD_RANGE
runPublishFileError:
        ld (RUN_PARAM_STATUS),a
        ld (RUN_PARAM_LAST_ERROR),a
        ld a,SHL_RESULT_FILE_ERROR
        ld (RUN_PARAM_RESULT_LO),a
        xor a
        ld (RUN_PARAM_RESULT_HI),a
        ld a,(RUN_PARAM_LAST_ERROR)
        scf
        ret

runDefaultArtifactPath:
        .db "/build/main.bin",0

Tecm8ExpansionBank8Info:
        .db     "T","M","8",EXP_BANK,EXP_VERSION
