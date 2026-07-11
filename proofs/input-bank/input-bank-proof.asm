; TecMate bank-6 input snapshot proof.
;
; Runs from RAM with the project monitor and expansion ROM loaded. It proves
; the input snapshot boundary publishes the current neutral input state through
; its RAM parameter block.

        .org    0x4000

        .include "../../roms/tec1g/tecm8/expansion/bank_ops.asmi"

PROOF_PASS                  .equ    0x42
INP_PROOF_RESULT            .equ    0x3BD0

.routine out carry,zero clobbers sign,parity,halfCarry,A,B,C,D,E,H,L
Start:
        ld a,0xAA
        ld (INP_PARAM_STATUS),a
        ld (INP_PARAM_LAST_ERROR),a
        ld (INP_PARAM_KEYS_LO),a
        ld (INP_PARAM_KEYS_HI),a
        ld (INP_PARAM_JOYSTICK),a
        ld (INP_PARAM_MODIFIERS),a

        ld a,INP_SVC_READ
        farCall 0x06,INP_ENTRY
        jp c,InputProofFail
        cp 0x86
        jp nz,InputProofFail

        ld a,(INP_PARAM_BANK)
        cp 0x06
        jp nz,InputProofFail
        ld a,(INP_PARAM_VERSION)
        cp 0x01
        jp nz,InputProofFail
        ld a,(INP_PARAM_STATUS)
        or a
        jp nz,InputProofFail
        ld a,(INP_PARAM_LAST_ERROR)
        or a
        jp nz,InputProofFail
        ld a,(INP_PARAM_KEYS_LO)
        or a
        jp nz,InputProofFail
        ld a,(INP_PARAM_KEYS_HI)
        or a
        jp nz,InputProofFail
        ld a,(INP_PARAM_JOYSTICK)
        or a
        jp nz,InputProofFail
        ld a,(INP_PARAM_MODIFIERS)
        or a
        jp nz,InputProofFail

        ld a,0x5A
        ld (INP_PARAM_STATUS),a
        ld a,0xA5
        ld (INP_PARAM_LAST_ERROR),a
        ld a,0x7F
        farCall 0x06,INP_ENTRY
        jp nc,InputProofFail
        cp INP_ERR_UNKNOWN
        jp nz,InputProofFail
        ld a,(INP_PARAM_STATUS)
        cp 0x5A
        jp nz,InputProofFail
        ld a,(INP_PARAM_LAST_ERROR)
        cp 0xA5
        jp nz,InputProofFail

        ld a,PROOF_PASS
        ld (INP_PROOF_RESULT),a
        halt

InputProofFail:
        ld (INP_PROOF_RESULT),a
        halt
