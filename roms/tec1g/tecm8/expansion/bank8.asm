; TECM8 expansion ROM physical bank 8.

        .include "bank_ops.asmi"

        .org    0x8000

EXP_BANK          .equ    0x08
EXP_VERSION       .equ    0x01

Tecm8ExpansionBank8Entry:
        cp RUN_SVC_RUN
        jp z,runUnsupported
        ld a,RUN_ERR_UNKNOWN
        scf
        ret

runUnsupported:
        ld a,EXP_BANK
        ld (RUN_PARAM_BANK),a
        ld a,EXP_VERSION
        ld (RUN_PARAM_VERSION),a
        ld a,RUN_ERR_UNSUPPORTED
        ld (RUN_PARAM_STATUS),a
        ld (RUN_PARAM_LAST_ERROR),a
        ld a,SHL_RESULT_UNSUPPORTED
        ld (RUN_PARAM_RESULT_LO),a
        xor a
        ld (RUN_PARAM_RESULT_HI),a
        ld a,RUN_ERR_UNSUPPORTED
        scf
        ret

Tecm8ExpansionBank8Info:
        .db     "T","M","8",EXP_BANK,EXP_VERSION
