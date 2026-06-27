; TECM8 expansion ROM physical bank 6.

        .org    0x8000

TECM8_EXPANSION_BANK          .equ    0x06
TECM8_EXPANSION_VERSION       .equ    0x01

@Tecm8ExpansionBank6Entry:
        ret

@Tecm8ExpansionBank6Info:
        .db     "T","M","8",TECM8_EXPANSION_BANK,TECM8_EXPANSION_VERSION
