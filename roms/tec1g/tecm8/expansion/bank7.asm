; TECM8 expansion ROM physical bank 7: phase-one self-hosted assembler.

        .include "bank_ops.asmi"

        .org    0x8000

EXP_BANK          .equ    0x07
EXP_VERSION       .equ    0x01

Tecm8ExpansionBank7Entry:
        cp ASM_SVC_ASSEMBLE
        jp z,asmAssemble
        ld a,ASM_ERR_UNKNOWN
        scf
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
asmAssemble:
        call asmInitialize
        call asmValidateTarget
        jp c,asmBadTarget
        call asmPrepareMainPath
        jp c,asmBadTarget
        ld a,(EDT_STATE_TOTAL_LINES)
        or a
        jp z,asmNoSource
        cp EDT_BUFFER_RECORDS+1
        jr c,asmSourceCountReady
        ld a,EDT_BUFFER_RECORDS
asmSourceCountReady:
        ld (ASM_STATE_SOURCE_LINES),a
        ld a,0x01
        ld (ASM_STATE_PASS),a
        call asmRunPass
        jp c,asmBuildFailed
        call asmFinishPassOne
        jp c,asmBuildFailed
        ld a,0x02
        ld (ASM_STATE_PASS),a
        xor a
        ld (ASM_STATE_LINE),a
        ld hl,(ASM_STATE_ORIGIN_LO)
        ld (ASM_STATE_PC_LO),hl
        call asmRunPass
        jp c,asmBuildFailed
        call asmBuildMap
        call asmSaveArtifacts
        jp c,asmStorageFailed
        xor a
        ld (ASM_PARAM_STATUS),a
        ld (ASM_PARAM_LAST_ERROR),a
        ld (ASM_STATE_DIAG_CODE),a
        ld a,SHL_RESULT_OK
        ld (ASM_PARAM_RESULT_LO),a
        xor a
        ld (ASM_PARAM_RESULT_HI),a
        ld a,0x87
        or a
        ret

.routine out A,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
asmInitialize:
        ld a,EXP_BANK
        ld (ASM_PARAM_BANK),a
        ld a,EXP_VERSION
        ld (ASM_PARAM_VERSION),a
        xor a
        ld (ASM_PARAM_STATUS),a
        ld (ASM_PARAM_LAST_ERROR),a
        ld (ASM_PARAM_RESULT_LO),a
        ld (ASM_PARAM_RESULT_HI),a
        ld hl,ASM_STATE_BASE
        ld de,ASM_STATE_BASE+1
        ld bc,0x1F
        ld (hl),a
        ldir
        ld hl,ASM_CONTEXT_BASE
        ld de,ASM_CONTEXT_BASE+1
        ld bc,0x0B
        ld (hl),a
        ldir
        ld hl,ASM_OUTPUT_BASE
        ld de,ASM_OUTPUT_BASE+1
        ld bc,ASM_OUTPUT_BYTES-1
        ld (hl),a
        ldir
        ld hl,ASM_MAP_BASE
        ld de,ASM_MAP_BASE+1
        ld bc,ASM_MAP_BYTES-1
        ld (hl),a
        ldir
        ld hl,ASM_SYMBOL_BASE
        ld de,ASM_SYMBOL_BASE+1
        ld bc,(ASM_SYMBOL_BYTES*ASM_SYMBOL_CAPACITY)-1
        ld (hl),a
        ldir
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,H,L
asmValidateTarget:
        ld hl,(ASM_PARAM_TARGET_LO)
        ld a,h
        or l
        scf
        ret z
        ld a,(hl)
        cp SHL_ACTION_ASM
        scf
        ret nz
        inc hl
        ld a,(hl)
        cp SHL_TARGET_KIND_PROJECT_MAIN
        scf
        ret nz
        or a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,D,E,H,L
asmPrepareMainPath:
        ld hl,(ASM_PARAM_TARGET_LO)
        ld de,0x0002
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,d
        or e
        jr nz,asmPrepareMainPathSourceReady
        ld de,asmDefaultMainPath
asmPrepareMainPathSourceReady:
        ex de,hl
        ld de,ASM_MAIN_PATH_BUFFER
        ld b,ASM_MAIN_PATH_CAPACITY-1
asmPrepareMainPathCopy:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jr z,asmPrepareMainPathValidate
        djnz asmPrepareMainPathCopy
        xor a
        ld (de),a
        scf
        ret
asmPrepareMainPathValidate:
        ld a,(ASM_MAIN_PATH_BUFFER)
        cp "/"
        scf
        ret nz
        or a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
asmRunPass:
        xor a
        ld (ASM_STATE_LINE),a
        ld (ASM_CONTEXT_INCLUDE_COUNT),a
        ld (ASM_CONTEXT_INCLUDE_DEPTH),a
        ld (ASM_CONTEXT_CURRENT_FILE),a
asmRunPassNext:
        ld a,(ASM_STATE_LINE)
        ld b,a
        ld a,(ASM_STATE_SOURCE_LINES)
        cp b
        jr z,asmRunPassDone
        call asmCopySourceLine
        call asmParseLine
        ret c
        ld a,(ASM_STATE_LINE)
        inc a
        ld (ASM_STATE_LINE),a
        jr asmRunPassNext
asmRunPassDone:
        or a
        ret

.routine out A,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
asmCopySourceLine:
        ld hl,EDT_BUFFER_BASE
        jr asmCopyLineFromBase
.routine out A,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
asmCopyIncludeLine:
        ld hl,ASM_INCLUDE_BASE
asmCopyLineFromBase:
        ld a,(ASM_STATE_LINE)
        or a
        jr z,asmCopySourceAddressReady
        ld b,a
        ld de,EDT_RECORD_BYTES
asmCopySourceAddressNext:
        add hl,de
        djnz asmCopySourceAddressNext
asmCopySourceAddressReady:
        ld a,(hl)
        and EDT_RECORD_LENGTH_MASK
        cp ASM_LINE_CAPACITY
        jr c,asmCopySourceLengthReady
        ld a,ASM_LINE_CAPACITY-1
asmCopySourceLengthReady:
        ld b,a
        ld c,0x00
        inc hl
        ld de,ASM_LINE_BUFFER
        ld a,b
        or a
        jr z,asmCopySourceTerminate
asmCopySourceNext:
        ld a,(hl)
        cp 0x22
        jr z,asmCopySourceQuote
        ld a,c
        or a
        ld a,(hl)
        jr nz,asmCopySourceStore
        cp "a"
        jr c,asmCopySourceStore
        cp "z"+1
        jr nc,asmCopySourceStore
        and 0xDF
        jr asmCopySourceStore
asmCopySourceQuote:
        ld a,c
        xor 0x01
        ld c,a
        ld a,0x22
asmCopySourceStore:
        ld (de),a
        inc hl
        inc de
        djnz asmCopySourceNext
asmCopySourceTerminate:
        xor a
        ld (de),a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
