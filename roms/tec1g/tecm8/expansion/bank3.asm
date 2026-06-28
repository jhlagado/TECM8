; TECM8 expansion ROM physical bank 3: RTC tools and diagnostics skeleton.

        .include "bank_ops.asmi"

        .org    0x8000

TECM8_EXPANSION_BANK          .equ    0x03
TECM8_EXPANSION_VERSION       .equ    0x01

@Tecm8ExpansionBank3Entry:
        cp TECM8_ABI_PROBE_FARJUMP
        jp z,BankAbiFarJumpTarget
        cp TECM8_ABI_PROBE_RETURNING_FARJUMP
        jp z,BankAbiReturningFarJumpTarget
        cp TECM8_RTC_SVC_SETUP_UI
        jp z,rtcUnsupportedUi
        cp TECM8_RTC_SVC_PRAM_VIEWER
        jp z,rtcUnsupportedUi
        jp rtcServiceEntryImpl

@rtcToolEntry:
        jp rtcServiceEntryImpl

@rtcSetupUi:
        jp rtcUnsupportedUi

@rtcPramViewer:
        jp rtcUnsupportedUi

@rtcServiceEntryImpl:
        ld a,TECM8_EXPANSION_BANK
        ld (TECM8_DEMO_TRACE_3),a
        ld (TECM8_RTC_PARAM_BANK),a
        ld a,TECM8_EXPANSION_VERSION
        ld (TECM8_RTC_PARAM_VERSION),a
        ld a,TECM8_RTC_FEATURE_SERVICE
        ld (TECM8_RTC_PARAM_FEATURES),a
        xor a
        ld (TECM8_RTC_PARAM_STATUS),a
        ld (TECM8_RTC_PARAM_LAST_ERROR),a
        ld a,0x83
        or a
        ret

@rtcUnsupportedUi:
        ld a,TECM8_RTC_ERR_UNSUPPORTED
        ld (TECM8_RTC_PARAM_STATUS),a
        ld (TECM8_RTC_PARAM_LAST_ERROR),a
        scf
        ret

@BankAbiFarJumpTarget:
        jp TECM8_ABI_FARJUMP_LANDED

@BankAbiReturningFarJumpTarget:
        ld a,0xD3
        ld (TECM8_ABI_TRACE_BASE+16),a
        ret

@Tecm8ExpansionBank3Info:
        .db     "T","M","8",TECM8_EXPANSION_BANK,TECM8_EXPANSION_VERSION
