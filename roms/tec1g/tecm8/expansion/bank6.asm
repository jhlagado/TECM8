; TECM8 expansion ROM physical bank 6.

        .include "bank_ops.asmi"

        .org    0x8000

EXP_BANK          .equ    0x06
EXP_VERSION       .equ    0x01

Tecm8ExpansionBank6Entry:
        cp INP_SVC_READ
        jp z,Tecm8InputRead
        ld a,INP_ERR_UNKNOWN
        scf
        ret

Tecm8InputRead:
        ld a,EXP_BANK
        ld (INP_PARAM_BANK),a
        ld a,EXP_VERSION
        ld (INP_PARAM_VERSION),a
        xor a
        ld (INP_PARAM_STATUS),a
        ld (INP_PARAM_LAST_ERROR),a
        ld (INP_PARAM_KEYS_LO),a
        ld (INP_PARAM_KEYS_HI),a
        ld (INP_PARAM_JOYSTICK),a
        ld (INP_PARAM_MODIFIERS),a
        ld a,0x86
        or a
        ret

Tecm8ExpansionBank6Info:
        .db     "T","M","8",EXP_BANK,EXP_VERSION