asmParseLine:
        ld hl,ASM_LINE_BUFFER
        call asmSkipSpaces
        ld a,(hl)
        or a
        ret z
        cp ";"
        ret z
        ld de,asmKwInclude
        call asmTryKeyword
        jp c,asmDirectiveInclude
        call asmTryEquDefinition
        ret c
        or a
        ret nz
        call asmConsumeLabel
        ret c
        call asmSkipSpaces
        ld a,(hl)
        or a
        ret z
        cp ";"
        ret z
        ld de,asmKwOrg
        call asmTryKeyword
        jp c,asmDirectiveOrg
        ld de,asmKwDb
        call asmTryKeyword
        jp c,asmDirectiveDb
        ld de,asmKwDw
        call asmTryKeyword
        jp c,asmDirectiveDw
        ld de,asmKwNop
        call asmTryKeyword
        jp c,asmInstructionNop
        ld de,asmKwRet
        call asmTryKeyword
        jp c,asmInstructionRet
        ld de,asmKwHalt
        call asmTryKeyword
        jp c,asmInstructionHalt
        ld de,asmKwDi
        call asmTryKeyword
        jp c,asmInstructionDi
        ld de,asmKwEi
        call asmTryKeyword
        jp c,asmInstructionEi
        ld de,asmKwScf
        call asmTryKeyword
        jp c,asmInstructionScf
        ld de,asmKwCcf
        call asmTryKeyword
        jp c,asmInstructionCcf
        ld de,asmKwCpl
        call asmTryKeyword
        jp c,asmInstructionCpl
        ld de,asmKwXor
        call asmTryKeyword
        jp c,asmInstructionXor
        ld de,asmKwAnd
        call asmTryKeyword
        jp c,asmInstructionAnd
        ld de,asmKwOr
        call asmTryKeyword
        jp c,asmInstructionOr
        ld de,asmKwSub
        call asmTryKeyword
        jp c,asmInstructionSub
        ld de,asmKwLd
        call asmTryKeyword
        jp c,asmInstructionLd
        ld de,asmKwJp
        call asmTryKeyword
        jp c,asmInstructionJp
        ld de,asmKwCall
        call asmTryKeyword
        jp c,asmInstructionCall
        ld de,asmKwJr
        call asmTryKeyword
        jp c,asmInstructionJr
        ld de,asmKwDjnz
        call asmTryKeyword
        jp c,asmInstructionDjnz
        ld de,asmKwCp
        call asmTryKeyword
        jp c,asmInstructionCp
        ld de,asmKwAdd
        call asmTryKeyword
        jp c,asmInstructionAdd
        ld de,asmKwAdc
        call asmTryKeyword
        jp c,asmInstructionAdc
        ld de,asmKwSbc
        call asmTryKeyword
        jp c,asmInstructionSbc
        ld de,asmKwInc
        call asmTryKeyword
        jp c,asmInstructionInc
        ld de,asmKwDec
        call asmTryKeyword
        jp c,asmInstructionDec
        ld de,asmKwOut
        call asmTryKeyword
        jp c,asmInstructionOut
        ld de,asmKwIn
        call asmTryKeyword
        jp c,asmInstructionIn
        ld de,asmKwPush
        call asmTryKeyword
        jp c,asmInstructionPush
        ld de,asmKwPop
        call asmTryKeyword
        jp c,asmInstructionPop
        jp asmSyntaxError

; Accept NAME .EQU expression and NAME: .EQU expression before ordinary
; label consumption. Constants must resolve during pass one; this keeps the
; bounded symbol table deterministic without a third fix-up pass.
.routine in H,L out A,carry,zero,H,L clobbers sign,parity,halfCarry,B,C,D,E
asmTryEquDefinition:
        ld (ASM_STATE_EQU_START_LO),hl
        ld (ASM_STATE_TOKEN_LO),hl
        ld b,0x00
asmTryEquName:
        ld a,(hl)
        cp ":"
        jr z,asmTryEquAfterColon
        cp " "
        jr z,asmTryEquAfterName
        cp 0x09
        jr z,asmTryEquAfterName
        or a
        jr z,asmTryEquNoMatch
        cp ";"
        jr z,asmTryEquNoMatch
        inc b
        ld a,b
        cp 0x09
        jr nc,asmTryEquNoMatch
        inc hl
        jr asmTryEquName
asmTryEquAfterColon:
        ld a,b
        or a
        jr z,asmTryEquNoMatch
        inc hl
        call asmSkipSpaces
        jr asmTryEquKeyword
asmTryEquAfterName:
        ld a,b
        or a
        jr z,asmTryEquNoMatch
        call asmSkipSpaces
asmTryEquKeyword:
        ld a,b
        ld (ASM_STATE_FLAGS),a
        ld de,asmKwEqu
        call asmTryKeyword
        jr nc,asmTryEquNoMatch
        xor a
        ld (ASM_STATE_UNRESOLVED),a
        call asmParseExpression
        jp c,asmExpressionError
        call asmExpectEnd
        jp c,asmSyntaxError
        ld a,(ASM_STATE_PASS)
        cp 0x01
        jr nz,asmTryEquMatched
        ld a,(ASM_STATE_UNRESOLVED)
        or a
        jp nz,asmExpressionError
        ld (ASM_STATE_VALUE_LO),de
        call asmAddEquSymbol
        ret c
asmTryEquMatched:
        ld a,0x01
        or a
        ret
asmTryEquNoMatch:
        ld hl,(ASM_STATE_EQU_START_LO)
        xor a
        ret

; Consume NAME: at the start of a line. Names are 1..8 uppercase bytes.
.routine in H,L out A,carry,zero,H,L clobbers sign,parity,halfCarry,B,C,D,E
asmConsumeLabel:
        ld (ASM_STATE_TOKEN_LO),hl
        ld b,0x00
asmConsumeLabelScan:
        ld a,(hl)
        cp ":"
        jr z,asmConsumeLabelFound
        or a
        jr z,asmConsumeLabelNone
        cp " "
        jr z,asmConsumeLabelNone
        cp 0x09
        jr z,asmConsumeLabelNone
        cp ";"
        jr z,asmConsumeLabelNone
        inc b
        inc hl
        jr asmConsumeLabelScan
asmConsumeLabelNone:
        ld hl,(ASM_STATE_TOKEN_LO)
        or a
        ret
asmConsumeLabelFound:
        ld a,b
        or a
        jr z,asmConsumeLabelBad
        cp 0x09
        jr nc,asmConsumeLabelBad
        ld (ASM_STATE_FLAGS),a
        ld a,(ASM_STATE_PASS)
        cp 0x01
        jr nz,asmConsumeLabelSkipAdd
        call asmAddSymbol
        jr c,asmConsumeLabelBad
asmConsumeLabelSkipAdd:
        ld hl,(ASM_STATE_TOKEN_LO)
        ld a,(ASM_STATE_FLAGS)
        ld b,a
asmConsumeLabelAdvance:
        inc hl
        djnz asmConsumeLabelAdvance
        inc hl
        or a
        ret
asmConsumeLabelBad:
        jp asmSyntaxError

.routine in H,L,D,E out A,carry,zero,H,L clobbers sign,parity,halfCarry,B,C
asmTryKeyword:
        ld (ASM_STATE_MATCH_LO),hl
asmTryKeywordNext:
        ld a,(de)
        or a
        jr z,asmTryKeywordBoundary
        cp (hl)
        jr nz,asmTryKeywordFail
        inc de
        inc hl
        jr asmTryKeywordNext
asmTryKeywordBoundary:
        ld a,(hl)
        or a
        jr z,asmTryKeywordMatched
        cp " "
        jr z,asmTryKeywordMatched
        cp 0x09
        jr z,asmTryKeywordMatched
        cp ","
        jr z,asmTryKeywordMatched
        cp ";"
        jr nz,asmTryKeywordFail
asmTryKeywordMatched:
        call asmSkipSpaces
        scf
        ret
asmTryKeywordFail:
        ld hl,(ASM_STATE_MATCH_LO)
        or a
        ret

.routine in H,L out A,zero,H,L clobbers sign,parity,halfCarry
asmSkipSpaces:
        ld a,(hl)
        cp " "
        jr z,asmSkipSpacesNext
        cp 0x09
        ret nz
asmSkipSpacesNext:
        inc hl
        jr asmSkipSpaces

