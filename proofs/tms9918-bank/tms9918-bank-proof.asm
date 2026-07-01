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
TMS_PROOF_RESULT            .equ    0x3B20

;! out carry,zero
;! clobbers sign,parity,halfCarry,A,B,C,D,E,H,L
@Start:
        ld hl,TMS_PROOF_TRACE_BASE
        ld b,16
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
        callBankService 0x01,VDU_CALL,VDU_SVC_PUT_STRING
        ld (TMS_PROOF_TRACE_6),a

        callBankService 0x01,VDU_CALL,VDU_SVC_NEWLINE
        ld (TMS_PROOF_TRACE_7),a

        ld c,MON_SYS_GET
        rst 10H
        ld (TMS_PROOF_TRACE_3),a

        ld a,PROOF_PASS
        ld (TMS_PROOF_RESULT),a
        halt

TmsProofString:
        .db     "O","K",0
