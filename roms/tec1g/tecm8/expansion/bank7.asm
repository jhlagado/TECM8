; TECM8 expansion ROM physical bank 7.

        .org    0x8000

TECM8_EXPANSION_BANK          .equ    0x07
TECM8_EXPANSION_VERSION       .equ    0x01

@Tecm8ExpansionBank7Entry:
        RET

@Tecm8ExpansionBank7Info:
        .db     "T","M","8",TECM8_EXPANSION_BANK,TECM8_EXPANSION_VERSION
