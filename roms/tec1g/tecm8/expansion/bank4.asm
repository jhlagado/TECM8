; TECM8 expansion ROM physical bank 4.

        .include "bank_ops.asmi"

        .org    0x8000

EXP_BANK          .equ    0x04
EXP_VERSION       .equ    0x01

Tecm8ExpansionBank4Entry:
        cp GLC_SVC_INIT
        jp z,glcdUnsupported
        cp GLC_SVC_CLEAR
        jp z,glcdUnsupported
        cp GLC_SVC_PLOT
        jp z,glcdUnsupported
        jp glcdBoundaryEntryImpl

glcdInit:
        jp glcdUnsupported

glcdClear:
        jp glcdUnsupported

glcdPlot:
        jp glcdUnsupported

glcdBoundaryEntryImpl:
        ld a,EXP_BANK
        ld (GLC_PARAM_BANK),a
        ld a,EXP_VERSION
        ld (GLC_PARAM_VERSION),a
        ld a,GLC_FEATURE_BOUNDARY
        ld (GLC_PARAM_FEATURES),a
        xor a
        ld (GLC_PARAM_STATUS),a
        ld (GLC_PARAM_LAST_ERROR),a
        ld a,0x84
        or a
        ret

glcdUnsupported:
        ld a,GLC_ERR_UNSUPPORTED
        ld (GLC_PARAM_STATUS),a
        ld (GLC_PARAM_LAST_ERROR),a
        scf
        ret

Tecm8ExpansionBank4Info:
        .db     "T","M","8",EXP_BANK,EXP_VERSION
