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

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
asmRunPass:
        xor a
        ld (ASM_STATE_LINE),a
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
        inc hl
        ld de,ASM_LINE_BUFFER
        ld a,b
        or a
        jr z,asmCopySourceTerminate
asmCopySourceNext:
        ld a,(hl)
        cp "a"
        jr c,asmCopySourceStore
        cp "z"+1
        jr nc,asmCopySourceStore
        and 0xDF
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
        ld de,asmKwXor
        call asmTryKeyword
        jp c,asmInstructionXor
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
        ld de,asmKwCp
        call asmTryKeyword
        jp c,asmInstructionCp
        ld de,asmKwAdd
        call asmTryKeyword
        jp c,asmInstructionAdd
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
        jp asmSyntaxError

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
        call asmExpectEnd
        jp c,asmSyntaxError
        ld a,0xC9
        jp asmEmitByte

asmInstructionHalt:
        call asmExpectEnd
        jp c,asmSyntaxError
        ld a,0x76
        jp asmEmitByte

asmInstructionXor:
        ld a,(hl)
        cp "A"
        jp nz,asmSyntaxError
        inc hl
        call asmExpectEnd
        jp c,asmSyntaxError
        ld a,0xAF
        jp asmEmitByte

asmInstructionLd:
        ld a,(hl)
        cp "A"
        jp z,asmLdA
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
asmLdA:
        inc hl
        call asmExpectComma
        jp c,asmSyntaxError
        ld a,(hl)
        cp "("
        jr z,asmLdAFromMemory
        call asmParseExpression
        jp c,asmExpressionError
        ld a,d
        or a
        jp nz,asmExpressionError
        call asmExpectEnd
        jp c,asmSyntaxError
        push de
        ld a,0x3E
        call asmEmitByte
        jr c,asmLdAImmediateBad
        pop de
        ld a,e
        jp asmEmitByte
asmLdAImmediateBad:
        pop de
        ret
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
        ld a,0xC3
        jr asmInstructionWordTarget
asmInstructionCall:
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
        call asmParseExpression
        jp c,asmExpressionError
        call asmExpectEnd
        jp c,asmSyntaxError
        push de
        ld a,0x18
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
        ld a,0xFE
        jr asmInstructionByteImmediate
asmInstructionAdd:
        ld a,(hl)
        cp "A"
        jp nz,asmSyntaxError
        inc hl
        call asmExpectComma
        jp c,asmSyntaxError
        ld a,0xC6
asmInstructionByteImmediate:
        push af
        call asmParseExpression
        jr c,asmInstructionByteBad
        ld a,d
        or a
        jr nz,asmInstructionByteBad
        call asmExpectEnd
        jr c,asmInstructionByteBad
        pop af
        push de
        call asmEmitByte
        jr c,asmInstructionByteEmitBad
        pop de
        ld a,e
        jp asmEmitByte
asmInstructionByteEmitBad:
        pop de
        ret
asmInstructionByteBad:
        pop af
        jp asmExpressionError

asmInstructionInc:
        call asmRegisterOpcodeInc
        jp c,asmSyntaxError
        jp asmEmitByte

asmInstructionDec:
        call asmRegisterOpcodeDec
        jp c,asmSyntaxError
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

.routine in H,L out A,carry,zero,H,L clobbers sign,parity,halfCarry,B
asmRegisterOpcodeInc:
        ld a,(hl)
        ld b,a
        inc hl
        call asmExpectEnd
        scf
        ret c
        ld a,b
        cp "A"
        jr z,asmRegisterIncA
        cp "B"
        jr z,asmRegisterIncB
        cp "C"
        jr z,asmRegisterIncC
        cp "D"
        jr z,asmRegisterIncD
        cp "E"
        jr z,asmRegisterIncE
        cp "H"
        jr z,asmRegisterIncH
        cp "L"
        jr z,asmRegisterIncL
        scf
        ret
asmRegisterIncA:
        ld a,0x3C
        or a
        ret
asmRegisterIncB:
        ld a,0x04
        or a
        ret
asmRegisterIncC:
        ld a,0x0C
        or a
        ret
asmRegisterIncD:
        ld a,0x14
        or a
        ret
asmRegisterIncE:
        ld a,0x1C
        or a
        ret
asmRegisterIncH:
        ld a,0x24
        or a
        ret
asmRegisterIncL:
        ld a,0x2C
        or a
        ret

.routine in H,L out A,carry,zero,H,L clobbers sign,parity,halfCarry,B
asmRegisterOpcodeDec:
        ld a,(hl)
        ld b,a
        inc hl
        call asmExpectEnd
        scf
        ret c
        ld a,b
        cp "A"
        jr z,asmRegisterDecA
        cp "B"
        jr z,asmRegisterDecB
        cp "C"
        jr z,asmRegisterDecC
        cp "D"
        jr z,asmRegisterDecD
        cp "E"
        jr z,asmRegisterDecE
        cp "H"
        jr z,asmRegisterDecH
        cp "L"
        jr z,asmRegisterDecL
        scf
        ret
asmRegisterDecA:
        ld a,0x3D
        or a
        ret
asmRegisterDecB:
        ld a,0x05
        or a
        ret
asmRegisterDecC:
        ld a,0x0D
        or a
        ret
asmRegisterDecD:
        ld a,0x15
        or a
        ret
asmRegisterDecE:
        ld a,0x1D
        or a
        ret
asmRegisterDecH:
        ld a,0x25
        or a
        ret
asmRegisterDecL:
        ld a,0x2D
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
        ld a,(hl)
        cp "0"
        jr c,asmParseSymbol
        cp "9"+1
        jr nc,asmParseSymbol
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
        call asmFindSymbol
        jr c,asmParseSymbolFound
        ld a,(ASM_STATE_PASS)
        cp 0x01
        scf
        ret nz
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
        ld de,(ASM_STATE_PC_LO)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld a,(ASM_STATE_LINE)
        ld (hl),a
        inc hl
        ld a,0x01
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
        .rcignore definite_contract_violation "Artifact parameters are fully published in shared RAM; no caller DE value is live across the bank call."
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_SAVE_ARTIFACT
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
asmRecordDiagnostic:
        ld (ASM_STATE_DIAG_CODE),a
        ld a,(ASM_STATE_LINE)
        ld (ASM_STATE_DIAG_LINE),a
        ld a,0x02
        ld (ASM_STATE_DIAG_COLUMN),a
        scf
        ret

asmKwOrg:      .db ".ORG",0
asmKwDb:       .db ".DB",0
asmKwDw:       .db ".DW",0
asmKwNop:      .db "NOP",0
asmKwRet:      .db "RET",0
asmKwHalt:     .db "HALT",0
asmKwXor:      .db "XOR",0
asmKwLd:       .db "LD",0
asmKwJp:       .db "JP",0
asmKwCall:     .db "CALL",0
asmKwJr:       .db "JR",0
asmKwCp:       .db "CP",0
asmKwAdd:      .db "ADD",0
asmKwInc:      .db "INC",0
asmKwDec:      .db "DEC",0
asmKwOut:      .db "OUT",0
asmKwIn:       .db "IN",0
asmKwHl:       .db "HL",0
asmKwDe:       .db "DE",0
asmKwBc:       .db "BC",0
asmKwSp:       .db "SP",0

Tecm8ExpansionBank7Info:
        .db     "T","M","8",EXP_BANK,EXP_VERSION
