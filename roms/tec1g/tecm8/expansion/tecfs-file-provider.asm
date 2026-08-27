; Read-only shared tool-service provider for ordinary TEC-FS files.
;
; ZT_FILE names a file with one binary byte: its TEC-FS catalogue file id.
; The provider has one live handle, but a client may open and close any of the
; 256 binary file ids in sequence. Source-part count is therefore independent
; of the live-handle count. Mutable state occupies 3CD0h..3CEFh; the existing
; object provider's synchronous 512-byte sector buffer is reused for transport.

.routine in HL out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsFileImpl:
        ld (TFS_FILE_REQUEST_PTR),hl
        ld a,TFS_BRIDGE_BANK
        ld (TFS_PARAM_DRIVER_BANK),a
        ld hl,TFS_MON3_FILE_DRIVER
        ld (TFS_PARAM_DRIVER_ADDR_LO),hl
        call tecfsFileEnsureState
        call tecfsFileValidateBase
        ret c
        ld ix,(TFS_FILE_REQUEST_PTR)
        ld a,(ix+ZT_FOP)
        cp ZT_ABORT+1
        jp nc,tecfsFileInvalid
        cp ZT_OPEN
        jr z,tecfsFileOpenRead
        cp ZT_READ
        jp z,tecfsFileRead
        cp ZT_REW
        jp z,tecfsFileRewind
        cp ZT_SEEK
        jp z,tecfsFileSeek
        cp ZT_CLOSE
        jp z,tecfsFileClose
        jp tecfsFileUnsupported

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsFileEnsureState:
        ld hl,(TFS_FILE_STATE_MAGIC)
        ld de,0x4654
        or a
        sbc hl,de
        ret z
        jp tecfsFileReset

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsFileReset:
        xor a
        ld (TFS_FILE_HANDLE_MODE),a
        ld a,(TFS_FILE_NEXT_TOKEN)
        inc a
        jr nz,tecfsFileResetTokenReady
        inc a
tecfsFileResetTokenReady:
        ld (TFS_FILE_NEXT_TOKEN),a
        ld hl,0x4654
        ld (TFS_FILE_STATE_MAGIC),hl
        xor a
        ret

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsFileValidateBase:
        ld hl,(TFS_FILE_REQUEST_PTR)
        ld bc,ZT_RQLEN
        call tecfsFileValidateRange
        jp c,tecfsFileInvalid
        ld ix,(TFS_FILE_REQUEST_PTR)
        xor a
        ld (ix+ZT_FRES),a
        ld (ix+ZT_FRES+1),a
        ld a,(ix+ZT_FSIZE)
        cp ZT_RQLEN
        jp nz,tecfsFileInvalid
        ld a,(ix+ZT_FABI)
        cp ZT_ABI
        jp nz,tecfsFileInvalid
        ld a,(ix+ZT_FFLG)
        or a
        jp nz,tecfsFileInvalid
        ret

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsFileOpenRead:
        call tecfsFileValidateOpen
        ret c
        ld a,(TFS_FILE_HANDLE_MODE)
        or a
        jp nz,tecfsFileCapacity
        ld ix,(TFS_FILE_REQUEST_PTR)
        ld l,(ix+ZT_FPTR)
        ld h,(ix+ZT_FPTR+1)
        ld a,(hl)
        ld (TFS_FILE_HANDLE_ID),a
        call tecfsFileFindCatalog
        ret c
        ld a,TFS_FILE_HANDLE_READ
        ld (TFS_FILE_HANDLE_MODE),a
        ld a,(TFS_FILE_NEXT_TOKEN)
        inc a
        jr nz,tecfsFileOpenTokenReady
        inc a
