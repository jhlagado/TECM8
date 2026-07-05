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
PROOF_FAIL_UNKNOWN_SELECTOR .equ    0xE4
RTC_PROOF_RESULT            .equ    0x3BB0

;! out carry,zero
;! clobbers sign,parity,halfCarry,A,B,C,D,E,H,L
@Start:
        ld hl,RTC_PARAM_BASE
        ld b,16
ClearParams:
        ld (hl),0
        inc hl
        djnz ClearParams

        xor a
        farCall 0x03,RTC_ENTRY
        jp c,FailEntry
        cp 0x83
        jp nz,FailEntry
        ld a,(RTC_PARAM_STATUS)
        cp RTC_STATUS_OK
        jp nz,FailEntry
        ld a,(RTC_PARAM_BANK)
        cp 0x03
        jp nz,FailEntry
        ld a,(RTC_PARAM_VERSION)
        cp 0x01
        jp nz,FailEntry
        ld a,(RTC_PARAM_FEATURES)
        cp RTC_FEATURE_SERVICE
        jp nz,FailEntry

        ld a,RTC_SVC_TOOL_ENTRY
        farCall 0x03,RTC_ENTRY
        jr c,FailTool
        cp 0x83
        jr nz,FailTool

        ld a,RTC_SVC_SETUP_UI
        farCall 0x03,RTC_ENTRY
        jr nc,FailSetupUi
        cp RTC_ERR_UNSUPPORTED
        jr nz,FailSetupUi
        ld a,(RTC_PARAM_STATUS)
        cp RTC_ERR_UNSUPPORTED
        jr nz,FailSetupUi
        ld a,(RTC_PARAM_LAST_ERROR)
        cp RTC_ERR_UNSUPPORTED
        jr nz,FailSetupUi

        ld a,RTC_SVC_PRAM_VIEWER
        farCall 0x03,RTC_ENTRY
        jr nc,FailPramViewer
        cp RTC_ERR_UNSUPPORTED
        jr nz,FailPramViewer
        ld a,(RTC_PARAM_STATUS)
        cp RTC_ERR_UNSUPPORTED
        jr nz,FailPramViewer
        ld a,(RTC_PARAM_LAST_ERROR)
        cp RTC_ERR_UNSUPPORTED
        jr nz,FailPramViewer

        ld a,0x5A
        ld (RTC_PARAM_STATUS),a
        ld a,0xA5
        ld (RTC_PARAM_LAST_ERROR),a
        ld a,0x7F
        farCall 0x03,RTC_ENTRY
        jr nc,FailUnknownSelector
        cp RTC_ERR_UNKNOWN
        jr nz,FailUnknownSelector
        ld a,(RTC_PARAM_STATUS)
        cp 0x5A
        jr nz,FailUnknownSelector
        ld a,(RTC_PARAM_LAST_ERROR)
        cp 0xA5
        jr nz,FailUnknownSelector

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
        jr Fail
FailUnknownSelector:
        ld a,PROOF_FAIL_UNKNOWN_SELECTOR
Fail:
        ld (RTC_PROOF_RESULT),a
        halt
