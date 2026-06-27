; TECM8 expansion ROM physical bank 1: VDU/TMS9918 service skeleton.

        .include "bank_ops.asmi"

        .org    0x8000

TECM8_EXPANSION_BANK          .equ    0x01
TECM8_EXPANSION_VERSION       .equ    0x01

@Tecm8ExpansionBank1Entry:
        ld a,TECM8_EXPANSION_BANK
        ld (TECM8_DEMO_TRACE_1),a
        ret

        .org    0x8010
@vduInit:
        ld a,0x81
        ret

        .org    0x8020
@vduClear:
        ret

        .org    0x8030
@vduSetCursor:
        ret

        .org    0x8040
@vduPutChar:
        ret

        .org    0x8080
@tmsInit:
        ret

        .org    0x8090
@tmsSetRegister:
        ret

        .org    0x80A0
@tmsWriteVram:
        ret

        .org    0x80C0
@BankAbiNestedCall:
        ld a,0xA1
        ld (TECM8_ABI_TRACE_6),a
        farCall 0x02,TECM8_ABI_BANK2_NESTED
        ld (TECM8_ABI_TRACE_7),a
        ld a,0x91
        ret

        .org    0x8100
@Tecm8ExpansionBank1Info:
        .db     "T","M","8",TECM8_EXPANSION_BANK,TECM8_EXPANSION_VERSION