asmDirectiveInclude:
        ld a,(ASM_CONTEXT_INCLUDE_DEPTH)
        or a
        jp nz,asmIncludeError
        ld a,(ASM_CONTEXT_INCLUDE_COUNT)
        cp ASM_INCLUDE_MAX
        jp nc,asmIncludeError
        call asmParseIncludePath
        jp c,asmIncludeError
        ld a,(ASM_STATE_LINE)
        ld (ASM_CONTEXT_RETURN_LINE),a
        ld a,(ASM_CONTEXT_CURRENT_FILE)
        ld (ASM_CONTEXT_RETURN_FILE),a
        call asmLoadInclude
        jp c,asmIncludeError
        ld a,(ASM_CONTEXT_INCLUDE_COUNT)
        inc a
        ld (ASM_CONTEXT_INCLUDE_COUNT),a
        ld (ASM_CONTEXT_CURRENT_FILE),a
        ld a,0x01
        ld (ASM_CONTEXT_INCLUDE_DEPTH),a
        xor a
        ld (ASM_STATE_LINE),a
asmDirectiveIncludeNext:
        ld a,(ASM_STATE_LINE)
        ld b,a
        ld a,(ASM_CONTEXT_INCLUDE_LINES)
        cp b
        jr z,asmDirectiveIncludeDone
        call asmCopyIncludeLine
        call asmParseLine
        jr c,asmDirectiveIncludeRestoreError
        ld a,(ASM_STATE_LINE)
        inc a
        ld (ASM_STATE_LINE),a
        jr asmDirectiveIncludeNext
asmDirectiveIncludeDone:
        call asmRestoreMainContext
        or a
        ret
asmDirectiveIncludeRestoreError:
        call asmRestoreMainContext
        scf
        ret

.routine out A,zero clobbers sign,parity,halfCarry
asmRestoreMainContext:
        ld a,(ASM_CONTEXT_RETURN_LINE)
        ld (ASM_STATE_LINE),a
        ld a,(ASM_CONTEXT_RETURN_FILE)
        ld (ASM_CONTEXT_CURRENT_FILE),a
        xor a
        ld (ASM_CONTEXT_INCLUDE_DEPTH),a
        ret

.routine in H,L out A,carry,zero,H,L clobbers sign,parity,halfCarry,B,C,D,E
asmParseIncludePath:
        call asmSkipSpaces
        ld a,(hl)
        cp 0x22
        scf
        ret nz
        inc hl
        ld a,(hl)
        cp "/"
        jr z,asmParseIncludeAbsolute
        push hl
        call asmCopyMainDirectory
        pop hl
        jr asmParseIncludeCopy
asmParseIncludeAbsolute:
        ld de,ASM_INCLUDE_PATH_BUFFER
asmParseIncludeCopy:
        ld c,0x00
asmParseIncludeCopyNext:
        ld a,(hl)
        or a
        jr z,asmParseIncludeBad
        cp 0x22
        jr z,asmParseIncludeEnd
        ld b,a
        ld a,e
        sub ASM_INCLUDE_PATH_BUFFER & 0xFF
        cp ASM_INCLUDE_PATH_CAPACITY-1
        jr nc,asmParseIncludeBad
        ld a,b
        ld (de),a
        inc de
        inc hl
        inc c
        jr asmParseIncludeCopyNext
asmParseIncludeEnd:
        ld a,c
        or a
        jr z,asmParseIncludeBad
        xor a
        ld (de),a
        inc hl
        call asmExpectEnd
        ret
asmParseIncludeBad:
        scf
        ret

.routine out A,D,E clobbers zero,sign,parity,halfCarry,B,C,H,L
asmCopyMainDirectory:
        ld hl,ASM_MAIN_PATH_BUFFER+1
        ld b,0x01
asmCopyMainDirectoryScan:
        ld a,(hl)
        or a
        jr z,asmCopyMainDirectoryReady
        inc b
        cp "/"
        jr z,asmCopyMainDirectoryReady
        inc hl
        jr asmCopyMainDirectoryScan
asmCopyMainDirectoryReady:
        ld a,(hl)
        or a
        jr nz,asmCopyMainDirectoryLengthReady
        ld b,0x01
asmCopyMainDirectoryLengthReady:
        ld hl,ASM_MAIN_PATH_BUFFER
        ld de,ASM_INCLUDE_PATH_BUFFER
        ld c,b
        ld b,0x00
        ldir
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
asmLoadInclude:
        ld hl,ASM_INCLUDE_PATH_BUFFER
        ld (TFS_PARAM_PATH_LO),hl
        .rcignore definite_contract_violation "The include path is published in shared RAM; no caller DE or flag value is live across the bank call."
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_FIND_PATH
        ret c
        ld a,(TFS_PARAM_ENTRY_FILE_ID)
        ld (ASM_CONTEXT_INCLUDE_FILE_ID),a
        ld hl,ASM_INCLUDE_BASE
        ld (TFS_PARAM_LOAD_DEST_LO),hl
        ld hl,ASM_INCLUDE_BYTES
        ld (TFS_PARAM_LOAD_BYTES_LO),hl
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_LOAD_SOURCE
        ret c
        ld a,(TFS_PARAM_LOAD_LINES_HI)
        or a
        scf
        ret nz
        ld a,(TFS_PARAM_LOAD_LINES_LO)
        cp EDT_BUFFER_RECORDS+1
        ccf
        ret c
        ld (ASM_CONTEXT_INCLUDE_LINES),a
        ld a,(ASM_CONTEXT_INCLUDE_COUNT)
        ld e,a
        ld d,0x00
        ld hl,ASM_CONTEXT_FILE_ID_TABLE
        add hl,de
        ld a,(ASM_CONTEXT_INCLUDE_FILE_ID)
        ld (hl),a
        or a
        ret

asmDirectiveOrg:
        call asmParseExpression
        jp c,asmExpressionError
        call asmExpectEnd
        jp c,asmSyntaxError
        ld a,d
        cp RUN_LOAD_MIN >> 8
        jp c,asmOriginError
        cp RUN_LOAD_MAX >> 8
        jp nc,asmOriginError
        ld (ASM_STATE_PC_LO),de
        ld a,(ASM_STATE_ORIGIN_HI)
        or a
        jr nz,asmDirectiveOrgDone
        ld (ASM_STATE_ORIGIN_LO),de
        ld (ASM_STATE_RUN_LO),de
asmDirectiveOrgDone:
        or a
        ret

asmDirectiveDb:
asmDirectiveDbNext:
        call asmParseExpression
        jp c,asmExpressionError
        ld a,d
        or a
        jp nz,asmExpressionError
        ld a,e
        push hl
        call asmEmitByte
        jr c,asmDirectiveDbEmitBad
        pop hl
        call asmSkipSpaces
        ld a,(hl)
        cp ","
        jr nz,asmDirectiveDbEnd
        inc hl
        call asmSkipSpaces
        jr asmDirectiveDbNext
asmDirectiveDbEmitBad:
        pop hl
        ret
asmDirectiveDbEnd:
        call asmExpectEnd
        jp c,asmSyntaxError
        or a
        ret

asmDirectiveDw:
asmDirectiveDwNext:
        call asmParseExpression
        jp c,asmExpressionError
        push hl
        call asmEmitWordDe
        jr c,asmDirectiveDwEmitBad
        pop hl
        call asmSkipSpaces
        ld a,(hl)
        cp ","
        jr nz,asmDirectiveDwEnd
        inc hl
        call asmSkipSpaces
        jr asmDirectiveDwNext
asmDirectiveDwEmitBad:
        pop hl
        ret
asmDirectiveDwEnd:
        call asmExpectEnd
        jp c,asmSyntaxError
        or a
        ret

asmInstructionNop:
        call asmExpectEnd
        jp c,asmSyntaxError
        ld a,0x00
        jp asmEmitByte

