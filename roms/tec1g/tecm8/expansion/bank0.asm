; TECM8 expansion ROM physical bank 0.
;
; Bank sources are assembled independently for the visible TEC-1G expansion
; window at 0x8000-0xBFFF, then packed into the 144K expansion image.

        .include "bank_ops.asmi"

        .org    0x8000

TECM8_EXPANSION_BANK          .equ    0x00
TECM8_EXPANSION_VERSION       .equ    0x01

@Tecm8ExpansionBank0Entry:
        ld a,TECM8_EXPANSION_BANK
        ld (TECM8_DEMO_TRACE_0),a
        farCall 0x01,TECM8_VDU_INIT
        ld (TECM8_DEMO_TRACE_4),a
        farCall 0x02,TECM8_TECFS_MOUNT
        ld (TECM8_DEMO_TRACE_5),a
        farCall 0x03,TECM8_RTC_TOOL_ENTRY
        ld (TECM8_DEMO_TRACE_6),a
        ret

        .org    0x8100
@Tecm8ExpansionBank0Info:
        .db     "T","M","8",TECM8_EXPANSION_BANK,TECM8_EXPANSION_VERSION
