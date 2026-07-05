; TECM8 expansion ROM physical bank 0.
;
; Bank sources are assembled independently for the visible TEC-1G expansion
; window at 0x8000-0xBFFF, then packed into the 144K expansion image.

        .include "bank_ops.asmi"

        .org    0x8000

EXP_BANK          .equ    0x00
EXP_VERSION       .equ    0x01

@Tecm8ExpansionHeader:
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

@Tecm8ExpansionBank0Entry:
        ld a,EXP_BANK
        ld (DBG_TRACE_0),a
        call Tecm8BootstrapVdu
        call Tecm8BootstrapTecfs
        call Tecm8BootstrapInput
        call Tecm8BootstrapShell
        ret

Tecm8BootstrapVdu:
        ; expects out A
        callService VDU_INIT
        ld (DBG_TRACE_4),a
        ret

Tecm8BootstrapTecfs:
        ; expects out A
        callService TFS_MOUNT
        ld (DBG_TRACE_5),a
        ret

Tecm8BootstrapInput:
        ld a,SHL_BOOT_INPUT_READY
        ld (DBG_TRACE_7),a
        ret

Tecm8BootstrapShell:
        ; expects out A
        callService RTC_TOOL
        ld (DBG_TRACE_6),a
        ld a,SHL_BOOT_READY
        ld (DBG_TRACE_8),a
        ret

@Tecm8ServiceCall:
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

@Tecm8ShellEntry:
        ld a,EXP_BANK
        ld (SHL_PARAM_BANK),a
        ld a,EXP_VERSION
        ld (SHL_PARAM_VERSION),a
        ld a,SHL_FEATURE_ENTRY+SHL_FEATURE_SPLASH+SHL_FEATURE_COMMAND_LOOP
        ld (SHL_PARAM_FEATURES),a
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
        call Tecm8ShellCopySplash
        push de
        call Tecm8ShellPublishReadyStatus
        pop de
        xor a
        ld (TMS_PARAM_CURSOR_LO),a
        ld (TMS_PARAM_CURSOR_HI),a
        ld hl,SHL_SPLASH_BUFFER
        ld (TMS_PARAM_STRING_LO),hl
        ; expects out A,carry
        callBankService 0x01,VDU_CALL,VDU_SVC_PUT_STRING
        jp c,Tecm8ShellSplashError
        ld a,0x80
        or a
        ret
Tecm8ShellSplashError:
        ld (SHL_PARAM_LAST_ERROR),a
        ld (SHL_PARAM_STATUS),a
        scf
        ret

@Tecm8ShellRunCommand:
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
        ld hl,SHL_COMMAND_BUFFER
        ld a,(hl)
        or a
        jp z,Tecm8ShellRunUnknown
        push de
        call Tecm8ShellCommandLength
        pop de
        ld b,SHL_TARGET_KIND_NONE
        ld a,(SHL_PARAM_COMMAND_LENGTH)
        cp 0x03
        jp z,Tecm8ShellRunCheckThree
        cp 0x04
        jp z,Tecm8ShellRunCheckFour
        jp Tecm8ShellRunUnknown

Tecm8ShellRunCheckThree:
        ld a,(SHL_COMMAND_BUFFER)
        and 0xDF
        cp "A"
        jp z,Tecm8ShellRunCheckAsm
        cp "R"
        jp z,Tecm8ShellRunCheckRun
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

Tecm8ShellRunCheckFour:
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
        jp z,Tecm8ShellRunEdit
        jp Tecm8ShellRunUnknown

Tecm8ShellRunEdit:
        ld a,SHL_ACTION_EDIT
        ld b,SHL_TARGET_KIND_PROJECT_MAIN
        jp Tecm8ShellRunOk
Tecm8ShellRunAsm:
        ld a,SHL_ACTION_ASM
        ld b,SHL_TARGET_KIND_PROJECT_MAIN
        call Tecm8ShellPublishTarget
        ld hl,(SHL_PARAM_COMMAND_TARGET_LO)
        ld (ASM_PARAM_TARGET_LO),hl
        or a
        ; expects out A,carry
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
        ; expects out A,carry
        callBankService RUN_BANK,RUN_ENTRY,RUN_SVC_RUN
        call Tecm8ShellPublishRunResult
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
Tecm8ShellPublishAsmResult:
        ld a,(ASM_PARAM_RESULT_LO)
        ld (SHL_PARAM_COMMAND_RESULT_LO),a
        ld a,(ASM_PARAM_RESULT_HI)
        ld (SHL_PARAM_COMMAND_RESULT_HI),a
        ret
Tecm8ShellPublishRunResult:
        ld a,(RUN_PARAM_RESULT_LO)
        ld (SHL_PARAM_COMMAND_RESULT_LO),a
        ld a,(RUN_PARAM_RESULT_HI)
        ld (SHL_PARAM_COMMAND_RESULT_HI),a
        ret
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
        ;! rc-ignore-next definite_contract_violation: AZM cannot yet prove this local bounded count loop preserves B/C/HL across the backward branch.
        jp Tecm8ShellCommandLengthNext
Tecm8ShellCommandLengthDone:
        ld a,b
        ld (SHL_PARAM_COMMAND_LENGTH),a
        ret

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

Tecm8ShellPublishReadyStatus:
        ld hl,Tecm8ShellReadyStatusText
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
        ; expects out A,carry
        callBankService VDU_BANK,VDU_CALL,VDU_SVC_STATUS_LINE
        ret

Tecm8ShellSplashText:
        .db     "TecMate",0
Tecm8ShellReadyStatusText:
        .db     "READY",0

@Tecm8ExpansionBank0Info:
        .db     "T","M","8",EXP_BANK,EXP_VERSION

@Tecm8ServiceRegistry:
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
        .db     ABI_PROBE_NESTED,VDU_BANK
        .dw     VDU_ENTRY
        .db     ABI_PROBE_NESTED
@Tecm8ServiceRegistryEnd:
        .db     SVC_REG_END