asmInstructionRet:
        call asmSkipSpaces
        ld a,(hl)
        or a
        jr z,asmInstructionRetPlain
        cp ";"
        jr z,asmInstructionRetPlain
        call asmParseCondition
        jp c,asmSyntaxError
        ld (ASM_STATE_OPERAND),a
        call asmExpectEnd
        jp c,asmSyntaxError
        ld a,(ASM_STATE_OPERAND)
        add a,a
        add a,a
        add a,a
        add a,0xC0
        jp asmEmitByte
asmInstructionRetPlain:
        ld a,0xC9
        jp asmEmitByte

asmInstructionHalt:
        call asmExpectEnd
        jp c,asmSyntaxError
        ld a,0x76
        jp asmEmitByte

asmInstructionDi:
        ld a,0xF3
        jr asmInstructionSingleByte
asmInstructionEi:
        ld a,0xFB
        jr asmInstructionSingleByte
asmInstructionScf:
        ld a,0x37
        jr asmInstructionSingleByte
asmInstructionCcf:
        ld a,0x3F
        jr asmInstructionSingleByte
asmInstructionCpl:
        ld a,0x2F
asmInstructionSingleByte:
        push af
        call asmExpectEnd
        jr c,asmInstructionSingleByteBad
        pop af
        jp asmEmitByte
asmInstructionSingleByteBad:
        pop af
        jp asmSyntaxError

asmInstructionXor:
        ld a,0xA8
        ld e,0xEE
        jp asmInstructionAlu
asmInstructionAnd:
        ld a,0xA0
        ld e,0xE6
        jp asmInstructionAlu
asmInstructionOr:
        ld a,0xB0
        ld e,0xF6
        jp asmInstructionAlu
asmInstructionSub:
        ld a,0x90
        ld e,0xD6
        jp asmInstructionAlu

asmInstructionLd:
        call asmParseRegister8
        jr c,asmLdNonRegister
        ld (ASM_STATE_OPERAND),a
        call asmExpectComma
        jp c,asmSyntaxError
        call asmParseRegister8
        jr nc,asmLdRegisterToRegister
        ld a,(ASM_STATE_OPERAND)
        cp 0x07
        jr nz,asmLdRegisterImmediate
        ld a,(hl)
        cp "("
        jr z,asmLdAFromMemory
asmLdRegisterImmediate:
        call asmParseExpression
        jp c,asmExpressionError
        ld a,d
        or a
        jp nz,asmExpressionError
        call asmExpectEnd
        jp c,asmSyntaxError
        push de
        ld a,(ASM_STATE_OPERAND)
        add a,a
        add a,a
        add a,a
        add a,0x06
        call asmEmitByte
        jr c,asmLdRegisterImmediateBad
        pop de
        ld a,e
        jp asmEmitByte
asmLdRegisterImmediateBad:
        pop de
        ret
asmLdRegisterToRegister:
        ld e,a
        call asmExpectEnd
        jp c,asmSyntaxError
        ld a,(ASM_STATE_OPERAND)
        add a,a
        add a,a
        add a,a
        add a,e
        add a,0x40
        cp 0x76
        jp z,asmSyntaxError
        jp asmEmitByte
asmLdNonRegister:
        ld a,(hl)
        cp "("
        jp z,asmLdMemoryA
        ld de,asmKwHl
        call asmTryKeyword
        jp c,asmLdHl
        ld de,asmKwDe
        call asmTryKeyword
        jp c,asmLdDe
        ld de,asmKwBc
        call asmTryKeyword
        jp c,asmLdBc
        ld de,asmKwSp
        call asmTryKeyword
        jp c,asmLdSp
        jp asmSyntaxError
asmLdAFromMemory:
        call asmParseParenExpression
        jp c,asmExpressionError
        call asmExpectEnd
        jp c,asmSyntaxError
        push de
        ld a,0x3A
        call asmEmitByte
        jr c,asmLdAFromMemoryBad
        pop de
        jp asmEmitWordDe
asmLdAFromMemoryBad:
        pop de
        ret
asmLdMemoryA:
        call asmParseParenExpression
        jp c,asmExpressionError
        push de
        call asmExpectComma
        jr c,asmLdMemoryABad
        ld a,(hl)
        cp "A"
        jr nz,asmLdMemoryABad
        inc hl
        call asmExpectEnd
        jr c,asmLdMemoryABad
        ld a,0x32
        call asmEmitByte
        jr c,asmLdMemoryAEmitBad
        pop de
        jp asmEmitWordDe
asmLdMemoryABad:
        pop de
asmLdMemoryAEmitBad:
        jp asmSyntaxError
asmLdHl:
        ld a,0x21
        jr asmLdWord
asmLdDe:
        ld a,0x11
        jr asmLdWord
asmLdBc:
        ld a,0x01
        jr asmLdWord
asmLdSp:
        ld a,0x31
asmLdWord:
        call asmExpectComma
        jp c,asmSyntaxError
        push af
        call asmParseExpression
        jr c,asmLdWordBad
        call asmExpectEnd
        jr c,asmLdWordBad
        pop af
        push de
        call asmEmitByte
        jr c,asmLdWordEmitBad
        pop de
        jp asmEmitWordDe
asmLdWordEmitBad:
        pop de
        ret
asmLdWordBad:
        pop af
        jp asmExpressionError

asmInstructionJp:
        call asmParseCondition
        jr c,asmInstructionJpPlain
        ld (ASM_STATE_OPERAND),a
        call asmExpectComma
        jp c,asmSyntaxError
        ld a,(ASM_STATE_OPERAND)
        add a,a
        add a,a
        add a,a
        add a,0xC2
        jr asmInstructionWordTarget
asmInstructionJpPlain:
        ld a,0xC3
        jr asmInstructionWordTarget
asmInstructionCall:
        call asmParseCondition
        jr c,asmInstructionCallPlain
        ld (ASM_STATE_OPERAND),a
        call asmExpectComma
        jp c,asmSyntaxError
        ld a,(ASM_STATE_OPERAND)
        add a,a
        add a,a
        add a,a
        add a,0xC4
        jr asmInstructionWordTarget
asmInstructionCallPlain:
        ld a,0xCD
asmInstructionWordTarget:
        push af
        call asmParseExpression
        jr c,asmInstructionWordBad
        call asmExpectEnd
        jr c,asmInstructionWordBad
        pop af
        push de
        call asmEmitByte
        jr c,asmInstructionWordEmitBad
        pop de
        jp asmEmitWordDe
asmInstructionWordEmitBad:
        pop de
        ret
asmInstructionWordBad:
        pop af
        jp asmExpressionError

asmInstructionJr:
        call asmParseCondition
        jr c,asmInstructionJrPlain
        cp 0x04
        jp nc,asmSyntaxError
        ld (ASM_STATE_OPERAND),a
        call asmExpectComma
        jp c,asmSyntaxError
        ld a,(ASM_STATE_OPERAND)
        add a,a
        add a,a
        add a,a
        add a,0x20
        jr asmInstructionRelativeTarget
asmInstructionJrPlain:
        ld a,0x18
        jr asmInstructionRelativeTarget
asmInstructionDjnz:
        ld a,0x10
asmInstructionRelativeTarget:
        ld (ASM_STATE_OPCODE),a
        call asmParseExpression
        jp c,asmExpressionError
        call asmExpectEnd
        jp c,asmSyntaxError
        push de
        ld a,(ASM_STATE_OPCODE)
        call asmEmitByte
        jr c,asmInstructionJrBad
        ld a,(ASM_STATE_PASS)
        cp 0x01
        jr z,asmInstructionJrPassOne
        pop de
        ld hl,(ASM_STATE_PC_LO)
        inc hl
        or a
        ex de,hl
        sbc hl,de
        ld a,h
        or a
        jr z,asmInstructionJrPositive
        cp 0xFF
        jp nz,asmExpressionError
        ld a,l
        cp 0x80
        jp c,asmExpressionError
        jr asmInstructionJrEmit
