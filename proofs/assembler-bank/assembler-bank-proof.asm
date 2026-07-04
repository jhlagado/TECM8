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
        ld a,0xAB
        ld (ASM_PARAM_TARGET_LO),a
        ld a,0x3B
        ld (ASM_PARAM_TARGET_HI),a

        ld a,ASM_SVC_ASSEMBLE
        farCall ASM_BANK,ASM_ENTRY
        jp nc,AssemblerProofFail
        cp ASM_ERR_UNSUPPORTED
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
        ld a,(ASM_PARAM_TARGET_LO)
        cp 0xAB
        jp nz,AssemblerProofFail
        ld a,(ASM_PARAM_TARGET_HI)
        cp 0x3B
        jp nz,AssemblerProofFail

        xor a
        ld (RUN_PARAM_STATUS),a
        ld (RUN_PARAM_LAST_ERROR),a
        ld (RUN_PARAM_RESULT_LO),a
        ld (RUN_PARAM_RESULT_HI),a
        ld a,0xAB
        ld (RUN_PARAM_TARGET_LO),a
        ld a,0x3B
        ld (RUN_PARAM_TARGET_HI),a

        ld a,RUN_SVC_RUN
        farCall RUN_BANK,RUN_ENTRY
        jp nc,AssemblerProofFail
        cp RUN_ERR_UNSUPPORTED
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
        ld a,(RUN_PARAM_TARGET_LO)
        cp 0xAB
        jp nz,AssemblerProofFail
        ld a,(RUN_PARAM_TARGET_HI)
        cp 0x3B
        jp nz,AssemblerProofFail

        ld a,PROOF_PASS
        ld (ASM_PROOF_RESULT),a
        halt

AssemblerProofFail:
        ld (ASM_PROOF_RESULT),a
        halt
