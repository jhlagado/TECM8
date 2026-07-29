; TecMate phase-one assembler and bounded runner proof.

        .org    0x2000

        .include "../../roms/tec1g/tecm8/expansion/bank_ops.asmi"

PROOF_PASS                  .equ    0x42
ASM_PROOF_RESULT            .equ    0x3CB0
PROGRAM_MARKER              .equ    0x4FF0

.routine out carry,zero clobbers sign,parity,halfCarry,A,B,C,D,E,H,L
Start:
        ld a,TFS_SVC_MOUNT
        farCall TFS_BANK,TFS_ENTRY
        jp c,AssemblerProofFail
        ld a,TFS_BRIDGE_BANK
        ld (TFS_PARAM_DRIVER_BANK),a
        ld hl,TFS_SECTOR_BRIDGE
        ld (TFS_PARAM_DRIVER_ADDR_LO),hl
        ld hl,SourceFixture
        ld de,EDT_BUFFER_BASE
        ld bc,SourceFixtureEnd-SourceFixture
        ldir
        ld a,EDT_BUFFER_RECORDS
        ld (EDT_STATE_TOTAL_LINES),a

        call PrepareAsmCommand
        callService SHL_RUN_COMMAND
        jp c,AssemblerProofFail
        ld a,(SHL_PARAM_COMMAND_RESULT_LO)
        cp SHL_RESULT_BUILD_ERROR
        jp nz,AssemblerProofFail
        ld a,(SHL_PARAM_COMMAND_RESULT_HI)
        cp 0x22
        jp nz,AssemblerProofFail
        ld a,(ASM_PARAM_DIAG_LINE)
        cp 0x22
        jp nz,AssemblerProofFail
        ld a,(ASM_PARAM_DIAG_CODE)
        cp ASM_ERR_SYNTAX
        jp nz,AssemblerProofFail

        ld a,"T"
        ld (EDT_BUFFER_BASE+(EDT_RECORD_BYTES*34)+3),a
        call PrepareAsmCommand
        callService SHL_RUN_COMMAND
        jp c,AssemblerProofFail
        ld a,(SHL_PARAM_COMMAND_RESULT_LO)
        cp SHL_RESULT_OK
        jp nz,AssemblerProofFail
        ld hl,(ASM_PARAM_OUTPUT_SIZE_LO)
        ld de,0x003B
        or a
        sbc hl,de
        jp nz,AssemblerProofFail
        ld hl,(ASM_PARAM_ORIGIN_LO)
        ld de,RUN_LOAD_MIN
        or a
        sbc hl,de
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+0)
        cp 0xF3
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+1)
        cp 0x06
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+2)
        cp 0x03
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+7)
        cp 0xAF
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+8)
        cp 0xB1
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+9)
        cp 0xE6
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+10)
        cp 0x0F
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+21)
        cp 0x20
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+22)
        cp 0x0F
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+23)
        cp 0x10
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+24)
        cp 0xFE
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+25)
        cp 0xCD
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+26)
        cp 0x1E
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+27)
        cp 0x40
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+30)
        cp 0xF5
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+36)
        cp 0xF1
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+37)
        cp 0xC8
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+43)
        cp 0x37
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+46)
        cp 0x62
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+47)
        cp 0x71
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+48)
        cp 0x7E
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+49)
        cp 0x34
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+50)
        cp 0x35
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+51)
        cp 0xA6
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+52)
        cp 0xEA
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+55)
        cp 0xFC
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+58)
        cp 0xD8
        jp nz,AssemblerProofFail
        ld a,(ASM_MAP_BASE+0)
        cp "T"
        jp nz,AssemblerProofFail
        ld a,(ASM_MAP_BASE+1)
        cp "M"
        jp nz,AssemblerProofFail
        ld a,(ASM_MAP_BASE+2)
        cp "A"
        jp nz,AssemblerProofFail
        ld a,(ASM_MAP_BASE+3)
        cp "P"
        jp nz,AssemblerProofFail
        ld a,(ASM_MAP_BASE+6)
        cp 0x07
        jp nz,AssemblerProofFail
        ld a,(ASM_MAP_BASE+8)
        cp "B"
        jp nz,AssemblerProofFail
        ld a,(ASM_MAP_BASE+16)
        cp PROGRAM_MARKER & 0xFF
        jp nz,AssemblerProofFail
        ld a,(ASM_MAP_BASE+17)
        cp PROGRAM_MARKER >> 8
        jp nz,AssemblerProofFail
        ld a,(ASM_MAP_BASE+19)
        cp 0x02
        jp nz,AssemblerProofFail
        ld a,(ASM_MAP_BASE+28)
        cp 0x5A
        jp nz,AssemblerProofFail
        ld a,(ASM_MAP_BASE+31)
        cp 0x02
        jp nz,AssemblerProofFail
        ld a,(ASM_MAP_BASE+40)
        cp RUN_LOAD_MIN & 0xFF
        jp nz,AssemblerProofFail
        ld a,(ASM_MAP_BASE+41)
        cp RUN_LOAD_MIN >> 8
        jp nz,AssemblerProofFail
        ld a,(ASM_MAP_BASE+43)
        cp 0x01
        jp nz,AssemblerProofFail
        ld a,(TFS_BRIDGE_ARTIFACT_DATA_WRITES)
        cp 0x02
        jp nz,AssemblerProofFail
        ld a,(TFS_BRIDGE_ARTIFACT_META_WRITES)
        cp 0x02
        jp nz,AssemblerProofFail

        xor a
        ld (PROGRAM_MARKER),a
        call PrepareRunCommand
        callService SHL_RUN_COMMAND
        jp c,AssemblerProofFail
        ld a,(SHL_PARAM_COMMAND_RESULT_LO)
        cp SHL_RESULT_OK
        jp nz,AssemblerProofFail
        ld a,(PROGRAM_MARKER)
        cp 0x5A
        jp nz,AssemblerProofFail
        ld a,(RUN_PARAM_RETURN_COUNT)
        cp 0x01
        jp nz,AssemblerProofFail
        ld a,(RUN_PARAM_LOAD_HI)
        cp RUN_LOAD_MIN >> 8
        jp nz,AssemblerProofFail
        ld a,(RUN_PARAM_BYTES_LO)
        cp 0x3B
        jp nz,AssemblerProofFail

        ld a,PROOF_PASS
        ld (ASM_PROOF_RESULT),a
        halt

