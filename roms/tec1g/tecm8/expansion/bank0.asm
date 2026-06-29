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
        callService VDU_INIT
        ld (DBG_TRACE_4),a
        ret

Tecm8BootstrapTecfs:
        callService TFS_MOUNT
        ld (DBG_TRACE_5),a
        ret

Tecm8BootstrapInput:
        ld a,SHL_BOOT_INPUT_READY
        ld (DBG_TRACE_7),a
        ret

Tecm8BootstrapShell:
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
        ld a,c
        cp VDU_INIT
        jp z,Tecm8ServiceCallVduInit
        cp TFS_MOUNT
        jp z,Tecm8ServiceCallTecfsMount
        cp RTC_TOOL
        jp z,Tecm8ServiceCallRtcTool
        cp GLC_ENTRY
        jp z,Tecm8ServiceCallGlcdEntry
        cp SHL_ENTRY
        jp z,Tecm8ServiceCallShellEntry
        cp ABI_PROBE_NESTED
        jp z,Tecm8ServiceCallAbiNested
        pop af
        pop de
        pop hl
        ld a,SVC_ERR_UNKNOWN
        scf
        ret

Tecm8ServiceCallVduInit:
        pop af
        pop de
        pop hl
        ld a,VDU_SVC_INIT
        farCall VDU_BANK,VDU_ADDR
        ret

Tecm8ServiceCallTecfsMount:
        pop af
        pop de
        pop hl
        ld a,TFS_SVC_MOUNT
        farCall TFS_BANK,TFS_ADDR
        ret

Tecm8ServiceCallRtcTool:
        pop af
        pop de
        pop hl
        ld a,RTC_SVC_TOOL_ENTRY
        farCall RTC_BANK,RTC_ADDR
        ret

Tecm8ServiceCallGlcdEntry:
        pop af
        pop de
        pop hl
        farCall GLC_BANK,GLC_ADDR
        ret

Tecm8ServiceCallShellEntry:
        pop af
        pop de
        pop hl
        call Tecm8ShellEntry
        ret

Tecm8ServiceCallAbiNested:
        pop af
        pop de
        pop hl
        ld a,ABI_PROBE_NESTED
        farCall 0x01,VDU_ENTRY
        ret

@Tecm8ShellEntry:
        ld a,EXP_BANK
        ld (SHL_PARAM_BANK),a
        ld a,EXP_VERSION
        ld (SHL_PARAM_VERSION),a
        ld a,SHL_FEATURE_ENTRY+SHL_FEATURE_SPLASH
        ld (SHL_PARAM_FEATURES),a
        xor a
        ld (SHL_PARAM_STATUS),a
        ld (SHL_PARAM_LAST_ERROR),a
        call Tecm8ShellCopySplash
        ld (TMS_PARAM_CURSOR_LO),a
        ld (TMS_PARAM_CURSOR_HI),a
        ld hl,SHL_SPLASH_BUFFER
        ld (TMS_PARAM_STRING_LO),hl
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

Tecm8ShellSplashText:
        .db     "TecMate",0

@Tecm8ExpansionBank0Info:
        .db     "T","M","8",EXP_BANK,EXP_VERSION

@Tecm8ServiceRegistry:
        .db     VDU_INIT,VDU_BANK
        .dw     VDU_ADDR
        .db     TFS_MOUNT,TFS_BANK
        .dw     TFS_ADDR
        .db     RTC_TOOL,RTC_BANK
        .dw     RTC_ADDR
        .db     GLC_ENTRY,GLC_BANK
        .dw     GLC_ADDR
        .db     SHL_ENTRY,SHL_BANK
        .dw     Tecm8ShellEntry
@Tecm8ServiceRegistryEnd:
        .db     SVC_REG_END
