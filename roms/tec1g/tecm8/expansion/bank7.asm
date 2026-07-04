; TECM8 expansion ROM physical bank 7.

        .include "bank_ops.asmi"

        .org    0x8000

EXP_BANK          .equ    0x07
EXP_VERSION       .equ    0x01

@Tecm8ExpansionBank7Entry:
        cp ASM_SVC_ASSEMBLE
        jp z,asmAssembleUnsupported
        ld a,ASM_ERR_UNKNOWN
        scf
        ret

asmAssembleUnsupported:
        ld a,EXP_BANK
        ld (ASM_PARAM_BANK),a
        ld a,EXP_VERSION
        ld (ASM_PARAM_VERSION),a
        ld a,ASM_ERR_UNSUPPORTED
        ld (ASM_PARAM_STATUS),a
        ld (ASM_PARAM_LAST_ERROR),a
        ld a,SHL_RESULT_UNSUPPORTED
        ld (ASM_PARAM_RESULT_LO),a
        xor a
        ld (ASM_PARAM_RESULT_HI),a
        ld a,ASM_ERR_UNSUPPORTED
        scf
        ret

@Tecm8ExpansionBank7Info:
        .db     "T","M","8",EXP_BANK,EXP_VERSION
