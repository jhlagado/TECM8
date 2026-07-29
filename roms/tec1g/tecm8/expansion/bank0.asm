; TECM8 expansion ROM physical bank 0.
;
; Bank sources are assembled independently for the visible TEC-1G expansion
; window at 0x8000-0xBFFF, then packed into the 144K expansion image.

        .include "bank_ops.asmi"

        .org    0x8000

EXP_BANK          .equ    0x00
EXP_VERSION       .equ    0x01

Tecm8ExpansionHeader:
        .db     EXP_MAGIC_0,EXP_MAGIC_1
        .db     EXP_MAGIC_2,EXP_MAGIC_3
        .db     EXP_HEADER_VERSION
        .db     EXP_BANK
        .db     EXP_TYPE_SUPERVISOR
        .db     0x00
        .dw     Tecm8ExpansionInstall
        .db     0x00

Tecm8ExpansionInstall:
        ld a,EXP_BANK
        ld (EXP_MENU_VEC_BANK),a
        ld hl,Tecm8ExpansionBank0Entry
        ld (EXP_MENU_VEC_ADDR),hl
        xor a
        ld (EXP_MENU_VEC_FLAGS),a
        ld a,EXP_BANK
        ld (EXP_SVC_VEC_BANK),a
        ld hl,Tecm8ServiceCall
        ld (EXP_SVC_VEC_ADDR),hl
        xor a
        ld (EXP_SVC_VEC_FLAGS),a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
Tecm8ExpansionBank0Entry:
        ld a,EXP_BANK
        ld (DBG_TRACE_0),a
        call Tecm8BootstrapVdu
        call Tecm8BootstrapTecfs
        call Tecm8BootstrapInput
        call Tecm8BootstrapShell
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
Tecm8BootstrapVdu:
        .expectout A
        callService VDU_INIT
        ld (DBG_TRACE_4),a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
Tecm8BootstrapTecfs:
        .expectout A
        callService TFS_MOUNT
        ld (DBG_TRACE_5),a
        ret c
        ld a,TFS_BRIDGE_BANK
        ld (TFS_PARAM_DRIVER_BANK),a
        ld hl,TFS_MON3_FILE_DRIVER
        ld (TFS_PARAM_DRIVER_ADDR_LO),hl
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
Tecm8BootstrapInput:
        .expectout A
        callService INP_READ
        ld (DBG_TRACE_7),a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
Tecm8BootstrapShell:
        .expectout A
        callService RTC_TOOL
        ld (DBG_TRACE_6),a
        .expectout A
        callService SHL_ENTRY
        ld (DBG_TRACE_8),a
        ret

Tecm8ServiceCall:
        push hl
        push de
        push af
        ld ix,0
        add ix,sp
        ld a,(ix+1)
        ld (ABI_TRACE_BASE+28),a
        ld a,b
        ld (ABI_TRACE_BASE+29),a
        ld hl,Tecm8ServiceRegistry
Tecm8ServiceCallFind:
        ld a,(hl)
        or a
        jp z,Tecm8ServiceCallUnknown
        cp c
        jp z,Tecm8ServiceCallFound
        ld de,SVC_REG_ENTRY_SIZE
        add hl,de
        jp Tecm8ServiceCallFind

Tecm8ServiceCallFound:
        inc hl
        ld b,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        ld (ix+1),a
        ld h,d
        ld l,e
        ld c,MON_BANK_CALL
        rst 10H
        ret

Tecm8ServiceCallUnknown:
        pop af
        pop de
        pop hl
        ld a,SVC_ERR_UNKNOWN
        scf
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
Tecm8ShellEntry:
        ld a,EXP_BANK
        ld (SHL_PARAM_BANK),a
        ld a,EXP_VERSION
        ld (SHL_PARAM_VERSION),a
        ld a,SHL_FEATURE_ENTRY+SHL_FEATURE_SPLASH+SHL_FEATURE_COMMAND_LOOP
        ld (SHL_PARAM_FEATURES),a
        call Tecm8ShellClearCommandState
        call Tecm8ShellCopySplash
        call Tecm8ShellRenderHome
        jp c,Tecm8ShellSplashError
        call Tecm8ShellLoopStep
        ld a,0x80
        or a
        ret
Tecm8ShellSplashError:
        ld (SHL_PARAM_LAST_ERROR),a
        ld (SHL_PARAM_STATUS),a
        scf
        ret

.routine out A,zero clobbers sign,parity,halfCarry
Tecm8ShellClearCommandState:
        xor a
        ld (SHL_PARAM_STATUS),a
        ld (SHL_PARAM_LAST_ERROR),a
        ld (SHL_PARAM_COMMAND_ACTION),a
        ld (SHL_PARAM_COMMAND_LENGTH),a
        ld (SHL_PARAM_COMMAND_TARGET_LO),a
        ld (SHL_PARAM_COMMAND_TARGET_HI),a
        ld (SHL_PARAM_COMMAND_RESULT_LO),a
        ld (SHL_PARAM_COMMAND_RESULT_HI),a
        ld (SHL_TARGET_ACTION),a
        ld (SHL_TARGET_KIND),a
        ld (SHL_TARGET_PATH_LO),a
        ld (SHL_TARGET_PATH_HI),a
        ld (SHL_TARGET_FLAGS),a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
