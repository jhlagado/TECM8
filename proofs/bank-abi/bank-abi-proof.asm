; TecMate banked ROM ABI proof.
;
; Runs from RAM with the project monitor and expansion ROM loaded. It proves
; that fixed-ROM RST 10h bank services can call and jump through the banked
; 8000h-BFFFh expansion window.

        .org    0x4000

        .include "../../roms/tec1g/tecm8/expansion/bank_ops.asmi"

PROOF_PASS                  .equ    0x42
PROOF_FAIL_FARJUMP_RETURNED .equ    0xE1
PROOF_FAIL_FARJUMP_LOCAL_RET .equ   0xE2

;! out carry,zero
;! clobbers sign,parity,halfCarry,A,B,C,D,E,H,L
@Start:
        ld hl,ABI_TRACE_BASE
        ld b,32
ClearTrace:
        ld (hl),0
        inc hl
        djnz ClearTrace

        ld c,MON_SYS_GET
        rst 10H
        ld (ABI_TRACE_0),a

        callBankService 0x01,VDU_CALL,VDU_SVC_INIT
        ld (ABI_TRACE_1),a

        ld c,MON_SYS_GET
        rst 10H
        ld (ABI_TRACE_2),a

        callService ABI_PROBE_NESTED
        ld (ABI_TRACE_3),a

        ld c,MON_SYS_GET
        rst 10H
        ld (ABI_TRACE_4),a

        ld hl,0
        add hl,sp
        ld a,l
        ld (ABI_TRACE_BASE+24),a
        ld a,h
        ld (ABI_TRACE_BASE+25),a
        ld a,0x5A
        ld de,0xD3E4
        ld hl,0x1234
        ld a,ABI_PROBE_PRESERVE
        ld (ABI_PROBE_REQUEST),a
        ld a,0x5A
        ld de,0xD3E4
        ld hl,0x1234
        farCall 0x01,VDU_ENTRY
        ld (ABI_TRACE_BASE+15),a
        ld hl,0
        add hl,sp
        ld a,l
        ld (ABI_TRACE_BASE+26),a
        ld a,h
        ld (ABI_TRACE_BASE+27),a

        callService VDU_INIT
        ld (ABI_TRACE_BASE+18),a
        callService TFS_MOUNT
        ld (ABI_TRACE_BASE+19),a
        callService RTC_TOOL
        ld (ABI_TRACE_BASE+20),a
        callService GLC_ENTRY
        ld (ABI_TRACE_BASE+22),a
        callService SHL_ENTRY
        ld (ABI_TRACE_BASE+23),a
        ld a,0xA5
        ld b,0xB6
        callService 0x7F
        ld (ABI_TRACE_BASE+21),a

        call ReturningFarJumpProbe
        ld a,0xD4
        ld (ABI_TRACE_BASE+17),a

        ld a,ABI_PROBE_FARJUMP
        farJump 0x03,RTC_ENTRY

        ld a,PROOF_FAIL_FARJUMP_RETURNED
        ld (ABI_TRACE_9),a
        ld (ResultMarker),a
        halt

ReturningFarJumpProbe:
        ld a,ABI_PROBE_RETURNING_FARJUMP
        farJump 0x03,RTC_ENTRY
        ld a,PROOF_FAIL_FARJUMP_LOCAL_RET
        ld (ABI_TRACE_9),a
        ld (ResultMarker),a
        halt

        .org    ABI_FARJUMP_LANDED
@BankAbiFarJumpLanded:
        ld c,MON_SYS_GET
        rst 10H
        ld (ABI_TRACE_5),a
        ld a,PROOF_PASS
        ld (ResultMarker),a
        halt

ResultMarker:
        .db     0
