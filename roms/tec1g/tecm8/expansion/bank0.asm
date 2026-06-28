; TECM8 expansion ROM physical bank 0.
;
; Bank sources are assembled independently for the visible TEC-1G expansion
; window at 0x8000-0xBFFF, then packed into the 144K expansion image.

        .include "bank_ops.asmi"

        .org    0x8000

TECM8_EXPANSION_BANK          .equ    0x00
TECM8_EXPANSION_VERSION       .equ    0x01

@Tecm8ExpansionHeader:
        .db     TECM8_EXP_MAGIC_0,TECM8_EXP_MAGIC_1
        .db     TECM8_EXP_MAGIC_2,TECM8_EXP_MAGIC_3
        .db     TECM8_EXP_HEADER_VERSION
        .db     TECM8_EXPANSION_BANK
        .db     TECM8_EXP_TYPE_SUPERVISOR
        .db     0x00
        .dw     Tecm8ExpansionInstall
        .db     0x00

Tecm8ExpansionInstall:
        ld a,TECM8_EXPANSION_BANK
        ld (TECM8_EXP_MENU_VEC_BANK),a
        ld hl,Tecm8ExpansionBank0Entry
        ld (TECM8_EXP_MENU_VEC_ADDR),hl
        xor a
        ld (TECM8_EXP_MENU_VEC_FLAGS),a
        ld a,TECM8_EXPANSION_BANK
        ld (TECM8_EXP_SVC_VEC_BANK),a
        ld hl,Tecm8ServiceCall
        ld (TECM8_EXP_SVC_VEC_ADDR),hl
        xor a
        ld (TECM8_EXP_SVC_VEC_FLAGS),a
        ret

@Tecm8ExpansionBank0Entry:
        ld a,TECM8_EXPANSION_BANK
        ld (TECM8_DEMO_TRACE_0),a
        call Tecm8BootstrapVdu
        call Tecm8BootstrapTecfs
        call Tecm8BootstrapInput
        call Tecm8BootstrapShell
        ret

Tecm8BootstrapVdu:
        callService TECM8_SERVICE_VDU_INIT
        ld (TECM8_DEMO_TRACE_4),a
        ret

Tecm8BootstrapTecfs:
        callService TECM8_SERVICE_TECFS_MOUNT
        ld (TECM8_DEMO_TRACE_5),a
        ret

Tecm8BootstrapInput:
        ld a,TECM8_BOOTSTRAP_INPUT_READY
        ld (TECM8_DEMO_TRACE_7),a
        ret

Tecm8BootstrapShell:
        callService TECM8_SERVICE_RTC_TOOL
        ld (TECM8_DEMO_TRACE_6),a
        ld a,TECM8_BOOTSTRAP_SHELL_READY
        ld (TECM8_DEMO_TRACE_8),a
        ret

@Tecm8ServiceCall:
        push hl
        push de
        push af
        ld ix,0
        add ix,sp
        ld a,(ix+12)
        cp TECM8_SERVICE_VDU_INIT
        jp z,Tecm8ServiceCallVduInit
        cp TECM8_SERVICE_TECFS_MOUNT
        jp z,Tecm8ServiceCallTecfsMount
        cp TECM8_SERVICE_RTC_TOOL
        jp z,Tecm8ServiceCallRtcTool
        cp TECM8_SERVICE_GLCD_ENTRY
        jp z,Tecm8ServiceCallGlcdEntry
        cp TECM8_SERVICE_SHELL_ENTRY
        jp z,Tecm8ServiceCallShellEntry
        pop af
        pop de
        pop hl
        ld a,TECM8_SERVICE_ERR_UNKNOWN
        scf
        ret

Tecm8ServiceCallVduInit:
        pop af
        pop de
        pop hl
        ld a,TECM8_VDU_SVC_INIT
        farCall TECM8_SERVICE_VDU_INIT_BANK,TECM8_SERVICE_VDU_INIT_ADDR
        ret

Tecm8ServiceCallTecfsMount:
        pop af
        pop de
        pop hl
        farCall TECM8_SERVICE_TECFS_MOUNT_BANK,TECM8_SERVICE_TECFS_MOUNT_ADDR
        ret

Tecm8ServiceCallRtcTool:
        pop af
        pop de
        pop hl
        farCall TECM8_SERVICE_RTC_TOOL_BANK,TECM8_SERVICE_RTC_TOOL_ADDR
        ret

Tecm8ServiceCallGlcdEntry:
        pop af
        pop de
        pop hl
        farCall TECM8_SERVICE_GLCD_ENTRY_BANK,TECM8_SERVICE_GLCD_ENTRY_ADDR
        ret

Tecm8ServiceCallShellEntry:
        pop af
        pop de
        pop hl
        call Tecm8ShellEntry
        ret

@Tecm8ShellEntry:
        ld a,TECM8_EXPANSION_BANK
        ld (TECM8_SHELL_PARAM_BANK),a
        ld a,TECM8_EXPANSION_VERSION
        ld (TECM8_SHELL_PARAM_VERSION),a
        ld a,TECM8_SHELL_FEATURE_ENTRY+TECM8_SHELL_FEATURE_SPLASH
        ld (TECM8_SHELL_PARAM_FEATURES),a
        xor a
        ld (TECM8_SHELL_PARAM_STATUS),a
        ld (TECM8_SHELL_PARAM_LAST_ERROR),a
        call Tecm8ShellCopySplash
        ld (TECM8_TMS_PARAM_CURSOR_LO),a
        ld (TECM8_TMS_PARAM_CURSOR_HI),a
        ld hl,TECM8_SHELL_SPLASH_BUFFER
        ld (TECM8_TMS_PARAM_STRING_LO),hl
        callBankService 0x01,TECM8_VDU_SERVICE_CALL,TECM8_VDU_SVC_PUT_STRING
        jp c,Tecm8ShellSplashError
        ld a,0x80
        or a
        ret
Tecm8ShellSplashError:
        ld (TECM8_SHELL_PARAM_LAST_ERROR),a
        ld (TECM8_SHELL_PARAM_STATUS),a
        scf
        ret

Tecm8ShellCopySplash:
        ld hl,Tecm8ShellSplashText
        ld de,TECM8_SHELL_SPLASH_BUFFER
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

        .org    0x8180
@Tecm8ExpansionBank0Info:
        .db     "T","M","8",TECM8_EXPANSION_BANK,TECM8_EXPANSION_VERSION

@Tecm8ServiceRegistry:
        .db     TECM8_SERVICE_VDU_INIT,TECM8_SERVICE_VDU_INIT_BANK
        .dw     TECM8_SERVICE_VDU_INIT_ADDR
        .db     TECM8_SERVICE_TECFS_MOUNT,TECM8_SERVICE_TECFS_MOUNT_BANK
        .dw     TECM8_SERVICE_TECFS_MOUNT_ADDR
        .db     TECM8_SERVICE_RTC_TOOL,TECM8_SERVICE_RTC_TOOL_BANK
        .dw     TECM8_SERVICE_RTC_TOOL_ADDR
        .db     TECM8_SERVICE_GLCD_ENTRY,TECM8_SERVICE_GLCD_ENTRY_BANK
        .dw     TECM8_SERVICE_GLCD_ENTRY_ADDR
        .db     TECM8_SERVICE_SHELL_ENTRY,TECM8_SERVICE_SHELL_ENTRY_BANK
        .dw     Tecm8ShellEntry
@Tecm8ServiceRegistryEnd:
        .db     TECM8_SERVICE_REGISTRY_END
