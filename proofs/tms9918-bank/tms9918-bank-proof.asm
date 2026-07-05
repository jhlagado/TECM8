; TecMate TMS9918 bank-service proof.
;
; Runs from RAM with the project monitor and expansion ROM loaded. It proves
; the bank-1 display services drive Debug80's TMS9918 ports through the banked
; 8000h-BFFFh expansion window.

        .org    0x4000

        .include "../../roms/tec1g/tecm8/expansion/bank_ops.asmi"

PROOF_PASS                  .equ    0x42
TMS_PROOF_TRACE_BASE        .equ    0x3B10
TMS_PROOF_TRACE_0           .equ    TMS_PROOF_TRACE_BASE+0
TMS_PROOF_TRACE_1           .equ    TMS_PROOF_TRACE_BASE+1
TMS_PROOF_TRACE_2           .equ    TMS_PROOF_TRACE_BASE+2
TMS_PROOF_TRACE_3           .equ    TMS_PROOF_TRACE_BASE+3
TMS_PROOF_TRACE_4           .equ    TMS_PROOF_TRACE_BASE+4
TMS_PROOF_TRACE_5           .equ    TMS_PROOF_TRACE_BASE+5
TMS_PROOF_TRACE_6           .equ    TMS_PROOF_TRACE_BASE+6
TMS_PROOF_TRACE_7           .equ    TMS_PROOF_TRACE_BASE+7
TMS_PROOF_TRACE_8           .equ    TMS_PROOF_TRACE_BASE+8
TMS_PROOF_TRACE_9           .equ    TMS_PROOF_TRACE_BASE+9
TMS_PROOF_TRACE_10          .equ    TMS_PROOF_TRACE_BASE+10
TMS_PROOF_TRACE_11          .equ    TMS_PROOF_TRACE_BASE+11
TMS_PROOF_TRACE_12          .equ    TMS_PROOF_TRACE_BASE+12
TMS_PROOF_TRACE_13          .equ    TMS_PROOF_TRACE_BASE+13
TMS_PROOF_TRACE_14          .equ    TMS_PROOF_TRACE_BASE+14
TMS_PROOF_TRACE_15          .equ    TMS_PROOF_TRACE_BASE+15
TMS_PROOF_TRACE_16          .equ    TMS_PROOF_TRACE_BASE+16
TMS_PROOF_TRACE_17          .equ    TMS_PROOF_TRACE_BASE+17
TMS_PROOF_TRACE_18          .equ    TMS_PROOF_TRACE_BASE+18
TMS_PROOF_TRACE_19          .equ    TMS_PROOF_TRACE_BASE+19
TMS_PROOF_TRACE_20          .equ    TMS_PROOF_TRACE_BASE+20
TMS_PROOF_TRACE_21          .equ    TMS_PROOF_TRACE_BASE+21
TMS_PROOF_TRACE_22          .equ    TMS_PROOF_TRACE_BASE+22
TMS_PROOF_TRACE_23          .equ    TMS_PROOF_TRACE_BASE+23
TMS_PROOF_TRACE_24          .equ    TMS_PROOF_TRACE_BASE+24
TMS_PROOF_TRACE_25          .equ    TMS_PROOF_TRACE_BASE+25
TMS_PROOF_RESULT            .equ    0x3B30

;! out carry,zero
;! clobbers sign,parity,halfCarry,A,B,C,D,E,H,L
@Start:
        ld hl,TMS_PROOF_TRACE_BASE
        ld b,26
