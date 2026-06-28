; TecMate shell launch proof.
;
; Runs from RAM with the project monitor and expansion ROM loaded. It proves
; that a monitor-style bank call can enter the resident TecMate shell boundary,
; and that the bank-0 service registry reaches the same shell entry.

        .org    0x4000

        .include "../../roms/tec1g/tecm8/expansion/bank_ops.asmi"

PROOF_PASS                  .equ    0x42
PROOF_FAIL_DIRECT           .equ    0xE0
PROOF_FAIL_REGISTRY         .equ    0xE1
PROOF_FAIL_PARAMS           .equ    0xE2
PROOF_TRACE_BASE            .equ    0x3BC0
PROOF_RESULT                .equ    0x3BD0

;! out carry,zero
;! clobbers sign,parity,halfCarry,A,B,C,D,E,H,L
@Start:
        ld hl,TECM8_SHELL_PARAM_BASE
        ld b,16
ClearShellParams:
        ld (hl),0
        inc hl
        djnz ClearShellParams

        farCall 0x00,TECM8_SHELL_ENTRY
        jp c,FailDirect
        cp 0x80
        jp nz,FailDirect
        ld (PROOF_TRACE_BASE+0),a
        call CheckShellParams
        jp c,FailParams

        ld hl,TECM8_SHELL_PARAM_BASE
        ld b,16
ClearShellParamsAgain:
        ld (hl),0
        inc hl
        djnz ClearShellParamsAgain

        callService TECM8_SERVICE_SHELL_ENTRY
        jp c,FailRegistry
        cp 0x80
        jp nz,FailRegistry
        ld (PROOF_TRACE_BASE+1),a
        call CheckShellParams
        jp c,FailParams

        ld a,PROOF_PASS
        ld (PROOF_RESULT),a
        halt

CheckShellParams:
        ld a,(TECM8_SHELL_PARAM_STATUS)
        cp TECM8_SHELL_STATUS_OK
        scf
        ret nz
        ld a,(TECM8_SHELL_PARAM_LAST_ERROR)
        cp TECM8_SHELL_STATUS_OK
        scf
        ret nz
        ld a,(TECM8_SHELL_PARAM_BANK)
        cp 0x00
        scf
        ret nz
        ld a,(TECM8_SHELL_PARAM_VERSION)
        cp 0x01
        scf
        ret nz
        ld a,(TECM8_SHELL_PARAM_FEATURES)
        cp TECM8_SHELL_FEATURE_ENTRY
        scf
        ret nz
        or a
        ret

FailDirect:
        ld a,PROOF_FAIL_DIRECT
        jr Fail
FailRegistry:
        ld a,PROOF_FAIL_REGISTRY
        jr Fail
FailParams:
        ld a,PROOF_FAIL_PARAMS
Fail:
        ld (PROOF_RESULT),a
        halt
