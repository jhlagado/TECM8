; TECM8 expansion ROM physical bank 1: VDU/TMS9918 services.

        .include "bank_ops.asmi"

        .org    0x8000

TECM8_EXPANSION_BANK          .equ    0x01
TECM8_EXPANSION_VERSION       .equ    0x01

@Tecm8ExpansionBank1Entry:
        push af
        ld a,(TECM8_ABI_PROBE_REQUEST)
        cp TECM8_ABI_PROBE_PRESERVE
        jr z,Tecm8ExpansionBank1PreserveProbe
        pop af
        cp TECM8_ABI_PROBE_NESTED
        jp z,BankAbiNestedCall
        jp vduServiceCall
Tecm8ExpansionBank1PreserveProbe:
        xor a
        ld (TECM8_ABI_PROBE_REQUEST),a
        pop af
        jp BankAbiPreserveProbe

@Tecm8ExpansionBank1Info:
        .db     "T","M","8",TECM8_EXPANSION_BANK,TECM8_EXPANSION_VERSION

@vduServiceCall:
        cp TECM8_TMS_SVC_INIT
        jr nc,tmsServiceCall
        cp TECM8_VDU_SVC_INIT
        jr c,vduServiceUnknown
        cp TECM8_VDU_SVC_NEWLINE+1
        jr nc,vduServiceUnknown
        sub TECM8_VDU_SVC_INIT
        ld e,a
        ld d,0x00
        ld hl,Tecm8VduServiceTable
        add hl,de
        add hl,de
        add hl,de
        jp (hl)
tmsServiceCall:
        cp TECM8_TMS_SVC_WRITE_VRAM+1
        jr nc,vduServiceUnknown
        sub TECM8_TMS_SVC_INIT
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
        ld (TECM8_TMS_PARAM_ADDR_LO),a
        ld (TECM8_TMS_PARAM_ADDR_HI),a
        ld (TECM8_TMS_PARAM_VALUE),a
        call tmsWriteVramImpl
        ld a,0x81
        or a
        ret

vduSetCursorImpl:
        ld hl,(TECM8_TMS_PARAM_ADDR_LO)
        res 6,h
        res 7,h
        ld (TECM8_TMS_PARAM_CURSOR_LO),hl
        ld a,0x81
        or a
        ret

vduPutCharImpl:
        ld a,(TECM8_TMS_PARAM_CURSOR_LO)
        ld (TECM8_TMS_PARAM_ADDR_LO),a
        ld a,(TECM8_TMS_PARAM_CURSOR_HI)
        ld (TECM8_TMS_PARAM_ADDR_HI),a
        call tmsWriteVramImpl
        ld hl,(TECM8_TMS_PARAM_CURSOR_LO)
        inc hl
        res 6,h
        res 7,h
        ld (TECM8_TMS_PARAM_CURSOR_LO),hl
        ld a,0x81
        or a
        ret

vduPutStringImpl:
        ld hl,(TECM8_TMS_PARAM_STRING_LO)
vduPutStringNext:
        ld a,(hl)
        or a
        jr z,vduPutStringDone
        ld (TECM8_TMS_PARAM_VALUE),a
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
        ld hl,(TECM8_TMS_PARAM_CURSOR_LO)
        ld a,l
        and 0xE0
        ld l,a
        ld de,TECM8_VDU_TEXT_ROW_BYTES
        add hl,de
        res 6,h
        res 7,h
        ld (TECM8_TMS_PARAM_CURSOR_LO),hl
        ld a,0x81
        or a
        ret

tmsInitImpl:
        ld a,0x07
        ld (TECM8_TMS_PARAM_REGISTER),a
        ld a,0xF1
        ld (TECM8_TMS_PARAM_VALUE),a
        call tmsSetRegisterImpl
        ld a,0x81
        or a
        ret

; Input: TECM8_TMS_PARAM_REGISTER = TMS register 0-7,
;        TECM8_TMS_PARAM_VALUE = value.
tmsSetRegisterImpl:
        ld a,(TECM8_TMS_PARAM_VALUE)
        out (TECM8_TMS_CONTROL_PORT),a
        ld a,(TECM8_TMS_PARAM_REGISTER)
        and 0x07
        or 0x80
        out (TECM8_TMS_CONTROL_PORT),a
        ld a,0x81
        or a
        ret

; Input: TECM8_TMS_PARAM_ADDR_LO/HI = VRAM address,
;        TECM8_TMS_PARAM_VALUE = byte value.
tmsWriteVramImpl:
        ld a,(TECM8_TMS_PARAM_ADDR_LO)
        out (TECM8_TMS_CONTROL_PORT),a
        ld a,(TECM8_TMS_PARAM_ADDR_HI)
        and 0x3F
        or 0x40
        out (TECM8_TMS_CONTROL_PORT),a
        ld a,(TECM8_TMS_PARAM_VALUE)
        out (TECM8_TMS_DATA_PORT),a
        ld a,0x81
        or a
        ret

@BankAbiNestedCall:
        ld a,0xA1
        ld (TECM8_ABI_TRACE_6),a
        ld a,TECM8_ABI_PROBE_NESTED
        farCall 0x02,TECM8_TECFS_ENTRY
        ld (TECM8_ABI_TRACE_7),a
        ld a,0x91
        ret

@BankAbiPreserveProbe:
        ld (TECM8_ABI_TRACE_BASE+10),a
        ld a,d
        ld (TECM8_ABI_TRACE_BASE+11),a
        ld a,e
        ld (TECM8_ABI_TRACE_BASE+12),a
        ld a,h
        ld (TECM8_ABI_TRACE_BASE+13),a
        ld a,l
        ld (TECM8_ABI_TRACE_BASE+14),a
        ld a,0xC1
        ret