asmInstructionJrPositive:
        ld a,l
        cp 0x80
        jp nc,asmExpressionError
asmInstructionJrEmit:
        jp asmEmitByte
asmInstructionJrPassOne:
        pop de
        xor a
        jp asmEmitByte
asmInstructionJrBad:
        pop de
        ret

asmInstructionCp:
        ld a,0xB8
        ld e,0xFE
        jr asmInstructionAlu
asmInstructionAdd:
        call asmExpectAccumulatorComma
        jp c,asmSyntaxError
        ld a,0x80
        ld e,0xC6
        jr asmInstructionAlu
asmInstructionAdc:
        call asmExpectAccumulatorComma
        jp c,asmSyntaxError
        ld a,0x88
        ld e,0xCE
        jr asmInstructionAlu
asmInstructionSbc:
        call asmExpectAccumulatorComma
        jp c,asmSyntaxError
        ld a,0x98
        ld e,0xDE
asmInstructionAlu:
        ld (ASM_STATE_OPERAND),a
        ld a,e
        ld (ASM_STATE_OPCODE),a
        call asmParseRegister8
        jr c,asmInstructionAluImmediate
        ld e,a
        call asmExpectEnd
        jp c,asmSyntaxError
        ld a,(ASM_STATE_OPERAND)
        add a,e
        jp asmEmitByte
asmInstructionAluImmediate:
        call asmParseExpression
        jp c,asmExpressionError
        ld a,d
        or a
        jp nz,asmExpressionError
        call asmExpectEnd
        jp c,asmSyntaxError
        push de
        ld a,(ASM_STATE_OPCODE)
        call asmEmitByte
        jr c,asmInstructionAluImmediateBad
        pop de
        ld a,e
        jp asmEmitByte
asmInstructionAluImmediateBad:
        pop de
        ret

.routine in H,L out A,carry,zero,H,L clobbers sign,parity,halfCarry
asmExpectAccumulatorComma:
        ld a,(hl)
        cp "A"
        scf
        ret nz
        inc hl
        jp asmExpectComma

asmInstructionInc:
        ld a,0x04
        jr asmInstructionIncDec

asmInstructionDec:
        ld a,0x05
asmInstructionIncDec:
        ld (ASM_STATE_OPCODE),a
        call asmParseRegister8
        jp c,asmSyntaxError
        ld e,a
        call asmExpectEnd
        jp c,asmSyntaxError
        ld a,e
        add a,a
        add a,a
        add a,a
        ld e,a
        ld a,(ASM_STATE_OPCODE)
        add a,e
        jp asmEmitByte

asmInstructionOut:
        call asmParseParenExpression
        jp c,asmExpressionError
        ld a,d
        or a
        jp nz,asmExpressionError
        push de
        call asmExpectComma
        jr c,asmInstructionOutBad
        ld a,(hl)
        cp "A"
        jr nz,asmInstructionOutBad
        inc hl
        call asmExpectEnd
        jr c,asmInstructionOutBad
        ld a,0xD3
        call asmEmitByte
        jr c,asmInstructionOutEmitBad
        pop de
        ld a,e
        jp asmEmitByte
asmInstructionOutBad:
        pop de
asmInstructionOutEmitBad:
        jp asmSyntaxError

asmInstructionIn:
        ld a,(hl)
        cp "A"
        jp nz,asmSyntaxError
        inc hl
        call asmExpectComma
        jp c,asmSyntaxError
        call asmParseParenExpression
        jp c,asmExpressionError
        ld a,d
        or a
        jp nz,asmExpressionError
        call asmExpectEnd
        jp c,asmSyntaxError
        push de
        ld a,0xDB
        call asmEmitByte
        jr c,asmInstructionInBad
        pop de
        ld a,e
        jp asmEmitByte
asmInstructionInBad:
        pop de
        ret

asmInstructionPush:
        ld a,0xC5
        jr asmInstructionStack
asmInstructionPop:
        ld a,0xC1
asmInstructionStack:
        ld (ASM_STATE_OPCODE),a
        call asmParseStackPair
        jp c,asmSyntaxError
        ld e,a
        call asmExpectEnd
        jp c,asmSyntaxError
        ld a,e
        add a,a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld a,(ASM_STATE_OPCODE)
        add a,e
        jp asmEmitByte

.routine in H,L out A,carry,zero,H,L clobbers sign,parity,halfCarry
asmParseCondition:
        ld (ASM_STATE_MATCH_LO),hl
        ld a,(hl)
        cp "N"
        jr z,asmParseConditionN
        cp "Z"
        jr z,asmParseConditionZ
        cp "C"
        jr z,asmParseConditionC
        cp "P"
        jr z,asmParseConditionP
        cp "M"
        jr z,asmParseConditionM
        jr asmParseConditionBad
asmParseConditionN:
        inc hl
        ld a,(hl)
        cp "Z"
        jr z,asmParseConditionNz
        cp "C"
        jr z,asmParseConditionNc
        jr asmParseConditionBad
asmParseConditionNz:
        inc hl
        call asmRegisterTokenBoundary
        jr c,asmParseConditionBad
        xor a
        ret
asmParseConditionNc:
        inc hl
        call asmRegisterTokenBoundary
        jr c,asmParseConditionBad
        ld a,0x02
        or a
        ret
asmParseConditionZ:
        inc hl
        call asmRegisterTokenBoundary
        jr c,asmParseConditionBad
        ld a,0x01
        or a
        ret
asmParseConditionC:
        inc hl
        call asmRegisterTokenBoundary
        jr c,asmParseConditionBad
        ld a,0x03
        or a
        ret
asmParseConditionP:
        inc hl
        ld a,(hl)
        cp "O"
        jr z,asmParseConditionPo
        cp "E"
        jr z,asmParseConditionPe
        call asmRegisterTokenBoundary
        jr c,asmParseConditionBad
        ld a,0x06
        or a
        ret
asmParseConditionPo:
        inc hl
        call asmRegisterTokenBoundary
        jr c,asmParseConditionBad
        ld a,0x04
        or a
        ret
asmParseConditionPe:
        inc hl
        call asmRegisterTokenBoundary
        jr c,asmParseConditionBad
        ld a,0x05
        or a
        ret
asmParseConditionM:
        inc hl
        call asmRegisterTokenBoundary
        jr c,asmParseConditionBad
        ld a,0x07
        or a
        ret
asmParseConditionBad:
        ld hl,(ASM_STATE_MATCH_LO)
        scf
        ret

.routine in H,L out A,carry,zero,H,L clobbers sign,parity,halfCarry
asmParseStackPair:
        ld (ASM_STATE_MATCH_LO),hl
        ld a,(hl)
        cp "B"
        jr z,asmParseStackPairBc
        cp "D"
        jr z,asmParseStackPairDe
        cp "H"
        jr z,asmParseStackPairHl
        cp "A"
        jr z,asmParseStackPairAf
        jr asmParseStackPairBad
asmParseStackPairBc:
        inc hl
        ld a,(hl)
        cp "C"
        jr nz,asmParseStackPairBad
        inc hl
        call asmRegisterTokenBoundary
        jr c,asmParseStackPairBad
        xor a
        ret
asmParseStackPairDe:
        inc hl
        ld a,(hl)
        cp "E"
        jr nz,asmParseStackPairBad
        inc hl
        call asmRegisterTokenBoundary
        jr c,asmParseStackPairBad
        ld a,0x01
        or a
        ret
asmParseStackPairHl:
        inc hl
        ld a,(hl)
        cp "L"
        jr nz,asmParseStackPairBad
        inc hl
        call asmRegisterTokenBoundary
        jr c,asmParseStackPairBad
        ld a,0x02
        or a
        ret
