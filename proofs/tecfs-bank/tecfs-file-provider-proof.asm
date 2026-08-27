; Ordinary TEC-FS file provider proof through the public 92h gateway.

        .org    0x4000

        .include "../../roms/tec1g/tecm8/expansion/bank_ops.asmi"

PROOF_PASS          .equ 0x42
PROOF_RESULT        .equ 0x3A10
PROOF_PHASE         .equ 0x3A11
PROOF_STATUS        .equ 0x3A12
PROOF_HANDLE        .equ 0x3A20
PROOF_REQUEST       .equ 0x5800
PROOF_NAME          .equ 0x5900
PROOF_FIRST_BUFFER  .equ 0x6000
PROOF_CROSS_BUFFER  .equ 0x6300
PROOF_SHORT_BUFFER  .equ 0x6400
PROOF_RETRY_BUFFER  .equ 0x6500

Start:
        xor a
        ld (PROOF_RESULT),a
        ld a,TFS_SVC_MOUNT
        callService TFS_MOUNT
        jp c,Fail

        ; Names are exactly one binary catalogue id byte.
        call RequestReset
        ld a,ZT_OPEN
        ld (PROOF_REQUEST+ZT_FOP),a
        ld hl,PROOF_NAME
        ld (PROOF_REQUEST+ZT_FPTR),hl
        ld a,2
        ld (PROOF_REQUEST+ZT_FLEN),a
        ld a,1
        ld (PROOF_PHASE),a
        call FileCall
        jp nc,Fail
        cp ZT_INV
        jp nz,Fail

        ; File id 1 is absent from the proof volume.
        ld a,1
        call SetOpenId
        ld a,2
        ld (PROOF_PHASE),a
        call FileCall
        jp nc,Fail
        cp ZT_NF
        jp nz,Fail

        ; File id 0 opens through the public bank-preserving gateway.
        xor a
        call SetOpenId
        ld ix,0x1357
        ld iy,0x2468
        ld a,3
        ld (PROOF_PHASE),a
        call FileCall
        jp c,Fail
        ld hl,(PROOF_REQUEST+ZT_FHND)
        ld (PROOF_HANDLE),hl
        push ix
        pop hl
        ld de,0x1357
        or a
        sbc hl,de
        jp nz,Fail
        push iy
        pop hl
        ld de,0x2468
        or a
        sbc hl,de
        jp nz,Fail

        ; A second simultaneous reader reports handle capacity, not a source
        ; part limit. Closing the first reader permits the next open.
        xor a
        call SetOpenId
        call FileCall
        jp nc,Fail
        cp ZT_CAP
        jp nz,Fail

        ; Read across an ordinary 512-byte sector boundary.
        ld hl,(PROOF_HANDLE)
        ld de,PROOF_FIRST_BUFFER
        ld bc,600
        call SetRead
        ld a,4
        ld (PROOF_PHASE),a
        call FileCall
        jp c,Fail
        ld hl,(PROOF_REQUEST+ZT_FRES)
        ld de,600
        or a
        sbc hl,de
        jp nz,Fail

        ; Seek near the end of the first 4 KiB allocation block, then cross
        ; into the second block in one transfer.
        ld hl,(PROOF_HANDLE)
        ld de,4090
        call SetSeek
        ld a,5
        ld (PROOF_PHASE),a
        call FileCall
        jp c,Fail
        ld hl,(PROOF_HANDLE)
        ld de,PROOF_CROSS_BUFFER
        ld bc,32
        call SetRead
        call FileCall
        jp c,Fail
        ld hl,(PROOF_REQUEST+ZT_FRES)
        ld de,32
        or a
        sbc hl,de
        jp nz,Fail

        ; A request beyond the remaining bytes is a successful short read.
        ld hl,(PROOF_HANDLE)
        ld de,4990
        call SetSeek
        call FileCall
        jp c,Fail
        ld hl,(PROOF_HANDLE)
        ld de,PROOF_SHORT_BUFFER
        ld bc,32
        call SetRead
        call FileCall
        jp c,Fail
        ld hl,(PROOF_REQUEST+ZT_FRES)
        ld de,10
        or a
        sbc hl,de
        jp nz,Fail

        ; Rewind and prove that a one-byte transfer ending exactly at 8000h is
        ; inside the common-visible half-open range.
        ld hl,(PROOF_HANDLE)
        call SetTerminal
        ld a,ZT_REW
        ld (PROOF_REQUEST+ZT_FOP),a
        call FileCall
        jp c,Fail
        ld hl,(PROOF_HANDLE)
        ld de,0x7FFF
        ld bc,1
        call SetRead
        call FileCall
        jp c,Fail
        ld hl,(PROOF_REQUEST+ZT_FRES)
        dec hl
        ld a,h
        or l
        jp nz,Fail

        ; Unsupported mutation operations remain distinct from malformed
        ; requests and cannot change the ordinary file.
        ld hl,(PROOF_HANDLE)
        call SetTerminal
        ld a,ZT_WRITE
        ld (PROOF_REQUEST+ZT_FOP),a
        ld a,6
        ld (PROOF_PHASE),a
        call FileCall
        jp nc,Fail
        cp ZT_UNSUP
        jp nz,Fail

        ; An injected media failure reports no bytes and leaves the handle
        ; cursor unchanged. The retried read starts at byte one.
        ld hl,(PROOF_HANDLE)
        ld de,PROOF_RETRY_BUFFER
        ld bc,16
        call SetRead
        ld a,0x30
        ld (PROOF_PHASE),a
        call FileCall
        jp nc,Fail
        cp ZT_STORE
        jp nz,Fail
        ld hl,(PROOF_REQUEST+ZT_FRES)
        ld a,h
        or l
        jp nz,Fail
        ld a,0x31
        ld (PROOF_PHASE),a
        ld hl,(PROOF_HANDLE)
        ld de,PROOF_RETRY_BUFFER
        ld bc,16
        call SetRead
        call FileCall
        jp c,Fail
        ld hl,(PROOF_REQUEST+ZT_FRES)
        ld de,16
        or a
        sbc hl,de
        jp nz,Fail

        ; Close invalidates the handle. A remount also invalidates a newly
        ; opened handle without changing catalogue identity.
        ld hl,(PROOF_HANDLE)
        call SetTerminal
        ld a,ZT_CLOSE
        ld (PROOF_REQUEST+ZT_FOP),a
        call FileCall
        jp c,Fail
        call FileCall
        jp nc,Fail
        cp ZT_INV
        jp nz,Fail
        xor a
        call SetOpenId
        call FileCall
        jp c,Fail
        ld hl,(PROOF_REQUEST+ZT_FHND)
        ld (PROOF_HANDLE),hl
        ld a,TFS_SVC_MOUNT
        callService TFS_MOUNT
        jp c,Fail
        ld hl,(PROOF_HANDLE)
        call SetTerminal
        ld a,ZT_CLOSE
        ld (PROOF_REQUEST+ZT_FOP),a
        call FileCall
        jp nc,Fail
        cp ZT_INV
        jp nz,Fail

        ld a,PROOF_PASS
        ld (PROOF_RESULT),a
        halt

