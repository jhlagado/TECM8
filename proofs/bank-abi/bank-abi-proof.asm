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
        ld hl,TECM8_ABI_TRACE_BASE
        ld b,22
ClearTrace:
        ld (hl),0
        inc hl
        djnz ClearTrace

        ld c,TECM8_BIOS_SYS_GET
        rst 10H
        ld (TECM8_ABI_TRACE_0),a

        farCall 0x01,TECM8_VDU_INIT
        ld (TECM8_ABI_TRACE_1),a

        ld c,TECM8_BIOS_SYS_GET
        rst 10H
        ld (TECM8_ABI_TRACE_2),a

        farCall 0x01,TECM8_ABI_BANK1_NESTED
        ld (TECM8_ABI_TRACE_3),a

        ld c,TECM8_BIOS_SYS_GET
        rst 10H
        ld (TECM8_ABI_TRACE_4),a

        ld a,0x5A
        ld de,0xD3E4
        ld hl,0x1234
        farCall 0x01,TECM8_ABI_BANK1_PRESERVE
        ld (TECM8_ABI_TRACE_BASE+15),a

        callService TECM8_SERVICE_VDU_INIT
        ld (TECM8_ABI_TRACE_BASE+18),a
        callService TECM8_SERVICE_TECFS_MOUNT
        ld (TECM8_ABI_TRACE_BASE+19),a
        callService TECM8_SERVICE_RTC_TOOL
        ld (TECM8_ABI_TRACE_BASE+20),a
        callService 0x7F
        ld (TECM8_ABI_TRACE_BASE+21),a

        call ReturningFarJumpProbe
        ld a,0xD4
        ld (TECM8_ABI_TRACE_BASE+17),a

        farJump 0x03,TECM8_ABI_BANK3_FARJUMP

        ld a,PROOF_FAIL_FARJUMP_RETURNED
        ld (TECM8_ABI_TRACE_9),a
        ld (ResultMarker),a
        halt

ReturningFarJumpProbe:
        farJump 0x03,TECM8_ABI_BANK3_RETURNING_FARJUMP
        ld a,PROOF_FAIL_FARJUMP_LOCAL_RET
        ld (TECM8_ABI_TRACE_9),a
        ld (ResultMarker),a
        halt

        .org    0x4100
@BankAbiFarJumpLanded:
        ld c,TECM8_BIOS_SYS_GET
        rst 10H
        ld (TECM8_ABI_TRACE_5),a
        ld a,PROOF_PASS
        ld (ResultMarker),a
        halt

ResultMarker:
        .db     0
