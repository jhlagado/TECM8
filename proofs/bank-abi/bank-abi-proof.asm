; TecMate banked ROM ABI proof.
;
; Runs from RAM with the project monitor and expansion ROM loaded. It proves
; that fixed-ROM RST 10h bank services can call and jump through the banked
; 8000h-BFFFh expansion window.

        .org    0x4000

        .include "../../roms/tec1g/tecm8/expansion/bank_ops.asmi"

PROOF_PASS                  .equ    0x42
PROOF_FAIL_FARJUMP_RETURNED .equ    0xE1

;! out carry,zero
;! clobbers sign,parity,halfCarry,A,B,C,D,E,H,L
@Start:
        ld hl,TECM8_ABI_TRACE_BASE
        ld b,16
ClearTrace:
        ld (hl),0
        inc hl
        djnz ClearTrace

        ld c,TECM8_BIOS_SYS_GET
        rst 10H
        ld (TECM8_ABI_TRACE_0),a

        ld a,0x01
        ld hl,TECM8_VDU_INIT
        ld c,TECM8_BIOS_BANK_CALL
        rst 10H
        ld (TECM8_ABI_TRACE_1),a

        ld c,TECM8_BIOS_SYS_GET
        rst 10H
        ld (TECM8_ABI_TRACE_2),a

        ld a,0x01
        ld hl,TECM8_ABI_BANK1_NESTED
        ld c,TECM8_BIOS_BANK_CALL
        rst 10H
        ld (TECM8_ABI_TRACE_3),a

        ld c,TECM8_BIOS_SYS_GET
        rst 10H
        ld (TECM8_ABI_TRACE_4),a

        ld a,0x03
        ld hl,TECM8_ABI_BANK3_FARJUMP
        ld c,TECM8_BIOS_FAR_JUMP
        rst 10H

        ld a,PROOF_FAIL_FARJUMP_RETURNED
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