Tecm8ShellRunCommand:
        call Tecm8ShellClearCommandState
        ld hl,SHL_COMMAND_BUFFER
        ld a,(hl)
        or a
        jp z,Tecm8ShellRunNoop
        push hl
        push de
        call Tecm8ShellCommandLength
        pop de
        pop hl
        ld b,SHL_TARGET_KIND_NONE
        ld a,(SHL_PARAM_COMMAND_LENGTH)
        cp 0x03
        jp z,Tecm8ShellRunCheckThree
        cp 0x04
        jp z,Tecm8ShellRunCheckFour
        cp 0x05
        jp z,Tecm8ShellRunCheckFive
        jp nc,Tecm8ShellRunCheckPathCommand
        jp Tecm8ShellRunUnknown

Tecm8ShellRunCheckThree:
        ld a,(SHL_COMMAND_BUFFER)
        and 0xDF
        cp "A"
        jp z,Tecm8ShellRunCheckAsm
        cp "D"
        jp z,Tecm8ShellRunCheckDir
        cp "R"
        jp z,Tecm8ShellRunCheckRun
        cp "S"
        jp z,Tecm8ShellRunCheckSym
        jp Tecm8ShellRunUnknown
Tecm8ShellRunCheckAsm:
        ld a,(SHL_COMMAND_BUFFER+1)
        and 0xDF
        cp "S"
        jp nz,Tecm8ShellRunUnknown
        ld a,(SHL_COMMAND_BUFFER+2)
        and 0xDF
        cp "M"
        jp z,Tecm8ShellRunAsm
        jp Tecm8ShellRunUnknown
Tecm8ShellRunCheckDir:
        ld a,(SHL_COMMAND_BUFFER+1)
        and 0xDF
        cp "I"
        jp nz,Tecm8ShellRunUnknown
        ld a,(SHL_COMMAND_BUFFER+2)
        and 0xDF
        cp "R"
        jp z,Tecm8ShellRunDirDefault
        jp Tecm8ShellRunUnknown
Tecm8ShellRunCheckRun:
        ld a,(SHL_COMMAND_BUFFER+1)
        and 0xDF
        cp "U"
        jp nz,Tecm8ShellRunUnknown
        ld a,(SHL_COMMAND_BUFFER+2)
        and 0xDF
        cp "N"
        jp z,Tecm8ShellRunRun
        jp Tecm8ShellRunUnknown
Tecm8ShellRunCheckSym:
        ld a,(SHL_COMMAND_BUFFER+1)
        and 0xDF
        cp "Y"
        jp nz,Tecm8ShellRunUnknown
        ld a,(SHL_COMMAND_BUFFER+2)
        and 0xDF
        cp "M"
        jp z,Tecm8ShellRunSymbols
        jp Tecm8ShellRunUnknown

Tecm8ShellRunCheckFour:
        ld hl,Tecm8ShellCommandEdit
        call Tecm8ShellMatchUpper
        jp z,Tecm8ShellRunEdit
        ld hl,Tecm8ShellCommandStep
        call Tecm8ShellMatchUpper
        jp z,Tecm8ShellRunDebugStep
        ld hl,Tecm8ShellCommandCont
        call Tecm8ShellMatchUpper
        jp z,Tecm8ShellRunDebugContinue
        ld hl,Tecm8ShellCommandList
        call Tecm8ShellMatchUpper
        jp z,Tecm8ShellRunListing
        jp Tecm8ShellRunUnknown

Tecm8ShellRunCheckFive:
        ld hl,Tecm8ShellCommandDebug
        call Tecm8ShellMatchUpper
        jp z,Tecm8ShellRunDebugStart
        jp Tecm8ShellRunCheckPathCommand

Tecm8ShellRunEdit:
        ld a,SHL_ACTION_EDIT
        ld b,SHL_TARGET_KIND_PROJECT_MAIN
        call Tecm8ShellPublishTarget
        jp Tecm8ShellLaunchEditor

Tecm8ShellRunCheckPathCommand:
        ld a,(SHL_COMMAND_BUFFER)
        and 0xDF
        cp "D"
        jp z,Tecm8ShellRunCheckDirPath
        cp "E"
        jp z,Tecm8ShellRunCheckEditPath
        cp "B"
        jp z,Tecm8ShellRunCheckBreak
        jp Tecm8ShellRunUnknown

