; TECM8 expansion ROM physical bank 3: RTC tools and diagnostics skeleton.

        .include "bank_ops.asmi"

        .org    0x8000

TECM8_EXPANSION_BANK          .equ    0x03
TECM8_EXPANSION_VERSION       .equ    0x01

@Tecm8ExpansionBank3Entry:
        ld a,TECM8_EXPANSION_BANK
        ld (TECM8_DEMO_TRACE_3),a
        ld a,0x83
        ret

        .org    0x8010
@rtcToolEntry:
        ld a,0x83
        ret

        .org    0x8020
@rtcSetupUi:
        ret

        .org    0x8030
@rtcPramViewer:
        ret

        .org    0x8100
@Tecm8ExpansionBank3Info:
        .db     "T","M","8",TECM8_EXPANSION_BANK,TECM8_EXPANSION_VERSION