Fail:
        ld (PROOF_STATUS),a
        ld a,0xE0
        ld (PROOF_RESULT),a
        halt

RequestReset:
        ld hl,PROOF_REQUEST
        ld de,PROOF_REQUEST+1
        ld bc,ZT_RQLEN-1
        xor a
        ld (hl),a
        ldir
        ld a,ZT_RQLEN
        ld (PROOF_REQUEST+ZT_FSIZE),a
        ld a,ZT_ABI
        ld (PROOF_REQUEST+ZT_FABI),a
        ret

FileCall:
        ld hl,PROOF_REQUEST
        ld c,ZT_FILE
        rst 10H
        ret

SetOpenId:
        push af
        call RequestReset
        pop af
        ld (PROOF_NAME),a
        ld hl,PROOF_NAME
        ld (PROOF_REQUEST+ZT_FPTR),hl
        ld a,1
        ld (PROOF_REQUEST+ZT_FLEN),a
        ld a,ZT_OPEN
        ld (PROOF_REQUEST+ZT_FOP),a
        ret

SetTerminal:
        push hl
        call RequestReset
        pop hl
        ld (PROOF_REQUEST+ZT_FHND),hl
        ret

SetSeek:
        push de
        call SetTerminal
        pop de
        ld (PROOF_REQUEST+ZT_FOFF),de
        ld a,ZT_SEEK
        ld (PROOF_REQUEST+ZT_FOP),a
        ret

SetRead:
        push bc
        push de
        call SetTerminal
        pop de
        pop bc
        ld (PROOF_REQUEST+ZT_FPTR),de
        ld (PROOF_REQUEST+ZT_FLEN),bc
        ld a,ZT_READ
        ld (PROOF_REQUEST+ZT_FOP),a
        ret