Tecm8ShellRunCheckBreak:
        ld hl,Tecm8ShellCommandBreak
        call Tecm8ShellMatchUpper
        jp nz,Tecm8ShellRunUnknown
        ld a,(SHL_COMMAND_BUFFER+6)
        or a
        jp z,Tecm8ShellRunUnknown
        ld hl,SHL_COMMAND_BUFFER+6
        ld (DBG_PARAM_SYMBOL_LO),hl
        jp Tecm8ShellRunDebugBreak

Tecm8ShellRunCheckEditPath:
        ld a,(SHL_COMMAND_BUFFER)
        and 0xDF
        cp "E"
        jp nz,Tecm8ShellRunUnknown
        ld a,(SHL_COMMAND_BUFFER+1)
        and 0xDF
        cp "D"
        jp nz,Tecm8ShellRunUnknown
        ld a,(SHL_COMMAND_BUFFER+2)
        and 0xDF
        cp "I"
        jp nz,Tecm8ShellRunUnknown
        ld a,(SHL_COMMAND_BUFFER+3)
        and 0xDF
        cp "T"
        jp nz,Tecm8ShellRunUnknown
        ld a,(SHL_COMMAND_BUFFER+4)
        cp " "
        jp nz,Tecm8ShellRunUnknown
        ld a,(SHL_COMMAND_BUFFER+5)
        cp "/"
        jp nz,Tecm8ShellRunUnknown
        ld hl,SHL_COMMAND_BUFFER+5
        ld de,SHL_TARGET_PATH_BUFFER
        ld b,SHL_TARGET_PATH_CAPACITY-1
Tecm8ShellCopyEditPath:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jp z,Tecm8ShellEditPathReady
        dec b
        jp nz,Tecm8ShellCopyEditPath
        xor a
        ld (de),a
Tecm8ShellEditPathReady:
        ld a,SHL_ACTION_EDIT
        ld b,SHL_TARGET_KIND_SOURCE_PATH
        call Tecm8ShellPublishTarget
        ld hl,SHL_TARGET_PATH_BUFFER
        ld (SHL_TARGET_PATH_LO),hl
        xor a
        ld (SHL_TARGET_FLAGS),a
Tecm8ShellLaunchEditor:
        ld hl,SHL_TARGET_DESC
        ld (EDT_PARAM_TARGET_LO),hl
        or a
        .expectout A,carry
        callBankService EDT_BANK,EDT_ENTRY,EDT_SVC_RUN
        ld a,(EDT_PARAM_RESULT)
        ld (SHL_PARAM_COMMAND_RESULT_LO),a
        ld a,(EDT_PARAM_LAST_ERROR)
        ld (SHL_PARAM_COMMAND_RESULT_HI),a
        ld a,0x80
        or a
        ret

Tecm8ShellRunCheckDirPath:
        ld a,(SHL_COMMAND_BUFFER+1)
        and 0xDF
        cp "I"
        jp nz,Tecm8ShellRunUnknown
        ld a,(SHL_COMMAND_BUFFER+2)
        and 0xDF
        cp "R"
        jp nz,Tecm8ShellRunUnknown
        ld a,(SHL_COMMAND_BUFFER+3)
        cp " "
        jp nz,Tecm8ShellRunUnknown
        ld a,(SHL_COMMAND_BUFFER+4)
        cp "/"
        jp nz,Tecm8ShellRunUnknown
        ld hl,SHL_COMMAND_BUFFER+4
        ld de,SHL_TARGET_PATH_BUFFER
        ld b,SHL_TARGET_PATH_CAPACITY-1
Tecm8ShellCopyDirPath:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jp z,Tecm8ShellDirPathReady
        dec b
        jp nz,Tecm8ShellCopyDirPath
        xor a
        ld (de),a
Tecm8ShellDirPathReady:
        ld hl,SHL_TARGET_PATH_BUFFER
        ld (TFS_PARAM_PATH_LO),hl
        jp Tecm8ShellRunDir

Tecm8ShellRunAsm:
        ld a,SHL_ACTION_ASM
        ld b,SHL_TARGET_KIND_PROJECT_MAIN
        call Tecm8ShellPublishTarget
        ld hl,(SHL_PARAM_COMMAND_TARGET_LO)
        ld (ASM_PARAM_TARGET_LO),hl
        or a
        .expectout A,carry
        callBankService ASM_BANK,ASM_ENTRY,ASM_SVC_ASSEMBLE
        call Tecm8ShellPublishAsmResult
        ld a,0x80
        or a
        ret
Tecm8ShellRunRun:
        ld a,SHL_ACTION_RUN
        ld b,SHL_TARGET_KIND_PROJECT_OUTPUT
        call Tecm8ShellPublishTarget
        ld hl,(SHL_PARAM_COMMAND_TARGET_LO)
        ld (RUN_PARAM_TARGET_LO),hl
        or a
        .expectout A,carry
        callBankService RUN_BANK,RUN_ENTRY,RUN_SVC_RUN
        call Tecm8ShellPublishRunResult
        ld a,0x80
        or a
        ret