tecfsFileOpenTokenReady:
        ld (TFS_FILE_NEXT_TOKEN),a
        ld (TFS_FILE_HANDLE_TOKEN),a
        xor a
        ld (TFS_FILE_HANDLE_CURSOR),a
        ld (TFS_FILE_HANDLE_CURSOR+1),a
        ld ix,(TFS_FILE_REQUEST_PTR)
        ld (ix+ZT_FHND),1
        ld a,(TFS_FILE_HANDLE_TOKEN)
        ld (ix+ZT_FHND+1),a
        jp tecfsFileSuccess

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsFileValidateOpen:
        ld ix,(TFS_FILE_REQUEST_PTR)
        ld a,(ix+ZT_FHND)
        or (ix+ZT_FHND+1)
        jp nz,tecfsFileInvalid
        ld a,(ix+ZT_FOFF)
        or (ix+ZT_FOFF+1)
        or (ix+ZT_FOFF+2)
        or (ix+ZT_FOFF+3)
        jp nz,tecfsFileInvalid
        ld a,(ix+ZT_FLEN)
        cp 1
        jp nz,tecfsFileInvalid
        ld a,(ix+ZT_FLEN+1)
        or a
        jp nz,tecfsFileInvalid
        ld l,(ix+ZT_FPTR)
        ld h,(ix+ZT_FPTR+1)
        ld bc,1
        call tecfsFileValidateRange
        jp c,tecfsFileInvalid
        ret

; Scan all 256 ordinary catalogue records for the binary file id. A matching
; record publishes a 16-bit length and first block into the single live handle.
.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsFileFindCatalog:
        ld a,TFS_FILE_CATALOG_SECTOR
        ld (TFS_FILE_SCAN_SECTOR),a
tecfsFileFindSector:
        ld l,a
        ld h,0
        ld (TFS_FILE_IO_SECTOR),hl
        call tecfsFileReadIoSector
        ret c
        ld iy,TFS_OBJECT_SECTOR_BUFFER
        ld b,TFS_FILE_ENTRIES_PER_SECTOR
tecfsFileFindEntry:
        ld a,(iy+TFS_CATALOG_OFFSET_STATUS)
        cp TFS_ENTRY_STATUS_ACTIVE
        jr nz,tecfsFileFindNextEntry
        ld a,(TFS_FILE_HANDLE_ID)
        cp (iy+TFS_CATALOG_OFFSET_FILE_ID)
        jr z,tecfsFileCatalogFound
tecfsFileFindNextEntry:
        ld de,TFS_CATALOG_ENTRY_BYTES
        add iy,de
        djnz tecfsFileFindEntry
        ld a,(TFS_FILE_SCAN_SECTOR)
        inc a
        ld (TFS_FILE_SCAN_SECTOR),a
        cp TFS_FILE_CATALOG_SECTOR+TFS_FILE_CATALOG_SECTORS
        jr c,tecfsFileFindSector
        jp tecfsFileNotFound

tecfsFileCatalogFound:
        ld a,(iy+TFS_CATALOG_OFFSET_FILE_SIZE+2)
        or (iy+TFS_CATALOG_OFFSET_FILE_SIZE+3)
        jp nz,tecfsFileCapacity
        ld l,(iy+TFS_CATALOG_OFFSET_FILE_SIZE)
        ld h,(iy+TFS_CATALOG_OFFSET_FILE_SIZE+1)
        ld (TFS_FILE_HANDLE_LENGTH),hl
        ld l,(iy+TFS_CATALOG_OFFSET_FIRST_BLOCK)
        ld h,(iy+TFS_CATALOG_OFFSET_FIRST_BLOCK+1)
        call tecfsFileValidateDataBlock
        jp c,tecfsFileStorage
        ld (TFS_FILE_HANDLE_FIRST_BLOCK),hl
        or a
        ret

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsFileRead:
        call tecfsFileValidateTransfer
        ret c
        call tecfsFileBeginTransfer
        ld hl,(TFS_FILE_XFER_CURSOR)
        ld de,(TFS_FILE_HANDLE_LENGTH)
        or a
        sbc hl,de
        jp nc,tecfsFileTransferSuccess
        add hl,de
        ex de,hl
        ld hl,(TFS_FILE_HANDLE_LENGTH)
        or a
        sbc hl,de
        ex de,hl
        ld hl,(TFS_FILE_XFER_REMAIN)
        or a
        sbc hl,de
        jr c,tecfsFileReadLengthReady
        ld (TFS_FILE_XFER_REMAIN),de
