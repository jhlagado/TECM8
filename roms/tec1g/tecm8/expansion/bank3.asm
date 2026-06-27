; TECM8 expansion ROM physical bank 3.

        .org    0x8000

TECM8_EXPANSION_BANK          .equ    0x03
TECM8_EXPANSION_VERSION       .equ    0x01

@Tecm8ExpansionBank3Entry:
        RET

@Tecm8ExpansionBank3Info:
        .db     "T","M","8",TECM8_EXPANSION_BANK,TECM8_EXPANSION_VERSION