Tecm8ShellRunSymbols:
        ld a,0x01
        ld (SHL_PARAM_COMMAND_RESULT_HI),a
        ld a,RUN_SVC_SYMBOLS
        jp Tecm8ShellCallDebug
Tecm8ShellRunListing:
        ld a,0x01
        ld (SHL_PARAM_COMMAND_RESULT_HI),a
        ld a,RUN_SVC_LISTING
        jp Tecm8ShellCallDebug
Tecm8ShellRunDebugStart:
        ld a,RUN_SVC_DEBUG_START
        jp Tecm8ShellCallDebugControl
Tecm8ShellRunDebugBreak:
        ld a,RUN_SVC_BREAK_SYMBOL
        jp Tecm8ShellCallDebugControl
Tecm8ShellRunDebugStep:
        ld a,RUN_SVC_DEBUG_STEP
        jp Tecm8ShellCallDebugControl
Tecm8ShellRunDebugContinue:
        ld a,RUN_SVC_DEBUG_CONTINUE
Tecm8ShellCallDebugControl:
        push af
        xor a
        ld (SHL_PARAM_COMMAND_RESULT_HI),a
        pop af
Tecm8ShellCallDebug:
        push af
        call Tecm8ShellPrepareDebug
        pop af
        .expectout A,carry
        farCall RUN_BANK,RUN_ENTRY
        ld a,(SHL_PARAM_COMMAND_RESULT_HI)
        or a
        jp z,Tecm8ShellPublishDebugResult
        ld a,(DBG_PARAM_OUTPUT_COUNT)
        ld (TFS_PARAM_LIST_COUNT),a
Tecm8ShellPublishDebugResult:
        call Tecm8ShellPublishRunResult
        ld a,0x80
        or a
        ret
.routine out A,H,L clobbers sign,parity,halfCarry,B
Tecm8ShellPrepareDebug:
        ld a,SHL_ACTION_DEBUG
        ld b,SHL_TARGET_KIND_PROJECT_OUTPUT
        call Tecm8ShellPublishTarget
        ld hl,(SHL_PARAM_COMMAND_TARGET_LO)
        ld (RUN_PARAM_TARGET_LO),hl
        xor a
        ld (TFS_PARAM_LIST_COUNT),a
        ret
Tecm8ShellRunDirDefault:
        xor a
        ld (TFS_PARAM_PATH_LO),a
        ld (TFS_PARAM_PATH_HI),a
Tecm8ShellRunDir:
        ld a,SHL_ACTION_DIR
        ld (SHL_PARAM_COMMAND_ACTION),a
        ld (SHL_TARGET_ACTION),a
        ld hl,(TFS_PARAM_DRIVER_ADDR_LO)
        ld a,h
        cp TFS_MON3_FILE_DRIVER / 256
        jp nz,Tecm8ShellRunDirResident
        ld a,l
        cp TFS_MON3_FILE_DRIVER & 0xFF
        jp nz,Tecm8ShellRunDirResident
        ld hl,EDT_BUFFER_BASE
        ld (TFS_PARAM_LIST_DEST_LO),hl
        ld hl,EDT_BUFFER_BYTES
        ld (TFS_PARAM_LIST_CAP_LO),hl
        or a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_LIST_PATH
        jp c,Tecm8ShellPublishDirError
        ld a,(TFS_PARAM_LIST_COUNT)
        ld (SHL_PARAM_COMMAND_RESULT_HI),a
        ld a,SHL_RESULT_OK
        ld (SHL_PARAM_COMMAND_RESULT_LO),a
        ld a,0x80
        or a
        ret
Tecm8ShellRunDirResident:
        ld hl,(TFS_PARAM_BUFFER_LO)
        push hl
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_SUMMARIZE_CATALOG
        jp c,Tecm8ShellPublishDirErrorPop
        ld a,(TFS_PARAM_SUMMARY_COUNT_LO)
        ld (SHL_PARAM_COMMAND_RESULT_HI),a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_NEXT_CATALOG
        jp c,Tecm8ShellPublishDirErrorPop
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_SUMMARIZE_CATALOG
        jp c,Tecm8ShellPublishDirErrorPop
        ld a,(TFS_PARAM_SUMMARY_COUNT_LO)
        ld b,a
        ld a,(SHL_PARAM_COMMAND_RESULT_HI)
        add a,b
        ld (SHL_PARAM_COMMAND_RESULT_HI),a
        pop hl
        ld (TFS_PARAM_BUFFER_LO),hl
        ld a,SHL_RESULT_OK
        ld (SHL_PARAM_COMMAND_RESULT_LO),a
        ld a,0x80
        or a
        ret
