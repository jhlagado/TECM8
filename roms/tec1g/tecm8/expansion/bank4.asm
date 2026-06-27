; TECM8 expansion ROM physical bank 4.

        .include "bank_ops.asmi"

        .org    0x8000

TECM8_EXPANSION_BANK          .equ    0x04
TECM8_EXPANSION_VERSION       .equ    0x01

@Tecm8ExpansionBank4Entry:
        jp glcdBoundaryEntryImpl

        .org    TECM8_GLCD_INIT
@glcdInit:
        jp glcdUnsupported

        .org    TECM8_GLCD_CLEAR
@glcdClear:
        jp glcdUnsupported

        .org    TECM8_GLCD_PLOT
@glcdPlot:
        jp glcdUnsupported

        .org    0x8040
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

        .org    0x8100
@Tecm8ExpansionBank4Info:
        .db     "T","M","8",TECM8_EXPANSION_BANK,TECM8_EXPANSION_VERSION
