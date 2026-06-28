; TECM8 expansion ROM physical bank 4.

        .include "bank_ops.asmi"

        .org    0x8000

TECM8_EXPANSION_BANK          .equ    0x04
TECM8_EXPANSION_VERSION       .equ    0x01

@Tecm8ExpansionBank4Entry:
        cp TECM8_GLCD_SVC_INIT
        jp z,glcdUnsupported
        cp TECM8_GLCD_SVC_CLEAR
        jp z,glcdUnsupported
        cp TECM8_GLCD_SVC_PLOT
        jp z,glcdUnsupported
        jp glcdBoundaryEntryImpl

@glcdInit:
        jp glcdUnsupported

@glcdClear:
        jp glcdUnsupported

@glcdPlot:
        jp glcdUnsupported

@glcdBoundaryEntryImpl:
        ld a,TECM8_EXPANSION_BANK
        ld (TECM8_GLCD_PARAM_BANK),a
        ld a,TECM8_EXPANSION_VERSION
        ld (TECM8_GLCD_PARAM_VERSION),a
        ld a,TECM8_GLCD_FEATURE_BOUNDARY
        ld (TECM8_GLCD_PARAM_FEATURES),a
        xor a
        ld (TECM8_GLCD_PARAM_STATUS),a
        ld (TECM8_GLCD_PARAM_LAST_ERROR),a
        ld a,0x84
        or a
        ret

@glcdUnsupported:
        ld a,TECM8_GLCD_ERR_UNSUPPORTED
        ld (TECM8_GLCD_PARAM_STATUS),a
        ld (TECM8_GLCD_PARAM_LAST_ERROR),a
        scf
        ret

@Tecm8ExpansionBank4Info:
        .db     "T","M","8",TECM8_EXPANSION_BANK,TECM8_EXPANSION_VERSION