tecfsFileReadLengthReady:
        ld hl,(TFS_FILE_XFER_REMAIN)
        ld a,h
        or l
        jp z,tecfsFileTransferSuccess
        call tecfsFileResolveCursorBlock
        jp c,tecfsFileTransferFailure
tecfsFileReadLoop:
        call tecfsFilePrepareDataSector
        call tecfsFileReadIoSector
        jp c,tecfsFileTransferFailure
        call tecfsFileChooseChunk
        ld hl,TFS_OBJECT_SECTOR_BUFFER
        ld de,(TFS_FILE_XFER_OFFSET)
        add hl,de
        ld de,(TFS_FILE_XFER_PTR)
        ld bc,(TFS_FILE_XFER_CHUNK)
        ldir
        call tecfsFileAdvanceTransfer
        ld hl,(TFS_FILE_XFER_REMAIN)
        ld a,h
        or l
        jp z,tecfsFileTransferSuccess
        ld hl,(TFS_FILE_XFER_CURSOR)
        ld a,h
        and 0x0F
        or l
        jr nz,tecfsFileReadLoop
        ld hl,(TFS_FILE_CURRENT_BLOCK)
        call tecfsFileNextBlock
        jp c,tecfsFileTransferFailure
        ld (TFS_FILE_CURRENT_BLOCK),hl
        jr tecfsFileReadLoop

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsFileValidateTransfer:
        ld ix,(TFS_FILE_REQUEST_PTR)
        ld a,(ix+ZT_FOFF)
        or (ix+ZT_FOFF+1)
        or (ix+ZT_FOFF+2)
        or (ix+ZT_FOFF+3)
        jp nz,tecfsFileInvalid
        call tecfsFileValidateHandle
        ret c
        ld c,(ix+ZT_FLEN)
        ld b,(ix+ZT_FLEN+1)
        ld l,(ix+ZT_FPTR)
        ld h,(ix+ZT_FPTR+1)
        ld a,b
        or c
        ret z
        call tecfsFileValidateRange
        jp c,tecfsFileInvalid
        ret

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsFileBeginTransfer:
        ld ix,(TFS_FILE_REQUEST_PTR)
        ld l,(ix+ZT_FPTR)
        ld h,(ix+ZT_FPTR+1)
        ld (TFS_FILE_XFER_PTR),hl
        ld l,(ix+ZT_FLEN)
        ld h,(ix+ZT_FLEN+1)
        ld (TFS_FILE_XFER_REMAIN),hl
        ld hl,0
        ld (TFS_FILE_XFER_RESULT),hl
        ld hl,(TFS_FILE_HANDLE_CURSOR)
        ld (TFS_FILE_XFER_CURSOR),hl
        ret

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsFileResolveCursorBlock:
        ld hl,(TFS_FILE_HANDLE_FIRST_BLOCK)
        ld (TFS_FILE_CURRENT_BLOCK),hl
        ld hl,(TFS_FILE_XFER_CURSOR)
        ld a,h
        rrca
        rrca
        rrca
        rrca
        and 0x0F
        ld (TFS_FILE_BLOCK_STEPS),a
tecfsFileResolveCursorLoop:
        ld a,(TFS_FILE_BLOCK_STEPS)
        or a
        ret z
        ld hl,(TFS_FILE_CURRENT_BLOCK)
        call tecfsFileNextBlock
        ret c
        ld (TFS_FILE_CURRENT_BLOCK),hl
        ld a,(TFS_FILE_BLOCK_STEPS)
        dec a
        ld (TFS_FILE_BLOCK_STEPS),a
        jr tecfsFileResolveCursorLoop

; Follow one TM8 allocation entry. Ordinary files may use blocks 12..255 or
; 512..1023; the private object arena reserves 10..11 and 256..511.
.routine in HL out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsFileNextBlock:
        call tecfsFileValidateDataBlock
        ret c
        ld (TFS_FILE_CURRENT_BLOCK),hl
        ld a,h
        add a,TFS_FILE_ALLOCATION_SECTOR
        ld l,a
        ld h,0
        ld (TFS_FILE_IO_SECTOR),hl
        call tecfsFileReadIoSector
        ret c
        ld hl,(TFS_FILE_CURRENT_BLOCK)
        ld a,l
        add a,a
        ld l,a
        ld h,0
        jr nc,tecfsFileAllocationOffsetReady
        inc h
tecfsFileAllocationOffsetReady:
        ld de,TFS_OBJECT_SECTOR_BUFFER
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        call tecfsFileValidateDataBlock
        ret

.routine in HL out A,HL,carry,zero clobbers sign,parity,halfCarry
tecfsFileValidateDataBlock:
        ld a,h
        cp 4
        jr nc,tecfsFileDataBlockInvalid
        or a
        jr nz,tecfsFileDataBlockHigh
        ld a,l
        cp 12
        jr c,tecfsFileDataBlockInvalid
        or a
        ret
tecfsFileDataBlockHigh:
        cp 1
        jr z,tecfsFileDataBlockInvalid
        or a
        ret
tecfsFileDataBlockInvalid:
        scf
        ret

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsFilePrepareDataSector:
        ld hl,(TFS_FILE_CURRENT_BLOCK)
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,(TFS_FILE_XFER_CURSOR)
        ld a,d
        srl a
        and 7
        ld e,a
        ld d,0
        add hl,de
        ld (TFS_FILE_IO_SECTOR),hl
        ld hl,(TFS_FILE_XFER_CURSOR)
        ld a,h
        and 1
        ld h,a
        ld (TFS_FILE_XFER_OFFSET),hl
        ret

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsFileChooseChunk:
        ld hl,512
        ld de,(TFS_FILE_XFER_OFFSET)
        or a
        sbc hl,de
        ex de,hl
        ld hl,(TFS_FILE_XFER_REMAIN)
        or a
        sbc hl,de
        jr c,tecfsFileChunkRemaining
        ld (TFS_FILE_XFER_CHUNK),de
        ret
tecfsFileChunkRemaining:
        add hl,de
        ld (TFS_FILE_XFER_CHUNK),hl
        ret

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsFileAdvanceTransfer:
        ld de,(TFS_FILE_XFER_CHUNK)
        ld hl,(TFS_FILE_XFER_CURSOR)
        add hl,de
        ld (TFS_FILE_XFER_CURSOR),hl
        ld hl,(TFS_FILE_XFER_PTR)
        add hl,de
        ld (TFS_FILE_XFER_PTR),hl
        ld hl,(TFS_FILE_XFER_RESULT)
        add hl,de
        ld (TFS_FILE_XFER_RESULT),hl
        ld hl,(TFS_FILE_XFER_REMAIN)
        or a
        sbc hl,de
        ld (TFS_FILE_XFER_REMAIN),hl
        ret

tecfsFileTransferSuccess:
        ld hl,(TFS_FILE_XFER_CURSOR)
        ld (TFS_FILE_HANDLE_CURSOR),hl
        ld hl,(TFS_FILE_XFER_RESULT)
        ld ix,(TFS_FILE_REQUEST_PTR)
        ld (ix+ZT_FRES),l
        ld (ix+ZT_FRES+1),h
        jp tecfsFileSuccess