ClearTrace:
        ld (hl),0
        inc hl
        djnz ClearTrace

        ld c,MON_SYS_GET
        rst 10H
        ld (TMS_PROOF_TRACE_0),a

        callBankService 0x01,VDU_CALL,VDU_SVC_INIT
        ld (TMS_PROOF_TRACE_1),a

        callBankService 0x01,VDU_CALL,VDU_SVC_CLEAR
        ld (TMS_PROOF_TRACE_8),a

        ld a,0x02
        ld (TMS_PARAM_ROW),a
        ld a,0x03
        ld (TMS_PARAM_COL),a
        callBankService 0x01,VDU_CALL,VDU_SVC_SET_ROWCOL
        ld (TMS_PROOF_TRACE_9),a
        ld a,(TMS_PARAM_CURSOR_LO)
        ld (TMS_PROOF_TRACE_11),a
        ld a,(TMS_PARAM_CURSOR_HI)
        ld (TMS_PROOF_TRACE_12),a

        ld a,0x20
        ld (TMS_PARAM_ADDR_LO),a
        xor a
        ld (TMS_PARAM_ADDR_HI),a
        ld a,0x53
        ld (TMS_PARAM_VALUE),a
        callBankService 0x01,VDU_CALL,TMS_SVC_WRITE_VRAM
        callBankService 0x01,VDU_CALL,VDU_SVC_SCROLL_UP
        ld (TMS_PROOF_TRACE_10),a

        ld c,MON_SYS_GET
        rst 10H
        ld (TMS_PROOF_TRACE_2),a

        ld a,0x07
        ld (TMS_PARAM_REGISTER),a
        ld a,0xF4
        ld (TMS_PARAM_VALUE),a
        callBankService 0x01,VDU_CALL,TMS_SVC_SET_REGISTER

        ld a,0x23
        ld (TMS_PARAM_ADDR_LO),a
        ld a,0x01
        ld (TMS_PARAM_ADDR_HI),a
        ld a,0x5A
        ld (TMS_PARAM_VALUE),a
        callBankService 0x01,VDU_CALL,TMS_SVC_WRITE_VRAM

        ld a,0x24
        ld (TMS_PARAM_ADDR_LO),a
        ld a,0x01
        ld (TMS_PARAM_ADDR_HI),a
        callBankService 0x01,VDU_CALL,VDU_SVC_SET_CURSOR
        ld (TMS_PROOF_TRACE_4),a

        ld a,0x42
        ld (TMS_PARAM_VALUE),a
        callBankService 0x01,VDU_CALL,VDU_SVC_PUT_CHAR
        ld (TMS_PROOF_TRACE_5),a

        ld hl,TmsProofString
        ld (TMS_PARAM_STRING_LO),hl
        ld hl,0x0001
        ld (TMS_PARAM_COUNT_LO),hl
        callBankService 0x01,VDU_CALL,VDU_SVC_PUT_STRING
        ld (TMS_PROOF_TRACE_6),a

        ld a,0x30
        ld (TMS_PARAM_ADDR_LO),a
        ld a,0x01
        ld (TMS_PARAM_ADDR_HI),a
        callBankService 0x01,VDU_CALL,VDU_SVC_SET_CURSOR
        ld hl,TmsProofCountedString
        ld (TMS_PARAM_STRING_LO),hl
        ld hl,0x0003
        ld (TMS_PARAM_COUNT_LO),hl
        callBankService 0x01,VDU_CALL,VDU_SVC_PUT_STRING_N
        ld (TMS_PROOF_TRACE_24),a

        ld a,0x40
        ld (TMS_PARAM_ADDR_LO),a
        ld a,0x01
        ld (TMS_PARAM_ADDR_HI),a
        callBankService 0x01,VDU_CALL,VDU_SVC_SET_CURSOR
        ld hl,TmsProofBoundedZeroString
        ld (TMS_PARAM_STRING_LO),hl
        ld hl,0x0005
        ld (TMS_PARAM_COUNT_LO),hl
        callBankService 0x01,VDU_CALL,VDU_SVC_PUT_STRING_N
        ld (TMS_PROOF_TRACE_25),a

        callBankService 0x01,VDU_CALL,VDU_SVC_NEWLINE
        ld (TMS_PROOF_TRACE_7),a

        callBankService 0x01,VDU_CALL,0x00
        ld (TMS_PROOF_TRACE_16),a
        ld a,0
        adc a,0
        ld (TMS_PROOF_TRACE_17),a

        callBankService 0x01,VDU_CALL,0x0B
        ld (TMS_PROOF_TRACE_18),a
        ld a,0
        adc a,0
        ld (TMS_PROOF_TRACE_19),a

        callBankService 0x01,VDU_CALL,0x7F
        ld (TMS_PROOF_TRACE_20),a
        ld a,0
        adc a,0
        ld (TMS_PROOF_TRACE_21),a
        ld a,(TMS_PARAM_CURSOR_LO)
        ld (TMS_PROOF_TRACE_22),a
        ld a,(TMS_PARAM_CURSOR_HI)
        ld (TMS_PROOF_TRACE_23),a

        ld hl,TmsStatusString
        ld (TMS_PARAM_STRING_LO),hl
        callBankService 0x01,VDU_CALL,VDU_SVC_STATUS_LINE
        ld (TMS_PROOF_TRACE_13),a
        ld a,(TMS_PARAM_CURSOR_LO)
        ld (TMS_PROOF_TRACE_14),a
        ld a,(TMS_PARAM_CURSOR_HI)
        ld (TMS_PROOF_TRACE_15),a

        ld c,MON_SYS_GET
        rst 10H
        ld (TMS_PROOF_TRACE_3),a

        ld a,PROOF_PASS
        ld (TMS_PROOF_RESULT),a
        halt

TmsProofString:
        .db     "O","K",0
TmsProofCountedString:
        .db     "A","B","C","D","E","F"
TmsProofBoundedZeroString:
        .db     "X","Y",0,"Z","Z"
TmsStatusString:
        .db     "R","D","Y",0
