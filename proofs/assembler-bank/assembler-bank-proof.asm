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
        ld a,0x05
        ld (EDT_STATE_TOTAL_LINES),a

        call PrepareAsmCommand
        callService SHL_RUN_COMMAND
        jp c,AssemblerProofFail
        ld a,(SHL_PARAM_COMMAND_RESULT_LO)
        cp SHL_RESULT_BUILD_ERROR
        jp nz,AssemblerProofFail
        ld a,(SHL_PARAM_COMMAND_RESULT_HI)
        cp 0x04
        jp nz,AssemblerProofFail
        ld a,(ASM_PARAM_DIAG_LINE)
        cp 0x04
        jp nz,AssemblerProofFail
        ld a,(ASM_PARAM_DIAG_CODE)
        cp ASM_ERR_SYNTAX
        jp nz,AssemblerProofFail

        ld a,"T"
        ld (EDT_BUFFER_BASE+(EDT_RECORD_BYTES*4)+3),a
        call PrepareAsmCommand
        callService SHL_RUN_COMMAND
        jp c,AssemblerProofFail
        ld a,(SHL_PARAM_COMMAND_RESULT_LO)
        cp SHL_RESULT_OK
        jp nz,AssemblerProofFail
        ld hl,(ASM_PARAM_OUTPUT_SIZE_LO)
        ld de,0x0006
        or a
        sbc hl,de
        jp nz,AssemblerProofFail
        ld hl,(ASM_PARAM_ORIGIN_LO)
        ld de,RUN_LOAD_MIN
        or a
        sbc hl,de
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+0)
        cp 0x3E
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+1)
        cp 0x5A
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+2)
        cp 0x32
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+3)
        cp PROGRAM_MARKER & 0xFF
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+4)
        cp PROGRAM_MARKER >> 8
        jp nz,AssemblerProofFail
        ld a,(ASM_OUTPUT_BASE+5)
        cp 0xC9
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
        cp 0x06
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
        .db     0x06,"START:"
        .ds     EDT_RECORD_BYTES-7
        .db     0x09,"LD A,0x5A"
        .ds     EDT_RECORD_BYTES-10
        .db     0x0D,"LD (0x4FF0),A"
        .ds     EDT_RECORD_BYTES-14
        .db     0x03,"REX"
        .ds     EDT_RECORD_BYTES-4
SourceFixtureEnd:
