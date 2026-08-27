; Native named-object ABI proof through the public 91h service gateway.

        .org    0x4000

        .include "../../roms/tec1g/tecm8/expansion/bank_ops.asmi"

PROOF_PASS       .equ 0x42
PROOF_RESULT     .equ 0x3A10
PROOF_PHASE      .equ 0x3A11
PROOF_WRITE_HANDLE .equ 0x3A20
PROOF_READ_HANDLE  .equ 0x3A22
PROOF_OLD_HANDLE   .equ 0x3A24
PROOF_REQUEST     .equ 0x5800
PROOF_NAME        .equ 0x5900
PROOF_WRITE_BUFFER .equ 0x6000
PROOF_READ_BUFFER  .equ 0x6300

Start:
        xor a
        ld (PROOF_RESULT),a
        ld a,TFS_SVC_MOUNT
        callService TFS_MOUNT
        jp c,Fail

        ; Malformed headers are rejected at the public gateway.
        call ObjectReset
        xor a
        ld (PROOF_REQUEST),a
        ld a,1
        ld (PROOF_PHASE),a
        call ObjectCall
        jp nc,Fail
        cp NucleusStatusInvalid
        jp nz,Fail

        ; A missing committed name is distinct from storage failure.
        call SetAlphaName
        ld a,NucleusObjectOpenRead
        ld (PROOF_REQUEST+NucleusObjectRequestOperation),a
        ld ix,0x1357
        ld iy,0x2468
        ld a,2
        ld (PROOF_PHASE),a
        call ObjectCall
        jp nc,Fail
        cp NucleusStatusNotFound
        jp nz,Fail
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

        ; Begin a tentative generation and write 513 binary bytes.
        call SetAlphaName
        ld a,NucleusObjectBeginWrite
        ld (PROOF_REQUEST+NucleusObjectRequestOperation),a
        ld a,3
        ld (PROOF_PHASE),a
        call ObjectCall
        jp c,Fail
        ld hl,(PROOF_REQUEST+NucleusObjectRequestHandle)
        ld (PROOF_WRITE_HANDLE),hl
        call FillPattern
        call SetWriteTransfer
        ld bc,513
        ld (PROOF_REQUEST+NucleusObjectRequestLength),bc
        ld a,4
        ld (PROOF_PHASE),a
        call ObjectCall
        jp c,Fail
        ld hl,(PROOF_REQUEST+NucleusObjectRequestResult)
        ld de,513
        or a
        sbc hl,de
        jp nz,Fail

        ; The tentative generation is hidden and a second writer conflicts.
        call SetAlphaName
        ld a,NucleusObjectOpenRead
        ld (PROOF_REQUEST+NucleusObjectRequestOperation),a
        ld a,5
        ld (PROOF_PHASE),a
        call ObjectCall
        jp nc,Fail
        cp NucleusStatusNotFound
        jp nz,Fail
        call SetAlphaName
        ld a,NucleusObjectBeginWrite
        ld (PROOF_REQUEST+NucleusObjectRequestOperation),a
        ld a,0x15
        ld (PROOF_PHASE),a
        call ObjectCall
        jp nc,Fail
        cp NucleusStatusConflict
        jp nz,Fail

        ; The update handle is readable before publication.
        ld hl,(PROOF_WRITE_HANDLE)
        ld a,NucleusObjectRewind
        call SetTerminal
        ld a,NucleusObjectRewind
        ld (PROOF_REQUEST+NucleusObjectRequestOperation),a
        call ObjectCall
        jp c,Fail
        ld hl,(PROOF_WRITE_HANDLE)
        call SetReadTransfer
        ld bc,513
        ld (PROOF_REQUEST+NucleusObjectRequestLength),bc
        ld a,6
        ld (PROOF_PHASE),a
        call ObjectCall
        jp c,Fail
        call CheckPattern
        jp nz,Fail

        ; Commit publishes the descriptor atomically and invalidates the writer.
        ld hl,(PROOF_WRITE_HANDLE)
        call SetTerminal
        ld a,NucleusObjectCommit
        ld (PROOF_REQUEST+NucleusObjectRequestOperation),a
        ld a,7
        ld (PROOF_PHASE),a
        call ObjectCall
        jp c,Fail
        call ObjectCall
        jp nc,Fail
        cp NucleusStatusInvalid
        jp nz,Fail

        ; Read across the 512-byte sector boundary and verify exact bytes.
        call OpenAlphaRead
        jp c,Fail
        ld hl,(PROOF_REQUEST+NucleusObjectRequestHandle)
        ld (PROOF_READ_HANDLE),hl
        call SetReadTransfer
        ld bc,513
        ld (PROOF_REQUEST+NucleusObjectRequestLength),bc
        ld a,8
        ld (PROOF_PHASE),a
        call ObjectCall
        jp c,Fail
        call CheckPattern
        jp nz,Fail

        ; Seeking beyond end is unsupported and leaves the cursor unchanged.
        ld hl,(PROOF_READ_HANDLE)
        call SetSeek
        ld de,514
        ld (PROOF_REQUEST+NucleusObjectRequestOffset),de
        ld a,9
        ld (PROOF_PHASE),a
        call ObjectCall
        jp nc,Fail
        cp NucleusStatusUnsupported
        jp nz,Fail
        ld hl,(PROOF_READ_HANDLE)
        call SetTerminal
        ld a,NucleusObjectRewind
        ld (PROOF_REQUEST+NucleusObjectRequestOperation),a
        call ObjectCall
        jp c,Fail

        ; Keep an old reader live while a replacement is committed.
        ld hl,(PROOF_READ_HANDLE)
        ld (PROOF_OLD_HANDLE),hl
        call SetAlphaName
        ld a,NucleusObjectBeginWrite
        ld (PROOF_REQUEST+NucleusObjectRequestOperation),a
        ld a,10
        ld (PROOF_PHASE),a
        call ObjectCall
        jp c,Fail
        ld hl,(PROOF_REQUEST+NucleusObjectRequestHandle)
        ld (PROOF_WRITE_HANDLE),hl
        ld hl,ReplacementBytes
        ld de,PROOF_WRITE_BUFFER
        ld bc,5
        ldir
        call SetWriteTransfer
        ld bc,5
        ld (PROOF_REQUEST+NucleusObjectRequestLength),bc
        call ObjectCall
        jp c,Fail
        ld hl,(PROOF_WRITE_HANDLE)
        call SetTerminal
        ld a,NucleusObjectCommit
        ld (PROOF_REQUEST+NucleusObjectRequestOperation),a
        call ObjectCall
        jp c,Fail

        ; The pre-commit reader still observes generation one.
        ld hl,(PROOF_OLD_HANDLE)
        call SetReadTransfer
        ld bc,6
        ld (PROOF_REQUEST+NucleusObjectRequestLength),bc
        ld a,11
        ld (PROOF_PHASE),a
        call ObjectCall
        jp c,Fail
        ld hl,PROOF_READ_BUFFER
        ld b,6
        xor a
