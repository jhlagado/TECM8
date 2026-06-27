; TECM8 expansion ROM physical bank 4.

        .org    0x8000

TECM8_EXPANSION_BANK          .equ    0x04
TECM8_EXPANSION_VERSION       .equ    0x01

@Tecm8ExpansionBank4Entry:
        RET

@Tecm8ExpansionBank4Info:
        .db     "T","M","8",TECM8_EXPANSION_BANK,TECM8_EXPANSION_VERSION
