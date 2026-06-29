; TECM8 expansion ROM physical bank 6.

        .org    0x8000

EXP_BANK          .equ    0x06
EXP_VERSION       .equ    0x01

@Tecm8ExpansionBank6Entry:
        ret

@Tecm8ExpansionBank6Info:
        .db     "T","M","8",EXP_BANK,EXP_VERSION
