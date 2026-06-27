; TECM8 expansion ROM physical bank 5.

        .org    0x8000

TECM8_EXPANSION_BANK          .equ    0x05
TECM8_EXPANSION_VERSION       .equ    0x01

@Tecm8ExpansionBank5Entry:
        RET

@Tecm8ExpansionBank5Info:
        .db     "T","M","8",TECM8_EXPANSION_BANK,TECM8_EXPANSION_VERSION
