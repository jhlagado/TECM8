; TECM8 expansion ROM physical bank 8.

        .org    0x8000

EXP_BANK          .equ    0x08
EXP_VERSION       .equ    0x01

@Tecm8ExpansionBank8Entry:
        ret

@Tecm8ExpansionBank8Info:
        .db     "T","M","8",EXP_BANK,EXP_VERSION
