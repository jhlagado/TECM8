; TecMate shell launch proof.
;
; Runs from RAM with the project monitor and expansion ROM loaded. It proves
; that the monitor service bridge can enter the resident TecMate shell boundary.

        .org    0x4000

        .include "../../roms/tec1g/tecm8/expansion/bank_ops.asmi"

PROOF_PASS                  .equ    0x42
PROOF_FAIL_SERVICE          .equ    0xE1
PROOF_FAIL_PARAMS           .equ    0xE2
PROOF_FAIL_SPLASH           .equ    0xE3
PROOF_TRACE_BASE            .equ    0x3BC0
PROOF_RESULT                .equ    0x3BD0

;! out carry,zero
;! clobbers sign,parity,halfCarry,A,B,C,D,E,H,L
@Start:
        ld hl,SHL_PARAM_BASE
        ld b,16
ClearShellParams:
        ld (hl),0
        inc hl
        djnz ClearShellParams

        callService SHL_ENTRY
        jp c,FailService
        cp 0x80
        jp nz,FailService
        ld (PROOF_TRACE_BASE+0),a
        call CheckShellParams
        jp c,FailParams
        call CheckShellSplash
        jp c,FailSplash

        ld a,PROOF_PASS
        ld (PROOF_RESULT),a
        halt

CheckShellParams:
        ld a,(SHL_PARAM_STATUS)
        cp SHL_STATUS_OK
        scf
        ret nz
        ld a,(SHL_PARAM_LAST_ERROR)
        cp SHL_STATUS_OK
        scf
        ret nz
        ld a,(SHL_PARAM_BANK)
        cp 0x00
        scf
        ret nz
        ld a,(SHL_PARAM_VERSION)
        cp 0x01
        scf
        ret nz
        ld a,(SHL_PARAM_FEATURES)
        cp SHL_FEATURE_ENTRY+SHL_FEATURE_SPLASH+SHL_FEATURE_COMMAND_LOOP
        scf
        ret nz
        or a
        ret

CheckShellSplash:
        ld hl,SHL_SPLASH_BUFFER
        ld de,ExpectedSplash
CheckShellSplashNext:
        ld a,(de)
        cp (hl)
        scf
        ret nz
        inc hl
        inc de
        or a
        jr nz,CheckShellSplashNext
        ld a,(TMS_PARAM_CURSOR_LO)
        cp 0x07
        scf
        ret nz
        ld a,(TMS_PARAM_CURSOR_HI)
        cp 0x00
        scf
        ret nz
        or a
        ret

ExpectedSplash:
        .db     "TecMate",0

FailService:
        ld a,PROOF_FAIL_SERVICE
        jr Fail
FailParams:
        ld a,PROOF_FAIL_PARAMS
        jr Fail
FailSplash:
        ld a,PROOF_FAIL_SPLASH
Fail:
        ld (PROOF_RESULT),a
        halt