CheckOldGeneration:
        cp (hl)
        jp nz,Fail
        inc a
        inc hl
        djnz CheckOldGeneration

        ; A fresh reader sees generation two and all high-bit bytes unchanged.
        call OpenAlphaRead
        jp c,Fail
        ld hl,(PROOF_REQUEST+NucleusObjectRequestHandle)
        ld (PROOF_READ_HANDLE),hl
        call SetReadTransfer
        ld bc,5
        ld (PROOF_REQUEST+NucleusObjectRequestLength),bc
        ld a,12
        ld (PROOF_PHASE),a
        call ObjectCall
        jp c,Fail
        ld hl,PROOF_READ_BUFFER
        ld de,ReplacementBytes
        ld b,5
CheckReplacement:
        ld a,(de)
        cp (hl)
        jp nz,Fail
        inc de
        inc hl
        djnz CheckReplacement

        ; EOF is a successful zero-byte result, and an oversized request is a
        ; successful short read rather than a status value.
        ld hl,(PROOF_READ_HANDLE)
        call SetReadTransfer
        ld bc,10
        ld (PROOF_REQUEST+NucleusObjectRequestLength),bc
        call ObjectCall
        jp c,Fail
        ld hl,(PROOF_REQUEST+NucleusObjectRequestResult)
        ld a,h
        or l
        jp nz,Fail
        ld hl,(PROOF_READ_HANDLE)
        call SetTerminal
        ld a,NucleusObjectRewind
        ld (PROOF_REQUEST+NucleusObjectRequestOperation),a
        call ObjectCall
        jp c,Fail
        ld hl,(PROOF_READ_HANDLE)
        call SetReadTransfer
        ld bc,7
        ld (PROOF_REQUEST+NucleusObjectRequestLength),bc
        call ObjectCall
        jp c,Fail
        ld hl,(PROOF_REQUEST+NucleusObjectRequestResult)
        ld de,5
        or a
        sbc hl,de
        jp nz,Fail

        ; A third generation cannot overwrite storage still owned by the old
        ; generation-one reader.
        call SetAlphaName
        ld a,NucleusObjectBeginWrite
        ld (PROOF_REQUEST+NucleusObjectRequestOperation),a
        ld a,0x1C
        ld (PROOF_PHASE),a
        call ObjectCall
        jp nc,Fail
        cp NucleusStatusConflict
        jp nz,Fail

        ld hl,(PROOF_OLD_HANDLE)
        call SetTerminal
        ld a,NucleusObjectClose
        ld (PROOF_REQUEST+NucleusObjectRequestOperation),a
        call ObjectCall
        jp c,Fail

        ; An aborted replacement with written bytes does not disturb generation two.
        call SetAlphaName
        ld a,NucleusObjectBeginWrite
        ld (PROOF_REQUEST+NucleusObjectRequestOperation),a
        call ObjectCall
        jp c,Fail
        ld hl,(PROOF_REQUEST+NucleusObjectRequestHandle)
        ld (PROOF_WRITE_HANDLE),hl
        call SetWriteTransfer
        ld bc,3
        ld (PROOF_REQUEST+NucleusObjectRequestLength),bc
        ld a,13
        ld (PROOF_PHASE),a
        call ObjectCall
        jp c,Fail
        ld hl,(PROOF_WRITE_HANDLE)
        call SetTerminal
        ld a,NucleusObjectAbort
        ld (PROOF_REQUEST+NucleusObjectRequestOperation),a
        call ObjectCall
        jp c,Fail

        call VerifyReplacement

        ; A media failure while writing data poisons the update handle. Abort
        ; still succeeds and the committed generation remains unchanged.
        call SetAlphaName
        ld a,NucleusObjectBeginWrite
        ld (PROOF_REQUEST+NucleusObjectRequestOperation),a
        call ObjectCall
        jp c,Fail
        ld hl,(PROOF_REQUEST+NucleusObjectRequestHandle)
        ld (PROOF_WRITE_HANDLE),hl
        call SetWriteTransfer
        ld bc,3
        ld (PROOF_REQUEST+NucleusObjectRequestLength),bc
        ld a,0x30
        ld (PROOF_PHASE),a
        call ObjectCall
        jp nc,Fail
        cp NucleusStatusStorage
        jp nz,Fail
        ld a,0x32
        ld (PROOF_PHASE),a
        ld hl,(PROOF_WRITE_HANDLE)
        call SetTerminal
        ld a,NucleusObjectAbort
        ld (PROOF_REQUEST+NucleusObjectRequestOperation),a
        call ObjectCall
        jp c,Fail
        call VerifyReplacement

        ; A media failure while publishing the descriptor cannot replace the
        ; committed generation. The still-live writer can be aborted.
        call SetAlphaName
        ld a,NucleusObjectBeginWrite
        ld (PROOF_REQUEST+NucleusObjectRequestOperation),a
        call ObjectCall
        jp c,Fail
        ld hl,(PROOF_REQUEST+NucleusObjectRequestHandle)
        ld (PROOF_WRITE_HANDLE),hl
        call SetWriteTransfer
        ld bc,3
        ld (PROOF_REQUEST+NucleusObjectRequestLength),bc
        call ObjectCall
        jp c,Fail
        ld hl,(PROOF_WRITE_HANDLE)
        call SetTerminal
        ld a,NucleusObjectCommit
        ld (PROOF_REQUEST+NucleusObjectRequestOperation),a
        ld a,0x31
        ld (PROOF_PHASE),a
        call ObjectCall
        jp nc,Fail
        cp NucleusStatusStorage
        jp nz,Fail
        ld a,0x32
        ld (PROOF_PHASE),a
        ld hl,(PROOF_WRITE_HANDLE)
        call SetTerminal
        ld a,NucleusObjectAbort
        ld (PROOF_REQUEST+NucleusObjectRequestOperation),a
        call ObjectCall
        jp c,Fail
        call VerifyReplacement

        ; A remount is a provider reset and makes all old handles stale.
        ld a,TFS_SVC_MOUNT
        callService TFS_MOUNT
        jp c,Fail
        ld hl,(PROOF_READ_HANDLE)
        call SetTerminal
        ld a,NucleusObjectClose
        ld (PROOF_REQUEST+NucleusObjectRequestOperation),a
        ld a,14
        ld (PROOF_PHASE),a
        call ObjectCall
        jp nc,Fail
        cp NucleusStatusInvalid
        jp nz,Fail

        ld a,PROOF_PASS
        ld (PROOF_RESULT),a
        halt