Tecm8ShellPublishDirErrorPop:
        pop hl
        ld (TFS_PARAM_BUFFER_LO),hl
Tecm8ShellPublishDirError:
        ld a,SHL_RESULT_FILE_ERROR
        ld (SHL_PARAM_COMMAND_RESULT_LO),a
        ld a,(TFS_PARAM_LAST_ERROR)
        ld (SHL_PARAM_COMMAND_RESULT_HI),a
        ld a,0x80
        or a
        ret
Tecm8ShellRunOk:
        ld (SHL_PARAM_COMMAND_ACTION),a
        ld (SHL_TARGET_ACTION),a
        ld a,b
        ld (SHL_TARGET_KIND),a
        ld hl,SHL_TARGET_DESC
        ld (SHL_PARAM_COMMAND_TARGET_LO),hl
        ld a,SHL_TARGET_FLAG_DEFAULT
        ld (SHL_TARGET_FLAGS),a
        ld a,0x80
        or a
        ret
Tecm8ShellRunNoop:
        ld a,0x80
        or a
        ret
.routine out A clobbers sign,parity,halfCarry
Tecm8ShellPublishAsmResult:
        ld a,(ASM_PARAM_RESULT_LO)
        ld (SHL_PARAM_COMMAND_RESULT_LO),a
        ld a,(ASM_PARAM_RESULT_HI)
        ld (SHL_PARAM_COMMAND_RESULT_HI),a
        ret
.routine out A clobbers sign,parity,halfCarry
Tecm8ShellPublishRunResult:
        ld a,(RUN_PARAM_RESULT_LO)
        ld (SHL_PARAM_COMMAND_RESULT_LO),a
        ld a,(RUN_PARAM_RESULT_HI)
        ld (SHL_PARAM_COMMAND_RESULT_HI),a
        ret
.routine in A,B out A,H,L clobbers sign,parity,halfCarry
Tecm8ShellPublishTarget:
        ld (SHL_PARAM_COMMAND_ACTION),a
        ld (SHL_TARGET_ACTION),a
        ld a,b
        ld (SHL_TARGET_KIND),a
        ld hl,SHL_TARGET_DESC
        ld (SHL_PARAM_COMMAND_TARGET_LO),hl
        ld a,SHL_TARGET_FLAG_DEFAULT
        ld (SHL_TARGET_FLAGS),a
        ret
Tecm8ShellRunUnknown:
        ld a,SHL_STATUS_UNKNOWN_COMMAND
        ld (SHL_PARAM_STATUS),a
        ld (SHL_PARAM_LAST_ERROR),a
        ld a,SVC_ERR_UNKNOWN
        scf
        ret

Tecm8ShellRenderCommandStatus:
        ld a,(SHL_PARAM_STATUS)
        cp SHL_STATUS_UNKNOWN_COMMAND
        jp z,Tecm8ShellPublishCommandErrorStatus
        ld a,(SHL_PARAM_COMMAND_ACTION)
        cp SHL_ACTION_EDIT
        jp z,Tecm8ShellPublishEditStatus
        cp SHL_ACTION_ASM
        jp z,Tecm8ShellPublishAsmStatus
        cp SHL_ACTION_RUN
        jp z,Tecm8ShellPublishRunStatus
        cp SHL_ACTION_DIR
        jp z,Tecm8ShellPublishDirStatus
        cp SHL_ACTION_DEBUG
        jp z,Tecm8ShellPublishDebugStatus
        jp Tecm8ShellPublishReadyStatus

Tecm8ShellPublishCommandErrorStatus:
        ld hl,Tecm8ShellCommandErrorStatusText
        jp Tecm8ShellPublishStatusFromHl
Tecm8ShellPublishEditStatus:
        ld hl,Tecm8ShellEditStatusText
        jp Tecm8ShellPublishStatusFromHl
Tecm8ShellPublishAsmStatus:
        ld hl,Tecm8ShellAsmStatusText
        jp Tecm8ShellPublishStatusFromHl
Tecm8ShellPublishRunStatus:
        ld hl,Tecm8ShellRunStatusText
        jp Tecm8ShellPublishStatusFromHl
Tecm8ShellPublishDirStatus:
        ld hl,Tecm8ShellDirStatusText
        jp Tecm8ShellPublishStatusFromHl
Tecm8ShellPublishDebugStatus:
        ld hl,Tecm8ShellDebugStatusText
        jp Tecm8ShellPublishStatusFromHl

Tecm8ShellRenderCommandResult:
        ld a,(SHL_PARAM_COMMAND_ACTION)
        cp SHL_ACTION_DIR
        jp z,Tecm8ShellRenderDirResult
        cp SHL_ACTION_DEBUG
        jp z,Tecm8ShellRenderDebugResult
        ld a,(SHL_PARAM_COMMAND_RESULT_LO)
        cp SHL_RESULT_OK
        jp z,Tecm8ShellPublishOkResult
        cp SHL_RESULT_BUILD_ERROR
        jp z,Tecm8ShellPublishBuildResult
        cp SHL_RESULT_FILE_ERROR
        jp z,Tecm8ShellPublishFileResult
        cp SHL_RESULT_UNSUPPORTED
        jp z,Tecm8ShellPublishUnsupportedResult
        jp Tecm8ShellPublishNoneResult