asmParseStackPairAf:
        inc hl
        ld a,(hl)
        cp "F"
        jr nz,asmParseStackPairBad
        inc hl
        call asmRegisterTokenBoundary
        jr c,asmParseStackPairBad
        ld a,0x03
        or a
        ret
asmParseStackPairBad:
        ld hl,(ASM_STATE_MATCH_LO)
        scf
        ret

.routine in H,L out A,carry,zero,H,L clobbers sign,parity,halfCarry
asmParseRegister8:
        ld (ASM_STATE_MATCH_LO),hl
        ld a,(hl)
        cp "("
        jr z,asmParseRegister8Indirect
        inc hl
        call asmRegisterTokenBoundary
        jr c,asmParseRegister8Bad
        dec hl
        ld a,(hl)
        inc hl
        cp "B"
        jr z,asmParseRegister8B
        cp "C"
        jr z,asmParseRegister8C
        cp "D"
        jr z,asmParseRegister8D
        cp "E"
        jr z,asmParseRegister8E
        cp "H"
        jr z,asmParseRegister8H
        cp "L"
        jr z,asmParseRegister8L
        cp "A"
        jr z,asmParseRegister8A
        jr asmParseRegister8Bad
asmParseRegister8Indirect:
        inc hl
        ld a,(hl)
        cp "H"
        jr nz,asmParseRegister8Bad
        inc hl
        ld a,(hl)
        cp "L"
        jr nz,asmParseRegister8Bad
        inc hl
        ld a,(hl)
        cp ")"
        jr nz,asmParseRegister8Bad
        inc hl
        call asmRegisterTokenBoundary
        jr c,asmParseRegister8Bad
        ld a,0x06
        or a
        ret
asmParseRegister8B:
        xor a
        ret
asmParseRegister8C:
        ld a,0x01
        or a
        ret
asmParseRegister8D:
        ld a,0x02
        or a
        ret
asmParseRegister8E:
        ld a,0x03
        or a
        ret
asmParseRegister8H:
        ld a,0x04
        or a
        ret
asmParseRegister8L:
        ld a,0x05
        or a
        ret
asmParseRegister8A:
        ld a,0x07
        or a
        ret
asmParseRegister8Bad:
        ld hl,(ASM_STATE_MATCH_LO)
        scf
        ret

.routine in H,L out A,carry,zero,H,L clobbers sign,parity,halfCarry
asmRegisterTokenBoundary:
        ld a,(hl)
        or a
        ret z
        cp " "
        jr z,asmRegisterTokenBoundaryGood
        cp 0x09
        jr z,asmRegisterTokenBoundaryGood
        cp ","
        jr z,asmRegisterTokenBoundaryGood
        cp ";"
        jr z,asmRegisterTokenBoundaryGood
        cp ")"
        jr z,asmRegisterTokenBoundaryGood
        scf
        ret
asmRegisterTokenBoundaryGood:
        or a
        ret

.routine in H,L out A,carry,zero,D,E,H,L clobbers sign,parity,halfCarry,B,C
asmParseParenExpression:
        ld a,(hl)
        cp "("
        scf
        ret nz
        inc hl
        call asmSkipSpaces
        call asmParseExpression
        ret c
        call asmSkipSpaces
        ld a,(hl)
        cp ")"
        scf
        ret nz
        inc hl
        or a
        ret

.routine in H,L out A,carry,zero,D,E,H,L clobbers sign,parity,halfCarry,B,C
asmParseExpression:
        call asmSkipSpaces
        call asmParseUnary
        ret c
        ld (ASM_STATE_VALUE_LO),de
asmParseExpressionNext:
        call asmSkipSpaces
        ld a,(hl)
        cp "+"
        jr z,asmParseExpressionOperator
        cp "-"
        jr z,asmParseExpressionOperator
        ld de,(ASM_STATE_VALUE_LO)
        or a
        ret
asmParseExpressionOperator:
        inc hl
        push af
        call asmParseUnary
        jr c,asmParseExpressionBad
        ld (ASM_STATE_RHS_LO),de
        ld (ASM_STATE_MATCH_LO),hl
        ld hl,(ASM_STATE_VALUE_LO)
        ld de,(ASM_STATE_RHS_LO)
        pop af
        cp "+"
        jr nz,asmParseExpressionSubtract
        add hl,de
        jr asmParseExpressionStore
asmParseExpressionSubtract:
        or a
        sbc hl,de
asmParseExpressionStore:
        ld (ASM_STATE_VALUE_LO),hl
        ld hl,(ASM_STATE_MATCH_LO)
        jr asmParseExpressionNext
asmParseExpressionBad:
        pop af
        scf
        ret

.routine in H,L out A,carry,zero,D,E,H,L clobbers sign,parity,halfCarry,B,C
asmParseUnary:
        call asmSkipSpaces
        ld a,(hl)
        cp "+"
        jr z,asmParseUnaryPositive
        cp "-"
        jr z,asmParseUnaryNegative
        jp asmParseAtom
asmParseUnaryPositive:
        inc hl
        jp asmParseUnary
asmParseUnaryNegative:
        inc hl
        call asmParseUnary
        ret c
        push hl
        ld hl,0x0000
        or a
        sbc hl,de
        ex de,hl
        pop hl
        or a
        ret

.routine in H,L out A,carry,zero,D,E,H,L clobbers sign,parity,halfCarry,B,C
asmParseAtom:
        call asmSkipSpaces
        ld a,(hl)
        cp "("
        jr z,asmParseGrouped
        cp "$"
        jr z,asmParseCurrentPc
        cp "0"
        jp c,asmParseSymbol
        cp "9"+1
        jp nc,asmParseSymbol
        cp "0"
        jr nz,asmParseDecimal
        inc hl
        ld a,(hl)
        cp "X"
        jr z,asmParseHexAfterPrefix
        dec hl
asmParseDecimal:
        ld de,0x0000
        ld b,0x00
asmParseDecimalNext:
        ld a,(hl)
        cp "0"
        jr c,asmParseDecimalDone
        cp "9"+1
        jr nc,asmParseDecimalDone
        sub "0"
        ld c,a
        push hl
        ld h,d
        ld l,e
        add hl,hl
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        ex de,hl
        pop hl
        ld a,e
        add a,c
        ld e,a
        ld a,d
        adc a,0x00
        ld d,a
        inc hl
        inc b
        jr asmParseDecimalNext
asmParseDecimalDone:
        ld a,b
        or a
        scf
        ret z
        or a
        ret
asmParseGrouped:
        inc hl
        call asmParseExpression
        ret c
        call asmSkipSpaces
        ld a,(hl)
        cp ")"
        scf
        ret nz
        inc hl
        or a
        ret
asmParseCurrentPc:
        inc hl
        ld de,(ASM_STATE_PC_LO)
        or a
        ret
asmParseHexAfterPrefix:
        inc hl
        ld de,0x0000
        ld b,0x00
asmParseHexNext:
        ld a,(hl)
        call asmHexNibble
        jr c,asmParseHexDone
        ld c,a
        sla e
        rl d
        sla e
        rl d
        sla e
        rl d
        sla e
        rl d
        ld a,e
        add a,c
        ld e,a
        ld a,d
        adc a,0x00
        ld d,a
        inc hl
        inc b
        ld a,b
        cp 0x05
        jr c,asmParseHexNext
        scf
        ret
asmParseHexDone:
        ld a,b
        or a
        scf
        ret z
        or a
        ret
asmParseSymbol:
        ld (ASM_STATE_TOKEN_LO),hl
        ld b,0x00
