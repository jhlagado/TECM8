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
        ld b,64
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
        ld a,(SHL_STATUS_BUFFER)
        ld (ABI_TRACE_BASE+62),a
        ld a,(SHL_STATUS_BUFFER+1)
        ld (ABI_TRACE_BASE+63),a
        ld a,"a"
        ld (SHL_COMMAND_BUFFER),a
        ld a,"s"
        ld (SHL_COMMAND_BUFFER+1),a
        ld a,"m"
        ld (SHL_COMMAND_BUFFER+2),a
        xor a
        ld (SHL_COMMAND_BUFFER+3),a
        ld a,0xD1
        ld (SHL_PARAM_COMMAND_TARGET_LO),a
        ld a,0xD2
        ld (SHL_PARAM_COMMAND_TARGET_HI),a
        ld a,0xD3
        ld (SHL_PARAM_COMMAND_RESULT_LO),a
        ld a,0xD4
        ld (SHL_PARAM_COMMAND_RESULT_HI),a
        callService SHL_RUN_COMMAND
        ld (ABI_TRACE_BASE+30),a
        ld a,(SHL_PARAM_COMMAND_ACTION)
        ld (ABI_TRACE_BASE+31),a
        ld a,(SHL_PARAM_COMMAND_LENGTH)
        ld (ABI_TRACE_BASE+32),a
        ld a,(SHL_PARAM_COMMAND_TARGET_LO)
        ld (ABI_TRACE_BASE+35),a
        ld a,(SHL_PARAM_COMMAND_TARGET_HI)
        ld (ABI_TRACE_BASE+36),a
        ld a,(SHL_PARAM_COMMAND_RESULT_LO)
        ld (ABI_TRACE_BASE+37),a
        ld a,(SHL_PARAM_COMMAND_RESULT_HI)
        ld (ABI_TRACE_BASE+38),a
        ld a,(SHL_TARGET_ACTION)
        ld (ABI_TRACE_BASE+42),a
        ld a,(SHL_TARGET_KIND)
        ld (ABI_TRACE_BASE+43),a
        ld a,(SHL_TARGET_FLAGS)
        ld (ABI_TRACE_BASE+44),a
        ld a,(SHL_TARGET_PATH_LO)
        ld (ABI_TRACE_BASE+45),a
        ld a,(SHL_TARGET_PATH_HI)
        ld (ABI_TRACE_BASE+46),a

        ld a,"e"
        ld (SHL_COMMAND_BUFFER),a
        ld a,"d"
        ld (SHL_COMMAND_BUFFER+1),a
        ld a,"i"
        ld (SHL_COMMAND_BUFFER+2),a
        ld a,"t"
        ld (SHL_COMMAND_BUFFER+3),a
        xor a
        ld (SHL_COMMAND_BUFFER+4),a
        callService SHL_RUN_COMMAND
        ld (ABI_TRACE_BASE+47),a
        ld a,(SHL_PARAM_COMMAND_ACTION)
        ld (ABI_TRACE_BASE+48),a
        ld a,(SHL_PARAM_COMMAND_RESULT_LO)
        ld (ABI_TRACE_BASE+49),a
        ld a,(SHL_PARAM_COMMAND_RESULT_HI)
        ld (ABI_TRACE_BASE+50),a

        ld a,"r"
        ld (SHL_COMMAND_BUFFER),a
        ld a,"u"
        ld (SHL_COMMAND_BUFFER+1),a
        ld a,"n"
        ld (SHL_COMMAND_BUFFER+2),a
        xor a
        ld (SHL_COMMAND_BUFFER+3),a
        callService SHL_RUN_COMMAND
        ld (ABI_TRACE_BASE+51),a
        ld a,(SHL_PARAM_COMMAND_ACTION)
        ld (ABI_TRACE_BASE+52),a
        ld a,(SHL_TARGET_KIND)
        ld (ABI_TRACE_BASE+53),a
        ld a,(SHL_TARGET_FLAGS)
        ld (ABI_TRACE_BASE+54),a
        ld a,"g"
        ld (SHL_COMMAND_BUFFER),a
        ld a,"a"
        ld (SHL_COMMAND_BUFFER+1),a
        ld a,"m"
        ld (SHL_COMMAND_BUFFER+2),a
        ld a,"e"
        ld (SHL_COMMAND_BUFFER+3),a
        xor a
        ld (SHL_COMMAND_BUFFER+4),a
        callService SHL_RUN_COMMAND
        ld (ABI_TRACE_BASE+33),a
        ld a,(SHL_PARAM_STATUS)
        ld (ABI_TRACE_BASE+34),a
        ld a,(SHL_PARAM_COMMAND_TARGET_LO)
        ld (ABI_TRACE_BASE+55),a
        ld a,(SHL_PARAM_COMMAND_TARGET_HI)
        ld (ABI_TRACE_BASE+56),a
        ld a,(SHL_TARGET_ACTION)
        ld (ABI_TRACE_BASE+57),a
        ld a,(SHL_TARGET_KIND)
        ld (ABI_TRACE_BASE+58),a
        ld a,(SHL_TARGET_FLAGS)
        ld (ABI_TRACE_BASE+59),a
        ld a,(SHL_PARAM_COMMAND_RESULT_LO)
        ld (ABI_TRACE_BASE+60),a
        ld a,(SHL_PARAM_COMMAND_RESULT_HI)
        ld (ABI_TRACE_BASE+61),a
        callService INP_READ
        ld (ABI_TRACE_BASE+39),a
        ld a,(INP_PARAM_JOYSTICK)
        ld (ABI_TRACE_BASE+40),a
        ld a,(INP_PARAM_BANK)
        ld (ABI_TRACE_BASE+41),a
        ld a,0xA5
        ld b,0xB6
        callService 0x7F
        ld (ABI_TRACE_BASE+21),a
        jp nc,BankAbiFarJumpReturnedFail

        call ReturningFarJumpProbe
        ld a,0xD4
        ld (ABI_TRACE_BASE+17),a

        ld a,ABI_PROBE_FARJUMP
        farJump 0x03,RTC_ENTRY

BankAbiFarJumpReturnedFail:
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