Tecm8ShellPublishOkResult:
        ld hl,Tecm8ShellOkResultText
        jp Tecm8ShellPublishStatusFromHl
Tecm8ShellPublishBuildResult:
        ld hl,Tecm8ShellBuildResultText
        jp Tecm8ShellPublishStatusFromHl
Tecm8ShellPublishFileResult:
        ld hl,Tecm8ShellFileResultText
        jp Tecm8ShellPublishStatusFromHl
Tecm8ShellPublishUnsupportedResult:
        ld hl,Tecm8ShellUnsupportedResultText
        jp Tecm8ShellPublishStatusFromHl
Tecm8ShellPublishNoneResult:
        ld hl,Tecm8ShellNoneResultText
        jp Tecm8ShellPublishStatusFromHl

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
Tecm8ShellRenderDirResult:
        ld a,(SHL_PARAM_COMMAND_RESULT_LO)
        cp SHL_RESULT_OK
        jp nz,Tecm8ShellPublishFileResult
        call Tecm8ShellRenderDirRows
        ret c
        jp Tecm8ShellPublishOkResult

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
Tecm8ShellRenderDebugResult:
        ld a,(SHL_PARAM_COMMAND_RESULT_LO)
        cp SHL_RESULT_OK
        jp nz,Tecm8ShellPublishFileResult
        ld a,(TFS_PARAM_LIST_COUNT)
        or a
        jp z,Tecm8ShellPublishOkResult
        call Tecm8ShellRenderDirRows
        ret c
        jp Tecm8ShellPublishOkResult

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
Tecm8ShellRenderDirRows:
        ld hl,EDT_BUFFER_BASE
        ld (TFS_LIST_WORK_PTR_LO),hl
        ld a,0x05
        ld (TFS_LIST_ROW),a
        ld a,(TFS_PARAM_LIST_COUNT)
        or a
        jp z,Tecm8ShellRenderDirEmpty
        cp 0x11
        jp c,Tecm8ShellRenderDirCountReady
        ld a,0x10
Tecm8ShellRenderDirCountReady:
        ld (TFS_LIST_ROWS_LEFT),a
Tecm8ShellRenderDirNext:
        call Tecm8ShellCopyDirLine
        ld a,(TFS_LIST_ROW)
        ld hl,SHL_LINE_BUFFER
        call Tecm8ShellWriteHomeLine
        ret c
        ld a,(TFS_LIST_ROW)
        inc a
        ld (TFS_LIST_ROW),a
        ld a,(TFS_LIST_ROWS_LEFT)
        dec a
        ld (TFS_LIST_ROWS_LEFT),a
        jp nz,Tecm8ShellRenderDirNext
        xor a
        ret
Tecm8ShellRenderDirEmpty:
        ld a,0x05
        ld hl,Tecm8ShellEmptyDirText
        jp Tecm8ShellWriteHomeLine

.routine out A,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
Tecm8ShellCopyDirLine:
        ld hl,SHL_LINE_BUFFER
        ld de,SHL_LINE_BUFFER+1
        ld bc,SHL_LINE_CAPACITY-2
        ld a," "
        ld (hl),a
        ldir
        xor a
        ld (de),a
        ld hl,(TFS_LIST_WORK_PTR_LO)
        ld de,SHL_LINE_BUFFER
        ld b,SHL_LINE_CAPACITY-1
Tecm8ShellCopyDirLineNext:
        ld a,(hl)
        or a
        jp z,Tecm8ShellCopyDirLineDone
        cp 0x0A
        jp z,Tecm8ShellCopyDirLineNewline
        ld (de),a
        inc hl
        inc de
        dec b
        jp nz,Tecm8ShellCopyDirLineNext
Tecm8ShellCopyDirLineDiscard:
        ld a,(hl)
        or a
        jp z,Tecm8ShellCopyDirLineDone
        inc hl
        cp 0x0A
        jp nz,Tecm8ShellCopyDirLineDiscard
        jp Tecm8ShellCopyDirLineDone
Tecm8ShellCopyDirLineNewline:
        inc hl
Tecm8ShellCopyDirLineDone:
        ld (TFS_LIST_WORK_PTR_LO),hl
        ret

.routine in HL out A,B,zero clobbers sign,parity,halfCarry,C,H,L
Tecm8ShellCommandLength:
        ld b,0x00
        ld c,SHL_COMMAND_CAPACITY
