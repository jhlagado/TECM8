; TECM8 expansion ROM physical bank 6.

        .include "bank_ops.asmi"

        .org    0x8000

EXP_BANK          .equ    0x06
EXP_VERSION       .equ    0x01
MON3_MATRIX_SCAN  .equ    0xCC40
MON3_PARSE_MATRIX_SCAN .equ 0xD142

Tecm8ExpansionBank6Entry:
        cp INP_SVC_READ
        jp z,Tecm8InputRead
        cp INP_SVC_READ_KEY
        jp z,Tecm8InputReadKey
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

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
Tecm8InputReadKey:
        ld a,EXP_BANK
        ld (INP_PARAM_BANK),a
        ld a,EXP_VERSION
        ld (INP_PARAM_VERSION),a
        xor a
        ld (INP_PARAM_STATUS),a
        ld (INP_PARAM_LAST_ERROR),a
        ld (INP_PARAM_EVENT),a
        ld a,(INP_QUEUE_COUNT)
        or a
        jr z,Tecm8InputReadHardware
        ld a,(INP_QUEUE_HEAD)
        add a,a
        ld e,a
        ld d,0x00
        ld hl,INP_QUEUE_BASE
        add hl,de
        ld a,(hl)
        ld (INP_PARAM_KEY),a
        inc hl
        ld a,(hl)
        ld (INP_PARAM_MODIFIERS),a
        ld a,(INP_QUEUE_HEAD)
        inc a
        ld (INP_QUEUE_HEAD),a
        ld a,(INP_QUEUE_COUNT)
        dec a
        ld (INP_QUEUE_COUNT),a
        ld a,0x01
        ld (INP_PARAM_EVENT),a
        ld a,0x86
        or a
        ret

Tecm8InputReadHardware:
        call MON3_MATRIX_SCAN
        ld a,e
        ld (INP_PARAM_RAW_PRIMARY),a
        ld a,d
        ld (INP_PARAM_RAW_SECONDARY),a
        call MON3_PARSE_MATRIX_SCAN
        jr nc,Tecm8InputNoKey
        ld (INP_PARAM_KEY),a
        ld a,(INP_PARAM_RAW_SECONDARY)
        call Tecm8InputModifierFlags
        ld (INP_PARAM_MODIFIERS),a
        and EDT_KEY_MOD_CTRL
        jr z,Tecm8InputHardwareReady
        ld a,(INP_PARAM_KEY)
        cp "A"
        jr c,Tecm8InputNormalizeLower
        cp "Z"+1
        jr nc,Tecm8InputNormalizeLower
        and 0x1F
        ld (INP_PARAM_KEY),a
        jr Tecm8InputHardwareReady

Tecm8InputNormalizeLower:
        cp "a"
        jr c,Tecm8InputHardwareReady
        cp "z"+1
        jr nc,Tecm8InputHardwareReady
        and 0x1F
        ld (INP_PARAM_KEY),a

Tecm8InputHardwareReady:
        ld a,0x01
        ld (INP_PARAM_EVENT),a
        ld a,0x86
        or a
        ret

Tecm8InputNoKey:
        xor a
        ld (INP_PARAM_KEY),a
        ld (INP_PARAM_MODIFIERS),a
        ld a,0x86
        or a
        ret

.routine in A out A,zero clobbers sign,parity,halfCarry
Tecm8InputModifierFlags:
        cp 0x00
        jr z,Tecm8InputModifierShift
        cp 0x01
        jr z,Tecm8InputModifierCtrl
        xor a
        ret

Tecm8InputModifierShift:
        ld a,EDT_KEY_MOD_SHIFT
        ret

Tecm8InputModifierCtrl:
        ld a,EDT_KEY_MOD_CTRL
        ret

Tecm8ExpansionBank6Info:
        .db     "T","M","8",EXP_BANK,EXP_VERSION