asmParseSymbolScan:
        ld a,(hl)
        or a
        jr z,asmParseSymbolReady
        cp " "
        jr z,asmParseSymbolReady
        cp 0x09
        jr z,asmParseSymbolReady
        cp ","
        jr z,asmParseSymbolReady
        cp ")"
        jr z,asmParseSymbolReady
        cp "+"
        jr z,asmParseSymbolReady
        cp "-"
        jr z,asmParseSymbolReady
        cp ";"
        jr z,asmParseSymbolReady
        inc hl
        inc b
        ld a,b
        cp 0x09
        jr c,asmParseSymbolScan
        scf
        ret
asmParseSymbolReady:
        ld a,b
        or a
        scf
        ret z
        ld (ASM_STATE_FLAGS),a
        ld (ASM_STATE_RHS_LO),hl
        call asmFindSymbol
        jr c,asmParseSymbolFound
        ld hl,(ASM_STATE_RHS_LO)
        ld a,(ASM_STATE_PASS)
        cp 0x01
        scf
        ret nz
        ld a,0x01
        ld (ASM_STATE_UNRESOLVED),a
        ld de,0x0000
        or a
        ret
asmParseSymbolFound:
        ld de,0x0008
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(ASM_STATE_TOKEN_LO)
        ld a,(ASM_STATE_FLAGS)
        ld b,a
asmParseSymbolAdvance:
        inc hl
        djnz asmParseSymbolAdvance
        or a
        ret

.routine in A out A,carry,zero clobbers sign,parity,halfCarry
asmHexNibble:
        cp "0"
        jr c,asmHexNibbleBad
        cp "9"+1
        jr c,asmHexNibbleDigit
        cp "A"
        jr c,asmHexNibbleBad
        cp "F"+1
        jr nc,asmHexNibbleBad
        sub "A"-10
        or a
        ret
asmHexNibbleDigit:
        sub "0"
        or a
        ret
asmHexNibbleBad:
        scf
        ret

.routine out A,carry,zero,H,L clobbers sign,parity,halfCarry,B,C,D,E
asmFindSymbol:
        ld a,(ASM_STATE_SYMBOL_COUNT)
        or a
        jr z,asmFindSymbolMissing
        ld c,a
        ld de,ASM_SYMBOL_BASE
asmFindSymbolNext:
        push de
        ld hl,(ASM_STATE_TOKEN_LO)
        ld a,(ASM_STATE_FLAGS)
        ld b,a
asmFindSymbolCompare:
        ld a,(de)
        cp (hl)
        jr nz,asmFindSymbolNotThis
        inc de
        inc hl
        djnz asmFindSymbolCompare
        ld a,(de)
        or a
        jr nz,asmFindSymbolNotThis
        pop hl
        scf
        ret
asmFindSymbolNotThis:
        pop de
        ld hl,ASM_SYMBOL_BYTES
        add hl,de
        ex de,hl
        dec c
        jr nz,asmFindSymbolNext
asmFindSymbolMissing:
        or a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
asmAddSymbol:
        ld de,(ASM_STATE_PC_LO)
        ld (ASM_STATE_VALUE_LO),de
        ld a,0x01
        ld (ASM_STATE_SYMBOL_KIND),a
        jr asmAddSymbolValue

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
asmAddEquSymbol:
        ld a,0x02
        ld (ASM_STATE_SYMBOL_KIND),a

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
asmAddSymbolValue:
        call asmFindSymbol
        jp c,asmDuplicateSymbol
        ld a,(ASM_STATE_SYMBOL_COUNT)
        cp ASM_SYMBOL_CAPACITY
        jp nc,asmSymbolFull
        ld c,a
        ld hl,ASM_SYMBOL_BASE
        ld de,ASM_SYMBOL_BYTES
        or a
        jr z,asmAddSymbolAddressReady
        ld b,a
asmAddSymbolAddressNext:
        add hl,de
        djnz asmAddSymbolAddressNext
asmAddSymbolAddressReady:
        push hl
        ex de,hl
        ld hl,(ASM_STATE_TOKEN_LO)
        ld a,(ASM_STATE_FLAGS)
        ld b,a
asmAddSymbolCopy:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        djnz asmAddSymbolCopy
        xor a
        ld (de),a
        pop hl
        ld de,0x0008
        add hl,de
        ld de,(ASM_STATE_VALUE_LO)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,(ASM_STATE_LINE)
        ld (hl),a
        inc hl
        ld a,(ASM_CONTEXT_CURRENT_FILE)
        add a,a
        add a,a
        add a,a
        add a,a
        ld b,a
        ld a,(ASM_STATE_SYMBOL_KIND)
        or b
        ld (hl),a
        ld a,c
        inc a
        ld (ASM_STATE_SYMBOL_COUNT),a
        or a
        ret

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
asmEmitByte:
        ld c,a
        ld hl,(ASM_STATE_ORIGIN_LO)
        ld a,h
        or l
        jp z,asmOriginError
        ld hl,(ASM_STATE_PC_LO)
        ld de,(ASM_STATE_ORIGIN_LO)
        or a
        sbc hl,de
        ld a,h
        cp ASM_OUTPUT_BYTES >> 8
        jp nc,asmOutputFull
        ld a,(ASM_STATE_PASS)
        cp 0x02
        jr nz,asmEmitByteAdvance
        ld de,ASM_OUTPUT_BASE
        add hl,de
        ld (hl),c
asmEmitByteAdvance:
        ld hl,(ASM_STATE_PC_LO)
        inc hl
        ld (ASM_STATE_PC_LO),hl
        or a
        ret

.routine in D,E out A,carry,zero clobbers sign,parity,halfCarry,B,C,H,L
asmEmitWordDe:
        push de
        ld a,e
        call asmEmitByte
        jr c,asmEmitWordBad
        pop de
        ld a,d
        jp asmEmitByte
asmEmitWordBad:
        pop de
        ret

.routine in H,L out A,carry,zero,H,L clobbers sign,parity,halfCarry
asmExpectComma:
        call asmSkipSpaces
        ld a,(hl)
        cp ","
        scf
        ret nz
        inc hl
        call asmSkipSpaces
        or a
        ret

.routine in H,L out A,carry,zero,H,L clobbers sign,parity,halfCarry
asmExpectEnd:
        call asmSkipSpaces
        ld a,(hl)
        or a
        ret z
        cp ";"
        ret z
        scf
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,D,E,H,L
asmFinishPassOne:
        ld hl,(ASM_STATE_ORIGIN_LO)
        ld a,h
        or l
        jp z,asmOriginError
        ld hl,(ASM_STATE_PC_LO)
        ld de,(ASM_STATE_ORIGIN_LO)
        or a
        sbc hl,de
        ld a,h
        or l
        jp z,asmOutputFull
        ld (ASM_STATE_SIZE_LO),hl
        or a
        ret