Tecm8ShellCommandLengthNext:
        ld a,(hl)
        or a
        jp z,Tecm8ShellCommandLengthDone
        inc b
        inc hl
        dec c
        jp z,Tecm8ShellCommandLengthDone
        jp Tecm8ShellCommandLengthNext
Tecm8ShellCommandLengthDone:
        ld a,b
        ld (SHL_PARAM_COMMAND_LENGTH),a
        ret

.routine in H,L out A,zero clobbers sign,parity,halfCarry,C,D,E,H,L
Tecm8ShellMatchUpper:
        ld de,SHL_COMMAND_BUFFER
Tecm8ShellMatchUpperNext:
        ld a,(hl)
        or a
        ret z
        ld c,a
        ld a,(de)
        cp "a"
        jp c,Tecm8ShellMatchUpperReady
        cp "z"+1
        jp nc,Tecm8ShellMatchUpperReady
        and 0xDF
Tecm8ShellMatchUpperReady:
        cp c
        ret nz
        inc hl
        inc de
        jp Tecm8ShellMatchUpperNext

.routine out A,zero clobbers sign,parity,halfCarry,D,E,H,L
Tecm8ShellCopySplash:
        ld hl,Tecm8ShellSplashText
        ld de,SHL_SPLASH_BUFFER
Tecm8ShellCopySplashNext:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jp nz,Tecm8ShellCopySplashNext
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
Tecm8ShellRenderHome:
        .expectout A,carry
        callBankService VDU_BANK,VDU_CALL,VDU_SVC_CLEAR
        ret c
        ld a,0x00
        ld hl,Tecm8ShellTitleText
        call Tecm8ShellWriteHomeLine
        ret c
        ld a,0x01
        ld hl,Tecm8ShellModeText
        call Tecm8ShellWriteHomeLine
        ret c
        ld a,0x03
        ld hl,Tecm8ShellPromptText
        call Tecm8ShellWriteHomeLine
        ret c
        jp Tecm8ShellPublishReadyStatus

.routine in A,HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
Tecm8ShellWriteHomeLine:
        ld (TMS_PARAM_ROW),a
        xor a
        ld (TMS_PARAM_COL),a
        .rcignore flag_lifetime_risk "Flags from clearing the row/column setup are scratch; only the following VDU service result is observed."
        call Tecm8ShellCopyLineToBuffer
        ld hl,SHL_LINE_BUFFER
        ld (TMS_PARAM_STRING_LO),hl
        .expectout A,carry
        .rcignore definite_contract_violation "callBankService reloads its own B/C/HL frame; the VDU_SET_ROWCOL service does not consume caller DE/HL."
        callBankService VDU_BANK,VDU_CALL,VDU_SVC_SET_ROWCOL
        ret c
        .expectout A,carry
        callBankService VDU_BANK,VDU_CALL,VDU_SVC_PUT_STRING
        ret

.routine in HL out A,zero clobbers sign,parity,halfCarry,B,D,E,H,L
Tecm8ShellCopyLineToBuffer:
        ld de,SHL_LINE_BUFFER
        ld b,SHL_LINE_CAPACITY-1
Tecm8ShellCopyLineNext:
        ld a,(hl)
        ld (de),a
        or a
        ret z
        inc hl
        inc de
        dec b
        jp nz,Tecm8ShellCopyLineNext
        xor a
        ld (de),a
        ret

Tecm8ShellPublishReadyStatus:
        ld hl,Tecm8ShellReadyStatusText
        jp Tecm8ShellPublishStatusFromHl

.routine out A,carry,zero clobbers sign,parity,halfCarry,D,E,H,L
Tecm8ShellPublishPollStatus:
        ld hl,Tecm8ShellPollStatusText
Tecm8ShellPublishStatusFromHl:
        ld de,SHL_STATUS_BUFFER
Tecm8ShellCopyReadyStatusNext:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jp nz,Tecm8ShellCopyReadyStatusNext
        ld hl,SHL_STATUS_BUFFER
        ld (TMS_PARAM_STRING_LO),hl
        .expectout A,carry
        callBankService VDU_BANK,VDU_CALL,VDU_SVC_STATUS_LINE
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
Tecm8ShellLoopStep:
        .expectout A,carry
        callService INP_READ
        ret c
        ld a,(SHL_LOOP_TICK)
        inc a
        ld (SHL_LOOP_TICK),a
        ld a,SHL_DIRTY_INPUT+SHL_DIRTY_STATUS
        ld (SHL_LOOP_DIRTY),a
        ld a,(INP_PARAM_KEYS_LO)
        ld (SHL_LOOP_KEYS_LO),a
        ld a,(INP_PARAM_KEYS_HI)
        ld (SHL_LOOP_KEYS_HI),a
        ld a,(INP_PARAM_JOYSTICK)
        ld (SHL_LOOP_JOYSTICK),a
        ld a,(INP_PARAM_MODIFIERS)
        ld (SHL_LOOP_MODIFIERS),a
        call Tecm8ShellRenderInputEcho
        ret c
        call Tecm8ShellPublishPollStatus
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
Tecm8ShellRenderInputEcho:
        ld hl,Tecm8ShellInputEchoText
        call Tecm8ShellCopyLineToBuffer
        ld a,(SHL_LOOP_KEYS_HI)
        ld de,SHL_LINE_BUFFER+4
        call Tecm8ShellHexByte
        ld a,(SHL_LOOP_KEYS_LO)
        ld de,SHL_LINE_BUFFER+6
        call Tecm8ShellHexByte
        ld a,(SHL_LOOP_JOYSTICK)
        ld de,SHL_LINE_BUFFER+13
        call Tecm8ShellHexByte
        ld a,0x02
        ld hl,SHL_LINE_BUFFER
        jp Tecm8ShellWriteHomeLine