Fail:
        ld (0x3A12),a
        ld a,0xE0
        ld (PROOF_RESULT),a
        halt

ObjectReset:
        ld hl,PROOF_REQUEST
        ld de,PROOF_REQUEST+1
        ld bc,NucleusObjectRequestSize-1
        xor a
        ld (hl),a
        ldir
        ld a,NucleusObjectRequestSize
        ld (PROOF_REQUEST),a
        ld a,NucleusObjectAbiVersion
        ld (PROOF_REQUEST+1),a
        ret

ObjectCall:
        ld hl,PROOF_REQUEST
        ld c,ZT_OBJECT
        rst 10H
        ret

SetAlphaName:
        call ObjectReset
        ld hl,AlphaName
        ld (PROOF_REQUEST+NucleusObjectRequestPointer),hl
        ld a,AlphaNameEnd-AlphaName
        ld (PROOF_REQUEST+NucleusObjectRequestLength),a
        ret

OpenAlphaRead:
        call SetAlphaName
        ld a,NucleusObjectOpenRead
        ld (PROOF_REQUEST+NucleusObjectRequestOperation),a
        jp ObjectCall

SetTerminal:
        push hl
        call ObjectReset
        pop hl
        ld (PROOF_REQUEST+NucleusObjectRequestHandle),hl
        ret

