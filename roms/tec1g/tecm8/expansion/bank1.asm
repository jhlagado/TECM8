; TECM8 expansion ROM physical bank 1.

        .include "bank_ops.asmi"

        .org    0x8000

TECM8_EXPANSION_BANK          .equ    0x01
TECM8_EXPANSION_VERSION       .equ    0x01

@Tecm8ExpansionBank1Entry:
        ld a,TECM8_EXPANSION_BANK
        ld (TECM8_DEMO_TRACE_1),a
        farCall 0x02,TECM8_DEMO_BANK2_ENTRY
        ld (TECM8_DEMO_TRACE_3),a
        ld a,TECM8_EXPANSION_BANK
        RET

        .org    0x8010
@Tecm8ExpansionBank1Helper:
        ld a,0x11
        ld (TECM8_DEMO_TRACE_5),a
        ret

@Tecm8ExpansionBank1Info:
        .db     "T","M","8",TECM8_EXPANSION_BANK,TECM8_EXPANSION_VERSION
