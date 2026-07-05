; TecMate bank-7 assembler service skeleton proof.

        .org    0x4000

        .include "../../roms/tec1g/tecm8/expansion/bank_ops.asmi"

PROOF_PASS                  .equ    0x42
ASM_PROOF_RESULT            .equ    0x3C10

;! out carry,zero
;! clobbers sign,parity,halfCarry,A,B,C,D,E,H,L
@Start:
        xor a
        ld (ASM_PARAM_STATUS),a
        ld (ASM_PARAM_LAST_ERROR),a
        ld (ASM_PARAM_RESULT_LO),a
        ld (ASM_PARAM_RESULT_HI),a
        ld a,"a"
        ld (SHL_COMMAND_BUFFER),a
        ld a,"s"
        ld (SHL_COMMAND_BUFFER+1),a
        ld a,"m"
        ld (SHL_COMMAND_BUFFER+2),a
        xor a
        ld (SHL_COMMAND_BUFFER+3),a
        callService SHL_RUN_COMMAND
        jp c,AssemblerProofFail
        cp 0x80
        jp nz,AssemblerProofFail
        ld a,(SHL_PARAM_COMMAND_ACTION)
        cp SHL_ACTION_ASM
        jp nz,AssemblerProofFail
        ld a,(SHL_TARGET_KIND)
        cp SHL_TARGET_KIND_PROJECT_MAIN
        jp nz,AssemblerProofFail
        ld a,(SHL_PARAM_COMMAND_TARGET_LO)
        cp SHL_TARGET_DESC & 0xFF
        jp nz,AssemblerProofFail
        ld a,(SHL_PARAM_COMMAND_TARGET_HI)
        cp SHL_TARGET_DESC >> 8
        jp nz,AssemblerProofFail
        ld a,(ASM_PARAM_BANK)
        cp ASM_BANK
        jp nz,AssemblerProofFail
        ld a,(ASM_PARAM_VERSION)
        cp 0x01
        jp nz,AssemblerProofFail
        ld a,(ASM_PARAM_STATUS)
        cp ASM_ERR_UNSUPPORTED
        jp nz,AssemblerProofFail
        ld a,(ASM_PARAM_LAST_ERROR)
        cp ASM_ERR_UNSUPPORTED
        jp nz,AssemblerProofFail
        ld a,(ASM_PARAM_RESULT_LO)
        cp SHL_RESULT_UNSUPPORTED
        jp nz,AssemblerProofFail
        ld a,(ASM_PARAM_RESULT_HI)
        or a
        jp nz,AssemblerProofFail
        ld a,(SHL_PARAM_COMMAND_RESULT_LO)
        cp SHL_RESULT_UNSUPPORTED
        jp nz,AssemblerProofFail
        ld a,(SHL_PARAM_COMMAND_RESULT_HI)
        or a
        jp nz,AssemblerProofFail
        ld a,(ASM_PARAM_TARGET_LO)
        cp SHL_TARGET_DESC & 0xFF
        jp nz,AssemblerProofFail
        ld a,(ASM_PARAM_TARGET_HI)
        cp SHL_TARGET_DESC >> 8
        jp nz,AssemblerProofFail
        ld a,0x7F
        farCall ASM_BANK,ASM_ENTRY
        jp nc,AssemblerProofFail
        cp ASM_ERR_UNKNOWN
        jp nz,AssemblerProofFail

        xor a
        ld (RUN_PARAM_STATUS),a
        ld (RUN_PARAM_LAST_ERROR),a
        ld (RUN_PARAM_RESULT_LO),a
        ld (RUN_PARAM_RESULT_HI),a
        ld a,"r"
        ld (SHL_COMMAND_BUFFER),a
        ld a,"u"
        ld (SHL_COMMAND_BUFFER+1),a
        ld a,"n"
        ld (SHL_COMMAND_BUFFER+2),a
        xor a
        ld (SHL_COMMAND_BUFFER+3),a
        callService SHL_RUN_COMMAND
        jp c,AssemblerProofFail
        cp 0x80
        jp nz,AssemblerProofFail
        ld a,(SHL_PARAM_COMMAND_ACTION)
        cp SHL_ACTION_RUN
        jp nz,AssemblerProofFail
        ld a,(SHL_TARGET_KIND)
        cp SHL_TARGET_KIND_PROJECT_OUTPUT
        jp nz,AssemblerProofFail
        ld a,(SHL_PARAM_COMMAND_TARGET_LO)
        cp SHL_TARGET_DESC & 0xFF
        jp nz,AssemblerProofFail
        ld a,(SHL_PARAM_COMMAND_TARGET_HI)
        cp SHL_TARGET_DESC >> 8
        jp nz,AssemblerProofFail
        ld a,(RUN_PARAM_BANK)
        cp RUN_BANK
        jp nz,AssemblerProofFail
        ld a,(RUN_PARAM_VERSION)
        cp 0x01
        jp nz,AssemblerProofFail
        ld a,(RUN_PARAM_STATUS)
        cp RUN_ERR_UNSUPPORTED
        jp nz,AssemblerProofFail
        ld a,(RUN_PARAM_LAST_ERROR)
        cp RUN_ERR_UNSUPPORTED
        jp nz,AssemblerProofFail
        ld a,(RUN_PARAM_RESULT_LO)
        cp SHL_RESULT_UNSUPPORTED
        jp nz,AssemblerProofFail
        ld a,(RUN_PARAM_RESULT_HI)
        or a
        jp nz,AssemblerProofFail
        ld a,(SHL_PARAM_COMMAND_RESULT_LO)
        cp SHL_RESULT_UNSUPPORTED
        jp nz,AssemblerProofFail
        ld a,(SHL_PARAM_COMMAND_RESULT_HI)
        or a
        jp nz,AssemblerProofFail
        ld a,(RUN_PARAM_TARGET_LO)
        cp SHL_TARGET_DESC & 0xFF
        jp nz,AssemblerProofFail
        ld a,(RUN_PARAM_TARGET_HI)
        cp SHL_TARGET_DESC >> 8
        jp nz,AssemblerProofFail
        ld a,0x7F
        farCall RUN_BANK,RUN_ENTRY
        jp nc,AssemblerProofFail
        cp RUN_ERR_UNKNOWN
        jp nz,AssemblerProofFail

        ld a,PROOF_PASS
        ld (ASM_PROOF_RESULT),a
        halt

AssemblerProofFail:
        ld (ASM_PROOF_RESULT),a
        halt
