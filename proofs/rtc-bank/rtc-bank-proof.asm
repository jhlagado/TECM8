; TecMate RTC bank-service proof.
;
; Runs from RAM with the project monitor and expansion ROM loaded. It proves
; bank-3 exposes a BIOS-style RTC service boundary while UI tools fail
; explicitly until they are relocated or rewritten.

        .org    0x4000

        .include "../../roms/tec1g/tecm8/expansion/bank_ops.asmi"

PROOF_PASS                  .equ    0x42
PROOF_FAIL_ENTRY            .equ    0xE0
PROOF_FAIL_TOOL             .equ    0xE1
PROOF_FAIL_SETUP_UI         .equ    0xE2
PROOF_FAIL_PRAM_VIEWER      .equ    0xE3
RTC_PROOF_RESULT            .equ    0x3BB0

;! out carry,zero
;! clobbers sign,parity,halfCarry,A,B,C,D,E,H,L
@Start:
        ld hl,TECM8_RTC_PARAM_BASE
        ld b,16
ClearParams:
        ld (hl),0
        inc hl
        djnz ClearParams

        farCall 0x03,TECM8_RTC_ENTRY
        jp c,FailEntry
        cp 0x83
        jp nz,FailEntry
        ld a,(TECM8_RTC_PARAM_STATUS)
        cp TECM8_RTC_STATUS_OK
        jp nz,FailEntry
        ld a,(TECM8_RTC_PARAM_BANK)
        cp 0x03
        jp nz,FailEntry
        ld a,(TECM8_RTC_PARAM_VERSION)
        cp 0x01
        jp nz,FailEntry
        ld a,(TECM8_RTC_PARAM_FEATURES)
        cp TECM8_RTC_FEATURE_SERVICE
        jp nz,FailEntry

        farCall 0x03,TECM8_RTC_TOOL_ENTRY
        jr c,FailTool
        cp 0x83
        jr nz,FailTool

        farCall 0x03,TECM8_RTC_SETUP_UI
        jr nc,FailSetupUi
        cp TECM8_RTC_ERR_UNSUPPORTED
        jr nz,FailSetupUi
        ld a,(TECM8_RTC_PARAM_STATUS)
        cp TECM8_RTC_ERR_UNSUPPORTED
        jr nz,FailSetupUi
        ld a,(TECM8_RTC_PARAM_LAST_ERROR)
        cp TECM8_RTC_ERR_UNSUPPORTED
        jr nz,FailSetupUi

        farCall 0x03,TECM8_RTC_PRAM_VIEWER
        jr nc,FailPramViewer
        cp TECM8_RTC_ERR_UNSUPPORTED
        jr nz,FailPramViewer
        ld a,(TECM8_RTC_PARAM_STATUS)
        cp TECM8_RTC_ERR_UNSUPPORTED
        jr nz,FailPramViewer
        ld a,(TECM8_RTC_PARAM_LAST_ERROR)
        cp TECM8_RTC_ERR_UNSUPPORTED
        jr nz,FailPramViewer

        ld a,PROOF_PASS
        ld (RTC_PROOF_RESULT),a
        halt

FailEntry:
        ld a,PROOF_FAIL_ENTRY
        jr Fail
FailTool:
        ld a,PROOF_FAIL_TOOL
        jr Fail
FailSetupUi:
        ld a,PROOF_FAIL_SETUP_UI
        jr Fail
FailPramViewer:
        ld a,PROOF_FAIL_PRAM_VIEWER
Fail:
        ld (RTC_PROOF_RESULT),a
        halt
