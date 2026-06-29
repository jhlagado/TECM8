; TECM8 expansion ROM physical bank 5.

        .org    0x8000

EXP_BANK          .equ    0x05
EXP_VERSION       .equ    0x01

@Tecm8ExpansionBank5Entry:
        ret

@Tecm8ExpansionBank5Info:
        .db     "T","M","8",EXP_BANK,EXP_VERSION
