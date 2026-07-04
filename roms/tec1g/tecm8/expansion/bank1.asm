; TECM8 expansion ROM physical bank 1: VDU/TMS9918 services.

        .include "bank_ops.asmi"

        .org    0x8000

EXP_BANK          .equ    0x01
EXP_VERSION       .equ    0x01

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
        cp VDU_SVC_STATUS_LINE+1
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
        cp TMS_SVC_READ_VRAM+1
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
        jp      vduSetRowColImpl
        jp      vduScrollUpImpl
        jp      vduStatusLineImpl

Tecm8TmsServiceTable:
        jp      tmsInitImpl
        jp      tmsSetRegisterImpl
        jp      tmsWriteVramImpl
        jp      tmsFillVramImpl
        jp      tmsReadVramImpl

vduInitImpl:
        call tmsInitImpl
        ld a,0x81
        or a
        ret

vduClearImpl:
        xor a
        ld (TMS_PARAM_ADDR_LO),a
        ld (TMS_PARAM_ADDR_HI),a
        ld a,VDU_BLANK_CHAR
        ld (TMS_PARAM_VALUE),a
        ld hl,VDU_SCREEN_BYTES
        ld (TMS_PARAM_COUNT_LO),hl
        call tmsFillVramImpl
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

vduSetRowColImpl:
        ld a,(TMS_PARAM_ROW)
        ld l,a
        ld h,0x00
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,(TMS_PARAM_COL)
        and 0x1F
        ld e,a
        ld d,0x00
        add hl,de
        ld (TMS_PARAM_CURSOR_LO),hl
        ld a,0x81
        or a
        ret

vduScrollUpImpl:
        ld hl,VDU_ROW_BYTES
        ld de,0x0000
        ld bc,VDU_SCROLL_BYTES
vduScrollUpNext:
        ld (TMS_PARAM_ADDR_LO),hl
        call tmsReadVramImpl
        ld a,(TMS_PARAM_VALUE)
        ld (TMS_PARAM_VALUE),a
        push hl
        ld h,d
        ld l,e
        ld (TMS_PARAM_ADDR_LO),hl
        call tmsWriteVramImpl
        pop hl
        inc hl
        inc de
        dec bc
        ld a,b
        or c
        jr nz,vduScrollUpNext
        ld hl,VDU_LAST_ROW_ADDR
        ld (TMS_PARAM_ADDR_LO),hl
        ld a,VDU_BLANK_CHAR
        ld (TMS_PARAM_VALUE),a
        ld hl,VDU_ROW_BYTES
        ld (TMS_PARAM_COUNT_LO),hl
        call tmsFillVramImpl
        ld hl,VDU_LAST_ROW_ADDR
        ld (TMS_PARAM_CURSOR_LO),hl
        ld a,0x81
        or a
        ret

vduStatusLineImpl:
        ld hl,(TMS_PARAM_CURSOR_LO)
        push hl
        ld hl,VDU_LAST_ROW_ADDR
        ld (TMS_PARAM_ADDR_LO),hl
        ld a,VDU_BLANK_CHAR
        ld (TMS_PARAM_VALUE),a
        ld hl,VDU_ROW_BYTES
        ld (TMS_PARAM_COUNT_LO),hl
        call tmsFillVramImpl
        ld hl,VDU_LAST_ROW_ADDR
        ld (TMS_PARAM_CURSOR_LO),hl
        call vduPutStringImpl
        pop hl
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

; Input: TMS_PARAM_ADDR_LO/HI = VRAM address.
; Output: TMS_PARAM_VALUE = byte read.
tmsReadVramImpl:
        ld a,(TMS_PARAM_ADDR_LO)
        out (TMS_CONTROL_PORT),a
        ld a,(TMS_PARAM_ADDR_HI)
        and 0x3F
        out (TMS_CONTROL_PORT),a
        in a,(TMS_DATA_PORT)
        ld (TMS_PARAM_VALUE),a
        ld a,0x81
        or a
        ret

; Input: TMS_PARAM_ADDR_LO/HI = start VRAM address,
;        TMS_PARAM_VALUE = byte value,
;        TMS_PARAM_COUNT_LO/HI = byte count.
tmsFillVramImpl:
        ld hl,(TMS_PARAM_COUNT_LO)
        ld a,h
        or l
        jr z,tmsFillVramDone
        ld a,(TMS_PARAM_ADDR_LO)
        out (TMS_CONTROL_PORT),a
        ld a,(TMS_PARAM_ADDR_HI)
        and 0x3F
        or 0x40
        out (TMS_CONTROL_PORT),a
tmsFillVramNext:
        ld a,(TMS_PARAM_VALUE)
        out (TMS_DATA_PORT),a
        dec hl
        ld a,h
        or l
        jr nz,tmsFillVramNext
tmsFillVramDone:
        ld a,0x81
        or a
        ret

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
