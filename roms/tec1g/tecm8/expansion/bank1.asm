; TECM8 expansion ROM physical bank 1: VDU/TMS9918 services.

        .include "bank_ops.asmi"

        .org    0x8000

EXP_BANK          .equ    0x01
EXP_VERSION       .equ    0x01

;! rc-ignore-next unknown_control_flow: temporary until AZM can express MON_BANK_CALL stack-frame effects.
@Tecm8ExpansionBank1Entry:
        push af
        ld a,(ABI_PROBE_REQUEST)
        cp ABI_PROBE_PRESERVE
        jr z,Tecm8ExpansionBank1PreserveProbe
        pop af
        cp ABI_PROBE_NESTED
        jp z,BankAbiNestedCall
        jp vduServiceCall
Tecm8ExpansionBank1PreserveProbe:
        xor a
        ld (ABI_PROBE_REQUEST),a
        pop af
        jp BankAbiPreserveProbe

@Tecm8ExpansionBank1Info:
        .db     "T","M","8",EXP_BANK,EXP_VERSION

@vduServiceCall:
        cp TMS_SVC_INIT
        jr nc,tmsServiceCall
        cp VDU_SVC_INIT
        jr c,vduServiceUnknown
        cp VDU_SVC_NEWLINE+1
        jr nc,vduServiceUnknown
        sub VDU_SVC_INIT
        ld e,a
        ld d,0x00
        ld hl,Tecm8VduServiceTable
        add hl,de
        add hl,de
        add hl,de
        jp (hl)
tmsServiceCall:
        cp TMS_SVC_WRITE_VRAM+1
        jr nc,vduServiceUnknown
        sub TMS_SVC_INIT
        ld e,a
        ld d,0x00
        ld hl,Tecm8TmsServiceTable
        add hl,de
        add hl,de
        add hl,de
        jp (hl)
vduServiceUnknown:
        ld a,SVC_ERR_UNKNOWN
        scf
        ret

Tecm8VduServiceTable:
        jp      vduInitImpl
        jp      vduClearImpl
        jp      vduSetCursorImpl
        jp      vduPutCharImpl
        jp      vduPutStringImpl
        jp      vduNewlineImpl

Tecm8TmsServiceTable:
        jp      tmsInitImpl
        jp      tmsSetRegisterImpl
        jp      tmsWriteVramImpl

vduInitImpl:
        call tmsInitImpl
        ld a,0x81
        or a
        ret

vduClearImpl:
        xor a
        ld (TMS_PARAM_ADDR_LO),a
        ld (TMS_PARAM_ADDR_HI),a
        ld (TMS_PARAM_VALUE),a
        call tmsWriteVramImpl
        ld a,0x81
        or a
        ret

vduSetCursorImpl:
        ld hl,(TMS_PARAM_ADDR_LO)
        res 6,h
        res 7,h
        ld (TMS_PARAM_CURSOR_LO),hl
        ld a,0x81
        or a
        ret

vduPutCharImpl:
        ld a,(TMS_PARAM_CURSOR_LO)
        ld (TMS_PARAM_ADDR_LO),a
        ld a,(TMS_PARAM_CURSOR_HI)
        ld (TMS_PARAM_ADDR_HI),a
        call tmsWriteVramImpl
        ld hl,(TMS_PARAM_CURSOR_LO)
        inc hl
        res 6,h
        res 7,h
        ld (TMS_PARAM_CURSOR_LO),hl
        ld a,0x81
        or a
        ret

vduPutStringImpl:
        ld hl,(TMS_PARAM_STRING_LO)
vduPutStringNext:
        ld a,(hl)
        or a
        jr z,vduPutStringDone
        ld (TMS_PARAM_VALUE),a
        push hl
        call vduPutCharImpl
        pop hl
        inc hl
        jr vduPutStringNext
vduPutStringDone:
        ld a,0x81
        or a
        ret

vduNewlineImpl:
        ld hl,(TMS_PARAM_CURSOR_LO)
        ld a,l
        and 0xE0
        ld l,a
        ld de,VDU_ROW_BYTES
        add hl,de
        res 6,h
        res 7,h
        ld (TMS_PARAM_CURSOR_LO),hl
        ld a,0x81
        or a
        ret

tmsInitImpl:
        ld a,0x07
        ld (TMS_PARAM_REGISTER),a
        ld a,0xF1
        ld (TMS_PARAM_VALUE),a
        call tmsSetRegisterImpl
        ld a,0x81
        or a
        ret

; Input: TMS_PARAM_REGISTER = TMS register 0-7,
;        TMS_PARAM_VALUE = value.
tmsSetRegisterImpl:
        ld a,(TMS_PARAM_VALUE)
        out (TMS_CONTROL_PORT),a
        ld a,(TMS_PARAM_REGISTER)
        and 0x07
        or 0x80
        out (TMS_CONTROL_PORT),a
        ld a,0x81
        or a
        ret

; Input: TMS_PARAM_ADDR_LO/HI = VRAM address,
;        TMS_PARAM_VALUE = byte value.
tmsWriteVramImpl:
        ld a,(TMS_PARAM_ADDR_LO)
        out (TMS_CONTROL_PORT),a
        ld a,(TMS_PARAM_ADDR_HI)
        and 0x3F
        or 0x40
        out (TMS_CONTROL_PORT),a
        ld a,(TMS_PARAM_VALUE)
        out (TMS_DATA_PORT),a
        ld a,0x81
        or a
        ret

;! rc-ignore-next unknown_control_flow: temporary until AZM can express MON_BANK_CALL stack-frame effects.
@BankAbiNestedCall:
        ld a,0xA1
        ld (ABI_TRACE_6),a
        ld a,ABI_PROBE_NESTED
        ; expects out A
        farCall 0x02,TFS_ENTRY
        ld (ABI_TRACE_7),a
        ld a,0x91
        ret

@BankAbiPreserveProbe:
        ld (ABI_TRACE_BASE+10),a
        ld a,d
        ld (ABI_TRACE_BASE+11),a
        ld a,e
        ld (ABI_TRACE_BASE+12),a
        ld a,h
        ld (ABI_TRACE_BASE+13),a
        ld a,l
        ld (ABI_TRACE_BASE+14),a
        ld a,0xC1
        ret
