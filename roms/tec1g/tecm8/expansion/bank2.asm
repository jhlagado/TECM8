; TECM8 expansion ROM physical bank 2.

        .include "bank_ops.asmi"

        .org    0x8000

TECM8_EXPANSION_BANK          .equ    0x02
TECM8_EXPANSION_VERSION       .equ    0x01

@Tecm8ExpansionBank2Entry:
        ld a,TECM8_EXPANSION_BANK
        ld (TECM8_DEMO_TRACE_2),a
        ld a,0x01
        ld hl,TECM8_DEMO_BANK1_HELPER
        ld c,TECM8_BIOS_BANK_CALL
        rst 10H
        ld a,TECM8_EXPANSION_BANK
        RET

        .org    0x8020
@Tecm8ExpansionBank2Target:
        ld a,0x22
        ld (TECM8_DEMO_TRACE_6),a
Tecm8ExpansionBank2Hold:
        jr Tecm8ExpansionBank2Hold

@Tecm8ExpansionBank2Info:
        .db     "T","M","8",TECM8_EXPANSION_BANK,TECM8_EXPANSION_VERSION