.routine out A,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
asmBuildMap:
        ld hl,ASM_MAP_BASE
        ld (hl),"T"
        inc hl
        ld (hl),"M"
        inc hl
        ld (hl),"A"
        inc hl
        ld (hl),"P"
        inc hl
        ld (hl),0x01
        inc hl
        ld (hl),ASM_SYMBOL_BYTES
        inc hl
        ld a,(ASM_STATE_SYMBOL_COUNT)
        ld (hl),a
        inc hl
        ld (hl),0x00
        inc hl
        ld de,ASM_SYMBOL_BASE
        ex de,hl
        ld a,(ASM_STATE_SYMBOL_COUNT)
        ld c,a
        add a,a
        add a,c
        add a,a
        add a,a
        ld c,a
        ld b,0x00
        push bc
        ldir
        pop hl
        ld de,0x0008
        add hl,de
        ld (ASM_STATE_MAP_SIZE_LO),hl
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
asmSaveArtifacts:
        ld hl,asmArtifactExtBin
        .rcignore definite_contract_violation "The extension pointer is consumed by path construction; no pre-call DE or flag value remains live."
        call asmBuildArtifactPath
        ret c
        ld a,TFS_ARTIFACT_KIND_BINARY
        ld (TFS_PARAM_ARTIFACT_KIND),a
        ld hl,ASM_OUTPUT_BASE
        ld (TFS_PARAM_ARTIFACT_BUFFER_LO),hl
        ld hl,(ASM_STATE_SIZE_LO)
        ld (TFS_PARAM_ARTIFACT_SIZE_LO),hl
        ld hl,(ASM_STATE_ORIGIN_LO)
        ld (TFS_PARAM_ARTIFACT_LOAD_LO),hl
        ld hl,(ASM_STATE_RUN_LO)
        ld (TFS_PARAM_ARTIFACT_RUN_LO),hl
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_SAVE_ARTIFACT
        ret c
        ld hl,asmArtifactExtMap
        .rcignore definite_contract_violation "The extension pointer is consumed by path construction; no pre-call DE value remains live."
        call asmBuildArtifactPath
        ret c
        ld a,TFS_ARTIFACT_KIND_MAP
        ld (TFS_PARAM_ARTIFACT_KIND),a
        ld hl,ASM_MAP_BASE
        ld (TFS_PARAM_ARTIFACT_BUFFER_LO),hl
        ld hl,(ASM_STATE_MAP_SIZE_LO)
        ld (TFS_PARAM_ARTIFACT_SIZE_LO),hl
        xor a
        ld (TFS_PARAM_ARTIFACT_LOAD_LO),a
        ld (TFS_PARAM_ARTIFACT_LOAD_HI),a
        ld (TFS_PARAM_ARTIFACT_RUN_LO),a
        ld (TFS_PARAM_ARTIFACT_RUN_HI),a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_SAVE_ARTIFACT
        ret

.routine in H,L out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
asmBuildArtifactPath:
        ld (ASM_STATE_RHS_LO),hl
        ld hl,ASM_MAIN_PATH_BUFFER
        ld (ASM_STATE_MATCH_LO),hl
asmBuildArtifactFindName:
        ld a,(hl)
        or a
        jr z,asmBuildArtifactNameReady
        cp "/"
        jr nz,asmBuildArtifactFindNext
        inc hl
        ld (ASM_STATE_MATCH_LO),hl
        dec hl
asmBuildArtifactFindNext:
        inc hl
        jr asmBuildArtifactFindName
asmBuildArtifactNameReady:
        ld hl,asmArtifactBuildPrefix
        ld de,TFS_ARTIFACT_PATH_BUFFER
        ld bc,0x0007
        ldir
        ld hl,(ASM_STATE_MATCH_LO)
        ld b,TFS_ARTIFACT_PATH_CAPACITY-7-5
        ld c,0x00
asmBuildArtifactCopyStem:
        ld a,(hl)
        or a
        jr z,asmBuildArtifactStemDone
        cp "."
        jr z,asmBuildArtifactStemDone
        ld (de),a
        inc de
        inc hl
        inc c
        djnz asmBuildArtifactCopyStem
        scf
        ret
asmBuildArtifactStemDone:
        ld a,c
        or a
        scf
        ret z
        ld hl,(ASM_STATE_RHS_LO)
        ld bc,0x0005
        ldir
        ld hl,TFS_ARTIFACT_PATH_BUFFER
        ld (TFS_PARAM_ARTIFACT_PATH_LO),hl
        or a
        ret

asmBadTarget:
        ld a,ASM_ERR_BAD_TARGET
        jr asmPublishFileError
asmNoSource:
        ld a,ASM_ERR_NO_SOURCE
        jr asmPublishFileError
asmStorageFailed:
        ld a,ASM_ERR_STORAGE
asmPublishFileError:
        ld (ASM_PARAM_STATUS),a
        ld (ASM_PARAM_LAST_ERROR),a
        ld (ASM_STATE_DIAG_CODE),a
        ld a,SHL_RESULT_FILE_ERROR
        ld (ASM_PARAM_RESULT_LO),a
        xor a
        ld (ASM_PARAM_RESULT_HI),a
        ld a,(ASM_PARAM_LAST_ERROR)
        scf
        ret

asmBuildFailed:
        ld a,(ASM_STATE_DIAG_CODE)
        or a
        jr nz,asmBuildFailedCodeReady
        ld a,ASM_ERR_SYNTAX
asmBuildFailedCodeReady:
        ld (ASM_PARAM_STATUS),a
        ld (ASM_PARAM_LAST_ERROR),a
        ld a,SHL_RESULT_BUILD_ERROR
        ld (ASM_PARAM_RESULT_LO),a
        ld a,(ASM_STATE_DIAG_LINE)
        ld (ASM_PARAM_RESULT_HI),a
        ld a,(ASM_PARAM_LAST_ERROR)
        scf
        ret

asmSyntaxError:
        ld a,ASM_ERR_SYNTAX
        jr asmRecordDiagnostic
asmExpressionError:
        ld a,ASM_ERR_EXPRESSION
        jr asmRecordDiagnostic
asmSymbolFull:
        ld a,ASM_ERR_SYMBOL_FULL
        jr asmRecordDiagnostic
asmDuplicateSymbol:
        ld a,ASM_ERR_DUP_SYMBOL
        jr asmRecordDiagnostic
asmOutputFull:
        ld a,ASM_ERR_OUTPUT_FULL
        jr asmRecordDiagnostic
asmOriginError:
        ld a,ASM_ERR_BAD_ORIGIN
        jr asmRecordDiagnostic
asmIncludeError:
        ld a,ASM_ERR_INCLUDE
asmRecordDiagnostic:
        ld (ASM_STATE_DIAG_CODE),a
        ld a,(ASM_STATE_LINE)
        ld (ASM_STATE_DIAG_LINE),a
        ld a,(ASM_CONTEXT_CURRENT_FILE)
        ld (ASM_CONTEXT_DIAG_FILE),a
        ld a,0x02
        ld (ASM_STATE_DIAG_COLUMN),a
        scf
        ret

asmKwOrg:      .db ".ORG",0
asmKwEqu:      .db ".EQU",0
asmKwInclude:  .db ".INCLUDE",0
asmKwDb:       .db ".DB",0
asmKwDw:       .db ".DW",0
asmKwNop:      .db "NOP",0
asmKwRet:      .db "RET",0
asmKwHalt:     .db "HALT",0
asmKwDi:       .db "DI",0
asmKwEi:       .db "EI",0
asmKwScf:      .db "SCF",0
asmKwCcf:      .db "CCF",0
asmKwCpl:      .db "CPL",0
asmKwXor:      .db "XOR",0
asmKwAnd:      .db "AND",0
asmKwOr:       .db "OR",0
asmKwSub:      .db "SUB",0
asmKwLd:       .db "LD",0
asmKwJp:       .db "JP",0
asmKwCall:     .db "CALL",0
asmKwJr:       .db "JR",0
asmKwDjnz:     .db "DJNZ",0
asmKwCp:       .db "CP",0
asmKwAdd:      .db "ADD",0
asmKwAdc:      .db "ADC",0
asmKwSbc:      .db "SBC",0
asmKwInc:      .db "INC",0
asmKwDec:      .db "DEC",0
asmKwOut:      .db "OUT",0
asmKwIn:       .db "IN",0
asmKwPush:     .db "PUSH",0
asmKwPop:      .db "POP",0
asmKwHl:       .db "HL",0
asmKwDe:       .db "DE",0
asmKwBc:       .db "BC",0
asmKwSp:       .db "SP",0
asmDefaultMainPath:
        .db "/src/main.asm",0
asmArtifactBuildPrefix:
        .db "/build/"
asmArtifactExtBin:
        .db ".bin",0
asmArtifactExtMap:
        .db ".map",0

Tecm8ExpansionBank7Info:
        .db     "T","M","8",EXP_BANK,EXP_VERSION