SetSeek:
        call SetTerminal
        ld a,NucleusObjectSeek
        ld (PROOF_REQUEST+NucleusObjectRequestOperation),a
        ret

SetWriteTransfer:
        ld hl,(PROOF_WRITE_HANDLE)
        push hl
        call ObjectReset
        pop hl
        ld (PROOF_REQUEST+NucleusObjectRequestHandle),hl
        ld hl,PROOF_WRITE_BUFFER
        ld (PROOF_REQUEST+NucleusObjectRequestPointer),hl
        ld a,NucleusObjectWrite
        ld (PROOF_REQUEST+NucleusObjectRequestOperation),a
        ret

SetReadTransfer:
        push hl
        call ObjectReset
        pop hl
        ld (PROOF_REQUEST+NucleusObjectRequestHandle),hl
        ld hl,PROOF_READ_BUFFER
        ld (PROOF_REQUEST+NucleusObjectRequestPointer),hl
        ld a,NucleusObjectRead
        ld (PROOF_REQUEST+NucleusObjectRequestOperation),a
        ret

VerifyReplacement:
        call OpenAlphaRead
        jp c,Fail
        ld hl,(PROOF_REQUEST+NucleusObjectRequestHandle)
        call SetReadTransfer
        ld bc,5
        ld (PROOF_REQUEST+NucleusObjectRequestLength),bc
        call ObjectCall
        jp c,Fail
        ld hl,PROOF_READ_BUFFER
        ld de,ReplacementBytes
        ld b,5
VerifyReplacementLoop:
        ld a,(de)
        cp (hl)
        jp nz,Fail
        inc de
        inc hl
        djnz VerifyReplacementLoop
        ret

FillPattern:
        ld hl,PROOF_WRITE_BUFFER
        ld bc,513
        xor a
FillPatternLoop:
        ld (hl),a
        inc hl
        inc a
        dec bc
        ld d,a
        ld a,b
        or c
        ld a,d
        jr nz,FillPatternLoop
        ret

CheckPattern:
        ld hl,PROOF_READ_BUFFER
        ld bc,513
        xor a
CheckPatternLoop:
        cp (hl)
        ret nz
        inc hl
        inc a
        dec bc
        ld d,a
        ld a,b
        or c
        ld a,d
        jr nz,CheckPatternLoop
        xor a
        ret

AlphaName:
        .db "src/alpha.nu"
AlphaNameEnd:
ReplacementBytes:
        .db 0x00,0x1A,0x7F,0x80,0xFF
