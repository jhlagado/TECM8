; TECM8 expansion ROM physical bank 0.
;
; Bank sources are assembled independently for the visible TEC-1G expansion
; window at 0x8000-0xBFFF, then packed into the 144K expansion image.

        .include "bank_ops.asmi"

        .org    0x8000

TECM8_EXPANSION_BANK          .equ    0x00
TECM8_EXPANSION_VERSION       .equ    0x01

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

        .org    TECM8_SERVICE_CALL
@Tecm8ServiceCall:
        push hl
        push de
        push af
        ld ix,0
        add ix,sp
        ld a,(ix+12)
        cp TECM8_SERVICE_VDU_INIT
        jr z,Tecm8ServiceCallVduInit
        cp TECM8_SERVICE_TECFS_MOUNT
        jr z,Tecm8ServiceCallTecfsMount
        cp TECM8_SERVICE_RTC_TOOL
        jr z,Tecm8ServiceCallRtcTool
        cp TECM8_SERVICE_GLCD_ENTRY
        jr z,Tecm8ServiceCallGlcdEntry
        cp TECM8_SERVICE_SHELL_ENTRY
        jr z,Tecm8ServiceCallShellEntry
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

        .org    TECM8_SHELL_ENTRY
@Tecm8ShellEntry:
        ld a,TECM8_EXPANSION_BANK
        ld (TECM8_SHELL_PARAM_BANK),a
        ld a,TECM8_EXPANSION_VERSION
        ld (TECM8_SHELL_PARAM_VERSION),a
        ld a,TECM8_SHELL_FEATURE_ENTRY
        ld (TECM8_SHELL_PARAM_FEATURES),a
        xor a
        ld (TECM8_SHELL_PARAM_STATUS),a
        ld (TECM8_SHELL_PARAM_LAST_ERROR),a
        ld a,0x80
        or a
        ret

        .org    0x8160
@Tecm8ExpansionBank0Info:
        .db     "T","M","8",TECM8_EXPANSION_BANK,TECM8_EXPANSION_VERSION