PrepareAsmCommand:
        ld hl,AsmCommand
        ld de,SHL_COMMAND_BUFFER
        ld bc,0x0004
        ldir
        ret

PrepareRunCommand:
        ld hl,RunCommand
        ld de,SHL_COMMAND_BUFFER
        ld bc,0x0004
        ldir
        ret

AssemblerProofFail:
        ld (ASM_PROOF_RESULT),a
        halt

AsmCommand:
        .db     "asm",0
RunCommand:
        .db     "run",0

SourceFixture:
        .db     0x0B,".ORG 0x4000"
        .ds     EDT_RECORD_BYTES-12
        .db     0x15,"BASE .EQU 0x4F00+0xF0"
        .ds     EDT_RECORD_BYTES-22
        .db     0x13,"VALUE: .EQU 0x50+10"
        .ds     EDT_RECORD_BYTES-20
        .db     0x06,"START:"
        .ds     EDT_RECORD_BYTES-7
        .db     0x02,"DI"
        .ds     EDT_RECORD_BYTES-3
        .db     0x06,"LD B,3"
        .ds     EDT_RECORD_BYTES-7
        .db     0x0A,"LD C,VALUE"
        .ds     EDT_RECORD_BYTES-11
        .db     0x07,"PUSH BC"
        .ds     EDT_RECORD_BYTES-8
        .db     0x06,"POP DE"
        .ds     EDT_RECORD_BYTES-7
        .db     0x05,"XOR A"
        .ds     EDT_RECORD_BYTES-6
        .db     0x04,"OR C"
        .ds     EDT_RECORD_BYTES-5
        .db     0x08,"AND 0x0F"
        .ds     EDT_RECORD_BYTES-9
        .db     0x07,"ADD A,E"
        .ds     EDT_RECORD_BYTES-8
        .db     0x07,"ADC A,0"
        .ds     EDT_RECORD_BYTES-8
        .db     0x05,"INC D"
        .ds     EDT_RECORD_BYTES-6
        .db     0x05,"DEC D"
        .ds     EDT_RECORD_BYTES-6
        .db     0x05,"SUB D"
        .ds     EDT_RECORD_BYTES-6
        .db     0x07,"SBC A,0"
        .ds     EDT_RECORD_BYTES-8
        .db     0x07,"CP 0x61"
        .ds     EDT_RECORD_BYTES-8
        .db     0x0A,"JR NZ,FAIL"
        .ds     EDT_RECORD_BYTES-11
        .db     0x05,"LOOP:"
        .ds     EDT_RECORD_BYTES-6
        .db     0x09,"DJNZ LOOP"
        .ds     EDT_RECORD_BYTES-10
        .db     0x0A,"CALL STORE"
        .ds     EDT_RECORD_BYTES-11
        .db     0x02,"EI"
        .ds     EDT_RECORD_BYTES-3
        .db     0x03,"RET"
        .ds     EDT_RECORD_BYTES-4
        .db     0x06,"STORE:"
        .ds     EDT_RECORD_BYTES-7
        .db     0x07,"PUSH AF"
        .ds     EDT_RECORD_BYTES-8
        .db     0x0A,"LD A,VALUE"
        .ds     EDT_RECORD_BYTES-11
        .db     0x0B,"LD (BASE),A"
        .ds     EDT_RECORD_BYTES-12
        .db     0x06,"POP AF"
        .ds     EDT_RECORD_BYTES-7
        .db     0x05,"RET Z"
        .ds     EDT_RECORD_BYTES-6
        .db     0x05,"FAIL:"
        .ds     EDT_RECORD_BYTES-6
        .db     0x05,"XOR A"
        .ds     EDT_RECORD_BYTES-6
        .db     0x0B,"LD (BASE),A"
        .ds     EDT_RECORD_BYTES-12
        .db     0x03,"REX"
        .ds     EDT_RECORD_BYTES-4
        .db     0x07,"UNUSED:"
        .ds     EDT_RECORD_BYTES-8
        .db     0x03,"SCF"
        .ds     EDT_RECORD_BYTES-4
        .db     0x03,"CCF"
        .ds     EDT_RECORD_BYTES-4
        .db     0x03,"CPL"
        .ds     EDT_RECORD_BYTES-4
        .db     0x06,"LD H,D"
        .ds     EDT_RECORD_BYTES-7
        .db     0x09,"LD (HL),C"
        .ds     EDT_RECORD_BYTES-10
        .db     0x09,"LD A,(HL)"
        .ds     EDT_RECORD_BYTES-10
        .db     0x08,"INC (HL)"
        .ds     EDT_RECORD_BYTES-9
        .db     0x08,"DEC (HL)"
        .ds     EDT_RECORD_BYTES-9
        .db     0x08,"AND (HL)"
        .ds     EDT_RECORD_BYTES-9
        .db     0x0A,"JP PE,FAIL"
        .ds     EDT_RECORD_BYTES-11
        .db     0x0C,"CALL M,STORE"
        .ds     EDT_RECORD_BYTES-13
        .db     0x05,"RET C"
        .ds     EDT_RECORD_BYTES-6
SourceFixtureEnd:
