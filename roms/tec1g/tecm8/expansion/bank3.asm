; TECM8 expansion ROM physical bank 3: RTC tools and diagnostics skeleton.

        .include "bank_ops.asmi"

        .org    0x8000

EXP_BANK          .equ    0x03
EXP_VERSION       .equ    0x01

Tecm8ExpansionBank3Entry:
        cp ABI_PROBE_FARJUMP
        jp z,BankAbiFarJumpTarget
        cp ABI_PROBE_RETURNING_FARJUMP
        jp z,BankAbiReturningFarJumpTarget
        or a
        jp z,rtcServiceEntryImpl
        cp RTC_SVC_TOOL_ENTRY
        jp z,rtcServiceEntryImpl
        cp RTC_SVC_SETUP_UI
        jp z,rtcUnsupportedUi
        cp RTC_SVC_PRAM_VIEWER
        jp z,rtcUnsupportedUi
        ld a,RTC_ERR_UNKNOWN
        scf
        ret

rtcToolEntry:
        jp rtcServiceEntryImpl

rtcSetupUi:
        jp rtcUnsupportedUi

rtcPramViewer:
        jp rtcUnsupportedUi

rtcServiceEntryImpl:
        ld a,EXP_BANK
        ld (DBG_TRACE_3),a
        ld (RTC_PARAM_BANK),a
        ld a,EXP_VERSION
        ld (RTC_PARAM_VERSION),a
        ld a,RTC_FEATURE_SERVICE
        ld (RTC_PARAM_FEATURES),a
        xor a
        ld (RTC_PARAM_STATUS),a
        ld (RTC_PARAM_LAST_ERROR),a
        ld a,0x83
        or a
        ret

rtcUnsupportedUi:
        ld a,RTC_ERR_UNSUPPORTED
        ld (RTC_PARAM_STATUS),a
        ld (RTC_PARAM_LAST_ERROR),a
        scf
        ret

BankAbiFarJumpTarget:
        .rcignore missing_callee_contract "Proof-only far-jump marker lands in the bank ABI harness outside this ROM image."
        jp ABI_FARJUMP_LANDED

BankAbiReturningFarJumpTarget:
        ld a,0xD3
        ld (ABI_TRACE_BASE+16),a
        ret

Tecm8ExpansionBank3Info:
        .db     "T","M","8",EXP_BANK,EXP_VERSION
