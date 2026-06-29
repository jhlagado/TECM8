; TECM8 expansion ROM physical bank 7.

        .org    0x8000

EXP_BANK          .equ    0x07
EXP_VERSION       .equ    0x01

@Tecm8ExpansionBank7Entry:
        ret

@Tecm8ExpansionBank7Info:
        .db     "T","M","8",EXP_BANK,EXP_VERSION