tecfsFileTransferFailure:
        ld ix,(TFS_FILE_REQUEST_PTR)
        xor a
        ld (ix+ZT_FRES),a
        ld (ix+ZT_FRES+1),a
        ld a,ZT_STORE
        jp tecfsFileFailure

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsFileRewind:
        call tecfsFileValidateSimple
        ret c
        call tecfsFileValidateHandle
        ret c
        xor a
        ld (TFS_FILE_HANDLE_CURSOR),a
        ld (TFS_FILE_HANDLE_CURSOR+1),a
        jp tecfsFileSuccess

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsFileSeek:
        ld ix,(TFS_FILE_REQUEST_PTR)
        ld a,(ix+ZT_FPTR)
        or (ix+ZT_FPTR+1)
        or (ix+ZT_FLEN)
        or (ix+ZT_FLEN+1)
        jp nz,tecfsFileInvalid
        call tecfsFileValidateHandle
        ret c
        ld a,(ix+ZT_FOFF+2)
        or (ix+ZT_FOFF+3)
        jp nz,tecfsFileUnsupported
        ld l,(ix+ZT_FOFF)
        ld h,(ix+ZT_FOFF+1)
        ld de,(TFS_FILE_HANDLE_LENGTH)
        push hl
        or a
        sbc hl,de
        pop hl
        jp c,tecfsFileSeekStore
        jp nz,tecfsFileUnsupported
tecfsFileSeekStore:
        ld (TFS_FILE_HANDLE_CURSOR),hl
        jp tecfsFileSuccess

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsFileClose:
        call tecfsFileValidateSimple
        ret c
        call tecfsFileValidateHandle
        ret c
        xor a
        ld (TFS_FILE_HANDLE_MODE),a
        jp tecfsFileSuccess

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsFileValidateSimple:
        ld ix,(TFS_FILE_REQUEST_PTR)
        ld a,(ix+ZT_FPTR)
        or (ix+ZT_FPTR+1)
        or (ix+ZT_FLEN)
        or (ix+ZT_FLEN+1)
        or (ix+ZT_FOFF)
        or (ix+ZT_FOFF+1)
        or (ix+ZT_FOFF+2)
        or (ix+ZT_FOFF+3)
        jp nz,tecfsFileInvalid
        ret

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsFileValidateHandle:
        ld ix,(TFS_FILE_REQUEST_PTR)
        ld a,(ix+ZT_FHND)
        cp 1
        jp nz,tecfsFileInvalid
        ld a,(TFS_FILE_HANDLE_MODE)
        cp TFS_FILE_HANDLE_READ
        jp nz,tecfsFileInvalid
        ld a,(ix+ZT_FHND+1)
        ld hl,TFS_FILE_HANDLE_TOKEN
        cp (hl)
        jp nz,tecfsFileInvalid
        ret

; Common-visible memory is 0800h..7FFFh. The end is half-open, so a transfer
; ending exactly at 8000h is valid while arithmetic wrap is not.
.routine in BC,HL out A,BC,HL,carry,zero clobbers sign,parity,halfCarry
tecfsFileValidateRange:
        ld a,h
        cp 0x08
        jr c,tecfsFileRangeInvalid
        cp 0x80
        jr nc,tecfsFileRangeInvalid
        add hl,bc
        jr c,tecfsFileRangeInvalid
        ld a,h
        cp 0x80
        jr c,tecfsFileRangeValid
        jr nz,tecfsFileRangeInvalid
        ld a,l
        or a
        jr nz,tecfsFileRangeInvalid
tecfsFileRangeValid:
        or a
        ret
tecfsFileRangeInvalid:
        scf
        ret

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsFileReadIoSector:
        ld hl,TFS_OBJECT_SECTOR_BUFFER
        ld (TFS_PARAM_BUFFER_LO),hl
        ld hl,(TFS_FILE_IO_SECTOR)
        ld (TFS_PARAM_SECTOR_0),hl
        ld hl,0
        ld (TFS_PARAM_SECTOR_2),hl
        call tecfsReadSectorImpl
        jr c,tecfsFileStorage
        xor a
        ret

tecfsFileSuccess:
        xor a
        ret
tecfsFileInvalid:
        ld a,ZT_INV
        jr tecfsFileFailure
tecfsFileNotFound:
        ld a,ZT_NF
        jr tecfsFileFailure
tecfsFileCapacity:
        ld a,ZT_CAP
        jr tecfsFileFailure
tecfsFileStorage:
        ld a,ZT_STORE
        jr tecfsFileFailure
tecfsFileUnsupported:
        ld a,ZT_UNSUP
tecfsFileFailure:
        scf
        ret