.routine in A,DE out A,D,E,carry,zero clobbers sign,parity,halfCarry
Tecm8ShellHexByte:
        push af
        srl a
        srl a
        srl a
        srl a
        call Tecm8ShellHexNibble
        ld (de),a
        inc de
        pop af
        call Tecm8ShellHexNibble
        ld (de),a
        ret

.routine in A out A,carry,zero clobbers sign,parity,halfCarry
Tecm8ShellHexNibble:
        and 0x0F
        add a,"0"
        cp "9"+1
        ret c
        add a,0x07
        ret

Tecm8ShellSplashText:
        .db     "TecMate",0
Tecm8ShellTitleText:
        .db     "TecMate ROM Shell",0
Tecm8ShellModeText:
        .db     "TFS:30+1 128M 4K",0
Tecm8ShellInputEchoText:
        .db     "KEY:0000 JOY:00",0
Tecm8ShellPromptText:
        .db     "> ",0
Tecm8ShellCommandEdit:
        .db     "EDIT",0
Tecm8ShellCommandStep:
        .db     "STEP",0
Tecm8ShellCommandCont:
        .db     "CONT",0
Tecm8ShellCommandList:
        .db     "LIST",0
Tecm8ShellCommandDebug:
        .db     "DEBUG",0
Tecm8ShellCommandBreak:
        .db     "BREAK ",0
Tecm8ShellEmptyDirText:
        .db     "(empty)",0
Tecm8ShellReadyStatusText:
        .db     "READY",0
Tecm8ShellPollStatusText:
        .db     "POLL",0
Tecm8ShellEditStatusText:
        .db     "EDIT",0
Tecm8ShellAsmStatusText:
        .db     "ASM",0
Tecm8ShellRunStatusText:
        .db     "RUN",0
Tecm8ShellDirStatusText:
        .db     "DIR",0
Tecm8ShellDebugStatusText:
        .db     "DEBUG",0
Tecm8ShellCommandErrorStatusText:
        .db     "ERRCMD",0
Tecm8ShellOkResultText:
        .db     "OK",0
Tecm8ShellBuildResultText:
        .db     "BUILD",0
Tecm8ShellFileResultText:
        .db     "FILE",0
Tecm8ShellUnsupportedResultText:
        .db     "UNSUP",0
Tecm8ShellNoneResultText:
        .db     "NONE",0

Tecm8ExpansionBank0Info:
        .db     "T","M","8",EXP_BANK,EXP_VERSION

Tecm8ServiceRegistry:
        .db     VDU_INIT,VDU_BANK
        .dw     VDU_ADDR
        .db     VDU_SVC_INIT
        .db     TFS_MOUNT,TFS_BANK
        .dw     TFS_ADDR
        .db     TFS_SVC_MOUNT
        .db     RTC_TOOL,RTC_BANK
        .dw     RTC_ADDR
        .db     RTC_SVC_TOOL_ENTRY
        .db     GLC_ENTRY,GLC_BANK
        .dw     GLC_ADDR
        .db     GLC_ENTRY
        .db     INP_READ,INP_BANK
        .dw     INP_ADDR
        .db     INP_SVC_READ
        .db     SHL_ENTRY,SHL_BANK
        .dw     Tecm8ShellEntry
        .db     SHL_ENTRY
        .db     SHL_RUN_COMMAND,SHL_BANK
        .dw     Tecm8ShellRunCommand
        .db     SHL_RUN_COMMAND
        .db     SHL_RENDER_STATUS,SHL_BANK
        .dw     Tecm8ShellRenderCommandStatus
        .db     SHL_RENDER_STATUS
        .db     SHL_RENDER_RESULT,SHL_BANK
        .dw     Tecm8ShellRenderCommandResult
        .db     SHL_RENDER_RESULT
        .db     ABI_PROBE_NESTED,VDU_BANK
        .dw     VDU_ENTRY
        .db     ABI_PROBE_NESTED
Tecm8ServiceRegistryEnd:
        .db     SVC_REG_END
