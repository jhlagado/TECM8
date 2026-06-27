; TECM8 expansion ROM physical bank 1: VDU/TMS9918 services.

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
        call tmsInit
        ld a,0x81
        ret

        .org    0x8020
@vduClear:
        xor a
        ld (TECM8_TMS_PARAM_ADDR_LO),a
        ld (TECM8_TMS_PARAM_ADDR_HI),a
        ld (TECM8_TMS_PARAM_VALUE),a
        jp tmsWriteVram

        .org    0x8030
@vduSetCursor:
        ret

        .org    0x8040
@vduPutChar:
        xor a
        ld (TECM8_TMS_PARAM_ADDR_LO),a
        ld (TECM8_TMS_PARAM_ADDR_HI),a
        jp tmsWriteVram

        .org    0x8080
@tmsInit:
        ld a,0x07
        ld (TECM8_TMS_PARAM_REGISTER),a
        ld a,0xF1
        ld (TECM8_TMS_PARAM_VALUE),a
        call tmsSetRegister
        ld a,0x81
        ret

        .org    0x8090
; Input: TECM8_TMS_PARAM_REGISTER = TMS register 0-7,
;        TECM8_TMS_PARAM_VALUE = value.
@tmsSetRegister:
        ld a,(TECM8_TMS_PARAM_VALUE)
        out (TECM8_TMS_CONTROL_PORT),a
        ld a,(TECM8_TMS_PARAM_REGISTER)
        and 0x07
        or 0x80
        out (TECM8_TMS_CONTROL_PORT),a
        ret

        .org    0x80A0
; Input: TECM8_TMS_PARAM_ADDR_LO/HI = VRAM address,
;        TECM8_TMS_PARAM_VALUE = byte value.
@tmsWriteVram:
        ld a,(TECM8_TMS_PARAM_ADDR_LO)
        out (TECM8_TMS_CONTROL_PORT),a
        ld a,(TECM8_TMS_PARAM_ADDR_HI)
        and 0x3F
        or 0x40
        out (TECM8_TMS_CONTROL_PORT),a
        ld a,(TECM8_TMS_PARAM_VALUE)
        out (TECM8_TMS_DATA_PORT),a
        ret

        .org    0x80C0
@BankAbiNestedCall:
        ld a,0xA1
        ld (TECM8_ABI_TRACE_6),a
        farCall 0x02,TECM8_ABI_BANK2_NESTED
        ld (TECM8_ABI_TRACE_7),a
        ld a,0x91
        ret

        .org    TECM8_ABI_BANK1_PRESERVE
@BankAbiPreserveProbe:
        ld (TECM8_ABI_TRACE_BASE+10),a
        ld a,d
        ld (TECM8_ABI_TRACE_BASE+11),a
        ld a,e
        ld (TECM8_ABI_TRACE_BASE+12),a
        ld a,h
        ld (TECM8_ABI_TRACE_BASE+13),a
        ld a,l
        ld (TECM8_ABI_TRACE_BASE+14),a
        ld a,0xC1
        ret

        .org    0x8100
@Tecm8ExpansionBank1Info:
        .db     "T","M","8",TECM8_EXPANSION_BANK,TECM8_EXPANSION_VERSION
