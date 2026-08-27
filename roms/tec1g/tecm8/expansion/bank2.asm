; TECM8 expansion ROM physical bank 2: TEC-FS service skeleton.

        .include "bank_ops.asmi"

        .org    0x8000

EXP_BANK          .equ    0x02
EXP_VERSION       .equ    0x01
TFS_VOLUME_MIB              .equ    128
TFS_BLOCK_BYTES             .equ    4096
TFS_VOLUME_BLOCKS           .equ    32768
TFS_USER_VOLUMES            .equ    30
TFS_SPARE_VOLUME            .equ    30
TFS_TOTAL_VOLUMES           .equ    31

Tecm8ExpansionBank2Entry:
        cp ABI_PROBE_NESTED
        jp z,BankAbiNestedTarget
        cp TFS_SVC_MOUNT
        jp z,tecfsMountImpl
        cp TFS_SVC_SELECT_VOLUME
        jp z,tecfsSelectVolumeImpl
        cp TFS_SVC_READ
        jp z,tecfsReadSectorImpl
        cp TFS_SVC_WRITE
        jp z,tecfsWriteSectorImpl
        cp TFS_SVC_LOAD_RANGE
        jp z,tecfsUnsupported
        cp TFS_SVC_SAVE_RANGE
        jp z,tecfsUnsupported
        cp TFS_SVC_MAP_BLOCK
        jp z,tecfsMapBlockImpl
        cp TFS_SVC_TRANSLATE_SECTOR
        jp z,tecfsTranslateSectorImpl
        cp TFS_SVC_FORMAT_LOCATOR
        jp z,tecfsFormatLocatorImpl
        cp TFS_SVC_READ_LOCATOR
        jp z,tecfsReadLocatorImpl
        cp TFS_SVC_FORMAT_META_RECORD
        jp z,tecfsFormatMetaRecordImpl
        cp TFS_SVC_PATCH_META_RECORD
        jp z,tecfsPatchMetaRecordImpl
        cp TFS_SVC_DECODE_CATALOG
        jp z,tecfsDecodeCatalogImpl
        cp TFS_SVC_SUMMARIZE_CATALOG
        jp z,tecfsSummarizeCatalogImpl
        cp TFS_SVC_NEXT_CATALOG
        jp z,tecfsNextCatalogImpl
        cp TFS_SVC_OBJECT
        jp z,tecfsObjectImpl
        cp TFS_SVC_FILE
        jp z,tecfsFileImpl
        ld a,SVC_ERR_UNKNOWN
        scf
        ret

tecfsMount:
        jp tecfsMountImpl

tecfsSelectVolume:
        jp tecfsSelectVolumeImpl

tecfsRead:
        jp tecfsReadSectorImpl

tecfsWrite:
        jp tecfsWriteSectorImpl

tecfsLoadRange:
        jp tecfsUnsupported

tecfsSaveRange:
        jp tecfsUnsupported

tecfsMapBlock:
        jp tecfsMapBlockImpl

tecfsTranslateSector:
        jp tecfsTranslateSectorImpl

tecfsFormatLocator:
        jp tecfsFormatLocatorImpl

tecfsReadLocator:
        jp tecfsReadLocatorImpl

tecfsFormatMetaRecord:
        jp tecfsFormatMetaRecordImpl

tecfsPatchMetaRecord:
        jp tecfsPatchMetaRecordImpl

tecfsDecodeCatalog:
        jp tecfsDecodeCatalogImpl

tecfsSummarizeCatalog:
        jp tecfsSummarizeCatalogImpl

tecfsNextCatalog:
        jp tecfsNextCatalogImpl

BankAbiNestedTarget:
        ld c,MON_SYS_GET
        .expectout A
        rst 10H
        ld (ABI_TRACE_8),a
        ld a,0xB2
        ret

tecfsMountImpl:
        call tecfsObjectReset
        call tecfsFileReset
        xor a
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        ld a,TFS_VOLUME_MIB
        ld (TFS_PARAM_VOLUME_MIB),a
        ld hl,TFS_BLOCK_BYTES
        ld (TFS_PARAM_BLOCK_BYTES_LO),hl
        ld hl,TFS_VOLUME_BLOCKS
        ld (TFS_PARAM_VOLUME_BLOCKS_LO),hl
        ld a,TFS_USER_VOLUMES
        ld (TFS_PARAM_USER_VOLUMES),a
        ld a,TFS_SPARE_VOLUME
        ld (TFS_PARAM_SPARE_VOLUME),a
        ld a,TFS_TOTAL_VOLUMES
        ld (TFS_PARAM_TOTAL_VOLUMES),a
        ld a,TFS_LOC_LBA_0
        ld (TFS_PARAM_LOCATOR_SECTOR_0),a
        ld a,TFS_LOC_LBA_1
        ld (TFS_PARAM_LOCATOR_SECTOR_1),a
        ld a,TFS_LOC_LBA_2
        ld (TFS_PARAM_LOCATOR_SECTOR_2),a
        ld a,TFS_LOC_LBA_3
        ld (TFS_PARAM_LOCATOR_SECTOR_3),a
        ld a,TFS_VOLUME_SECTORS_0
        ld (TFS_PARAM_VOLUME_SECTORS_0),a
        ld a,TFS_VOLUME_SECTORS_1
        ld (TFS_PARAM_VOLUME_SECTORS_1),a
        ld a,TFS_VOLUME_SECTORS_2
        ld (TFS_PARAM_VOLUME_SECTORS_2),a
        ld a,TFS_VOLUME_SECTORS_3
        ld (TFS_PARAM_VOLUME_SECTORS_3),a
        ld a,TFS_BRIDGE_BANK
        ld (TFS_PARAM_DRIVER_BANK),a
        ld hl,TFS_MON3_FILE_DRIVER
        ld (TFS_PARAM_DRIVER_ADDR_LO),hl
        ld a,0x82
        or a
        ret

tecfsSelectVolumeImpl:
        ld a,(TFS_PARAM_REQUEST_VOLUME)
        cp TFS_TOTAL_VOLUMES
        jr nc,tecfsBadVolume
        ld (TFS_PARAM_ACTIVE_VOLUME),a
        xor a
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        ld a,0x82
        or a
        ret

tecfsBadVolume:
        ld a,TFS_ERR_BAD_VOLUME
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        scf
        ret

tecfsMapBlockImpl:
        ld a,(TFS_PARAM_BLOCK_INDEX_HI)
        bit 7,a
        jr nz,tecfsBadBlock
        ld d,a
        and 0x60
        rrca
        rrca
        rrca
        rrca
        rrca
        ld e,a
        ld a,(TFS_PARAM_ACTIVE_VOLUME)
        cp TFS_TOTAL_VOLUMES
        jr nc,tecfsBadVolume
        add a,a
        add a,a
        add a,e
        ld (TFS_PARAM_SECTOR_2),a
        xor a
        ld (TFS_PARAM_SECTOR_3),a
        ld hl,(TFS_PARAM_BLOCK_INDEX_LO)
        add hl,hl
        add hl,hl
        add hl,hl
        ld (TFS_PARAM_SECTOR_0),hl
        xor a
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        ld a,0x82
        or a
        ret

tecfsBadBlock:
        ld a,TFS_ERR_BAD_BLOCK
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        scf
        ret

tecfsTranslateSectorImpl:
        call tecfsValidateSector
        jp c,tecfsBadSector
        ld hl,(TFS_PARAM_SECTOR_0)
        ld de,TFS_IMAGE_BASE_LBA_0 + (TFS_IMAGE_BASE_LBA_1 * 256)
        add hl,de
        ld (TFS_PARAM_SECTOR_0),hl
        ld a,(TFS_PARAM_SECTOR_2)
        adc a,TFS_IMAGE_BASE_LBA_2
        ld (TFS_PARAM_SECTOR_2),a
        ld a,(TFS_PARAM_SECTOR_3)
        adc a,TFS_IMAGE_BASE_LBA_3
        ld (TFS_PARAM_SECTOR_3),a
        xor a
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        ld a,0x82
        or a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsReadSectorImpl:
        ld a,TFS_DRIVER_OP_READ
        jr tecfsSectorIoWithDriverOp

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsWriteSectorImpl:
        ld a,TFS_DRIVER_OP_WRITE
        jr tecfsSectorIoWithDriverOp

tecfsSectorIoWithDriverOp:
        ld (TFS_PARAM_DRIVER_OP),a
        call tecfsValidateCardSector
        jp c,tecfsBadSector
        ld hl,(TFS_PARAM_BUFFER_LO)
        ld a,h
        or l
        jp z,tecfsBadBuffer
        call tecfsSectorDriverHook
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsSectorDriverHook:
        ld a,(TFS_PARAM_DRIVER_ADDR_LO)
        ld l,a
        ld a,(TFS_PARAM_DRIVER_ADDR_HI)
        ld h,a
        or l
        jr z,tecfsNoSectorDriver
        push ix
        push iy
        ld a,(TFS_PARAM_DRIVER_OP)
        push hl
        push de
        push af
        ld a,(TFS_PARAM_DRIVER_BANK)
        ld b,a
        ld c,MON_BANK_CALL
        rst 10H
        pop iy
        pop ix
        ret

tecfsNoSectorDriver:
        ld a,TFS_ERR_NO_DRIVER
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        scf
        ret

tecfsFormatLocatorImpl:
        ld hl,(TFS_PARAM_BUFFER_LO)
        ld a,h
        or l
        jp z,tecfsBadBuffer
        ld a,TFS_LOC_MAGIC_0
        ld (hl),a
        inc hl
        ld a,TFS_LOC_MAGIC_1
        ld (hl),a
        inc hl
        ld a,TFS_LOC_MAGIC_2
        ld (hl),a
        inc hl
        ld a,TFS_LOC_MAGIC_3
        ld (hl),a
        inc hl
        ld a,TFS_LOC_VERSION
        ld (hl),a
        inc hl
        ld a,TFS_LOC_ENTRY_BYTES
        ld (hl),a
        inc hl
        ld a,TFS_TOTAL_VOLUMES
        ld (hl),a
        inc hl
        ld a,TFS_USER_VOLUMES
        ld (hl),a
        inc hl
        ld a,TFS_SPARE_VOLUME
        ld (hl),a
        inc hl
        ld a,TFS_VOLUME_SECTORS_0
        ld (hl),a
        inc hl
        ld a,TFS_VOLUME_SECTORS_1
        ld (hl),a
        inc hl
        ld a,TFS_VOLUME_SECTORS_2
        ld (hl),a
        inc hl
        ld a,TFS_VOLUME_SECTORS_3
        ld (hl),a
        xor a
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        ld a,0x82
        or a
        ret

tecfsReadLocatorImpl:
        ld hl,(TFS_PARAM_BUFFER_LO)
        ld a,h
        or l
        jp z,tecfsBadBuffer
        ld a,(hl)
        cp TFS_LOC_MAGIC_0
        jp nz,tecfsBadLocator
        inc hl
        ld a,(hl)
        cp TFS_LOC_MAGIC_1
        jp nz,tecfsBadLocator
        inc hl
        ld a,(hl)
        cp TFS_LOC_MAGIC_2
        jp nz,tecfsBadLocator
        inc hl
        ld a,(hl)
        cp TFS_LOC_MAGIC_3
        jp nz,tecfsBadLocator
        inc hl
        ld a,(hl)
        cp TFS_LOC_VERSION
        jp nz,tecfsBadLocator
        inc hl
        ld a,(hl)
        ld (TFS_PARAM_LAST_ERROR),a
        inc hl
        ld a,(hl)
        ld (TFS_PARAM_TOTAL_VOLUMES),a
        inc hl
        ld a,(hl)
        ld (TFS_PARAM_USER_VOLUMES),a
        inc hl
        ld a,(hl)
        ld (TFS_PARAM_SPARE_VOLUME),a
        inc hl
        ld a,(hl)
        ld (TFS_PARAM_VOLUME_SECTORS_0),a
        inc hl
        ld a,(hl)
        ld (TFS_PARAM_VOLUME_SECTORS_1),a
        inc hl
        ld a,(hl)
        ld (TFS_PARAM_VOLUME_SECTORS_2),a
        inc hl
        ld a,(hl)
        ld (TFS_PARAM_VOLUME_SECTORS_3),a
        xor a
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        ld a,0x82
        or a
        ret

tecfsFormatMetaRecordImpl:
        ld hl,(TFS_PARAM_BUFFER_LO)
        ld a,h
        or l
        jp z,tecfsBadBuffer
        push hl
        ld b,TFS_META_RECORD_BYTES
        xor a
tecfsFormatMetaRecordClear:
        ld (hl),a
        inc hl
        djnz tecfsFormatMetaRecordClear
        pop hl
        ld a,TFS_META_MAGIC_0
        ld (hl),a
        inc hl
        ld a,TFS_META_MAGIC_1
        ld (hl),a
        inc hl
        ld a,TFS_META_MAGIC_2
        ld (hl),a
        inc hl
        ld a,TFS_META_MAGIC_3
        ld (hl),a
        inc hl
        ld a,TFS_META_VERSION
        ld (hl),a
        inc hl
        ld a,TFS_META_RECORD_BYTES
        ld (hl),a
        inc hl
        ld a,TFS_FILE_PROJECT
        ld (hl),a
        xor a
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        ld a,0x82
        or a
        ret

tecfsPatchMetaRecordImpl:
        ld hl,(TFS_PARAM_BUFFER_LO)
        ld a,h
        or l
        jp z,tecfsBadBuffer
        ld de,TFS_META_OFFSET_FILE_TYPE
        add hl,de
        ld a,(TFS_META_PATCH_FILE_TYPE)
        ld (hl),a
        inc hl
        ld a,(TFS_META_PATCH_FLAGS)
        ld (hl),a
        inc hl
        ld a,(TFS_META_PATCH_LOAD_LO)
        ld (hl),a
        inc hl
        ld a,(TFS_META_PATCH_LOAD_HI)
        ld (hl),a
        inc hl
        ld a,(TFS_META_PATCH_END_LO)
        ld (hl),a
        inc hl
        ld a,(TFS_META_PATCH_END_HI)
        ld (hl),a
        inc hl
        ld a,(TFS_META_PATCH_RUN_LO)
        ld (hl),a
        inc hl
        ld a,(TFS_META_PATCH_RUN_HI)
        ld (hl),a
        inc hl
        ld a,(TFS_META_PATCH_HW_LO)
        ld (hl),a
        inc hl
        ld a,(TFS_META_PATCH_HW_HI)
        ld (hl),a
        ld de,TFS_META_OFFSET_NAME_REF-TFS_META_OFFSET_REQUIRED_HW-1
        add hl,de
        ld a,(TFS_META_PATCH_NAME_REF_LO)
        ld (hl),a
        inc hl
        ld a,(TFS_META_PATCH_NAME_REF_HI)
        ld (hl),a
        xor a
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        ld a,0x82
        or a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,D,E,H,L
tecfsDecodeCatalogImpl:
        ld hl,(TFS_PARAM_BUFFER_LO)
        ld a,h
        or l
        jp z,tecfsBadBuffer
        ld a,(hl)
        cp TFS_ENTRY_STATUS_ACTIVE
        jp nz,tecfsBadCatalog
        inc hl
        ld a,(hl)
        ld (TFS_PARAM_ENTRY_FILE_ID),a
        inc hl
        ld a,(hl)
        ld (TFS_PARAM_ENTRY_PREFIX_ID),a
        inc hl
        ld a,(hl)
        or a
        jp z,tecfsBadCatalog
        cp TFS_CATALOG_NAME_BYTES+1
        jp nc,tecfsBadCatalog
        ld (TFS_PARAM_ENTRY_NAME_LEN),a
        ld hl,(TFS_PARAM_BUFFER_LO)
        ld de,TFS_CATALOG_OFFSET_FIRST_BLOCK
        add hl,de
        ld a,(hl)
        ld (TFS_PARAM_ENTRY_FIRST_BLOCK_LO),a
        inc hl
        ld a,(hl)
        ld (TFS_PARAM_ENTRY_FIRST_BLOCK_HI),a
        inc hl
        ld a,(hl)
        ld (TFS_PARAM_ENTRY_SIZE_0),a
        inc hl
        ld a,(hl)
        ld (TFS_PARAM_ENTRY_SIZE_1),a
        inc hl
        ld a,(hl)
        ld (TFS_PARAM_ENTRY_SIZE_2),a
        inc hl
        ld a,(hl)
        ld (TFS_PARAM_ENTRY_SIZE_3),a
        ld hl,(TFS_PARAM_BUFFER_LO)
        ld de,TFS_CATALOG_OFFSET_FILE_TYPE
        add hl,de
        ld a,(hl)
        ld (TFS_PARAM_ENTRY_FILE_TYPE),a
        xor a
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        ld a,0x82
        or a
        ret

tecfsSummarizeCatalogImpl:
        call tecfsClearSummary
        ld hl,(TFS_PARAM_BUFFER_LO)
        ld a,h
        or l
        jp z,tecfsBadBuffer
        ld a,(hl)
        cp TFS_ENTRY_STATUS_ACTIVE
        jr z,tecfsSummarizeActive
        xor a
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        ld a,0x82
        or a
        ret

tecfsSummarizeActive:
        call tecfsDecodeCatalogImpl
        ret c
        ld a,0x01
        ld (TFS_PARAM_SUMMARY_COUNT_LO),a
        xor a
        ld (TFS_PARAM_SUMMARY_COUNT_HI),a
        ld a,(TFS_PARAM_ENTRY_FILE_ID)
        ld (TFS_PARAM_SUMMARY_FIRST_FILE_ID),a
        ld a,(TFS_PARAM_ENTRY_FILE_TYPE)
        ld (TFS_PARAM_SUMMARY_FIRST_FILE_TYPE),a
        ld a,(TFS_PARAM_ENTRY_NAME_LEN)
        ld (TFS_PARAM_SUMMARY_FIRST_NAME_LEN),a
        ld a,TFS_SUMMARY_FLAG_HAS_FIRST
        ld (TFS_PARAM_SUMMARY_FLAGS),a
        ld a,0x82
        or a
        ret

.routine out A,zero clobbers sign,parity,halfCarry,H,L
tecfsClearSummary:
        xor a
        ld (TFS_PARAM_SUMMARY_COUNT_LO),a
        ld (TFS_PARAM_SUMMARY_COUNT_HI),a
        ld (TFS_PARAM_SUMMARY_FIRST_FILE_ID),a
        ld (TFS_PARAM_SUMMARY_FIRST_FILE_TYPE),a
        ld (TFS_PARAM_SUMMARY_FIRST_NAME_LEN),a
        ld (TFS_PARAM_SUMMARY_FLAGS),a
        ret

tecfsNextCatalogImpl:
        ld hl,(TFS_PARAM_BUFFER_LO)
        ld a,h
        or l
        jp z,tecfsBadBuffer
        ld de,TFS_CATALOG_ENTRY_BYTES
        add hl,de
        ld (TFS_PARAM_BUFFER_LO),hl
        xor a
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        ld a,0x82
        or a
        ret

        .include "tecfs-file-provider.asm"

; Common named-object ABI 1 over the private bounded tool arena at the end of
; VOLUME.TM8. The public 91h expansion gateway preserves IX/IY and bank state;
; this bank-local implementation may use both index registers internally.
tecfsObjectImpl:
        ld (TFS_OBJECT_REQUEST_PTR),hl
        ld a,TFS_BRIDGE_BANK
        ld (TFS_PARAM_DRIVER_BANK),a
        ld hl,TFS_MON3_FILE_DRIVER
        ld (TFS_PARAM_DRIVER_ADDR_LO),hl
        call tecfsObjectEnsureState
        call tecfsObjectValidateBase
        ret c
        call tecfsObjectEnsureArena
        ret c
        ld ix,(TFS_OBJECT_REQUEST_PTR)
        ld a,(ix+NucleusObjectRequestOperation)
        cp NucleusObjectAbort+1
        jp nc,tecfsObjectInvalid
        add a,a
        ld e,a
        ld d,0
        ld hl,tecfsObjectDispatch
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        jp (hl)
tecfsObjectDispatch:
        .dw tecfsObjectOpenRead
        .dw tecfsObjectBeginWrite
        .dw tecfsObjectRead
        .dw tecfsObjectWrite
        .dw tecfsObjectRewind
        .dw tecfsObjectSeek
        .dw tecfsObjectClose
        .dw tecfsObjectCommit
        .dw tecfsObjectAbort

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsObjectEnsureState:
        ld hl,(TFS_OBJECT_STATE_MAGIC)
        ld de,0x4F54
        or a
        sbc hl,de
        ret z
        jp tecfsObjectReset
.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsObjectReset:
        ld hl,TFS_OBJECT_HANDLE_TABLE
        ld de,TFS_OBJECT_HANDLE_TABLE+1
        ld bc,TFS_OBJECT_HANDLE_SIZE*TFS_OBJECT_HANDLE_COUNT-1
        xor a
        ld (hl),a
        ldir
        ld a,(TFS_OBJECT_NEXT_TOKEN)
        inc a
        jr nz,tecfsObjectResetTokenReady
        inc a
tecfsObjectResetTokenReady:
        ld (TFS_OBJECT_NEXT_TOKEN),a
        ld hl,0x4F54
        ld (TFS_OBJECT_STATE_MAGIC),hl
        xor a
        ld (TFS_OBJECT_FORMAT_VALID),a
        ret

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
tecfsObjectEnsureArena:
        ld a,(TFS_OBJECT_FORMAT_VALID)
        cp 0xA5
        ret z
        ld hl,8
        ld (TFS_OBJECT_IO_SECTOR),hl
        call tecfsObjectReadIoSector
        ret c
        ld hl,TFS_OBJECT_SECTOR_BUFFER+TFS_OBJECT_DESC_BLOCK*2
        ld b,TFS_OBJECT_DESC_BLOCKS
tecfsObjectCheckArenaFirst:
        ld a,(hl)
        inc hl
        and (hl)
        inc hl
        inc a
        jr nz,tecfsObjectArenaUnavailable
        djnz tecfsObjectCheckArenaFirst
        ld hl,9
        ld (TFS_OBJECT_IO_SECTOR),hl
        call tecfsObjectReadIoSector
        ret c
        ld hl,TFS_OBJECT_SECTOR_BUFFER
        ld b,0
tecfsObjectCheckArenaSecond:
        ld a,(hl)
        inc hl
        and (hl)
        inc hl
        inc a
        jr nz,tecfsObjectArenaUnavailable
        djnz tecfsObjectCheckArenaSecond
        ld a,0xA5
        ld (TFS_OBJECT_FORMAT_VALID),a
        xor a
        ret
tecfsObjectArenaUnavailable:
        ld a,NucleusStatusUnavailable
        scf
        ret

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsObjectValidateBase:
        ld hl,(TFS_OBJECT_REQUEST_PTR)
        ld a,h
        cp 0x08
        jp c,tecfsObjectInvalid
        cp 0x80
        jp nc,tecfsObjectInvalid
        ld de,NucleusObjectRequestSize-1
        add hl,de
        ld a,h
        cp 0x80
        jp nc,tecfsObjectInvalid
        ld ix,(TFS_OBJECT_REQUEST_PTR)
        xor a
        ld (ix+NucleusObjectRequestResult),a
        ld (ix+NucleusObjectRequestResult+1),a
        ld a,(ix+0)
        cp NucleusObjectRequestSize
        jp nz,tecfsObjectInvalid
        ld a,(ix+1)
        cp NucleusObjectAbiVersion
        jp nz,tecfsObjectInvalid
        ld a,(ix+NucleusObjectRequestFlags)
        or a
        jp nz,tecfsObjectInvalid
        ret

tecfsObjectOpenRead:
        call tecfsObjectValidateOpen
        ret c
        call tecfsObjectFindName
        ret c
        or a
        jp nz,tecfsObjectNotFound
        ld a,TFS_OBJECT_HANDLE_READ
        jp tecfsObjectAllocate

tecfsObjectBeginWrite:
        call tecfsObjectValidateOpen
        ret c
        call tecfsObjectWriterNameConflict
        ret c
        call tecfsObjectFindName
        ret c
        or a
        jr nz,tecfsObjectBeginNew
        call tecfsObjectWriterConflict
        ret c
        ld a,(TFS_OBJECT_SELECTED_HALF)
        xor 1
        ld (TFS_OBJECT_SELECTED_HALF),a
        call tecfsObjectSelectedHalfBusy
        jp nz,tecfsObjectConflict
        ld hl,(TFS_OBJECT_SELECTED_GEN)
        inc hl
        ld a,h
        or l
        jp z,tecfsObjectCapacity
        ld (TFS_OBJECT_SELECTED_GEN),hl
        jr tecfsObjectBeginReady
tecfsObjectBeginNew:
        ld a,(TFS_OBJECT_FREE_SLOT)
        cp 0xFF
        jp z,tecfsObjectCapacity
        ld (TFS_OBJECT_SELECTED_SLOT),a
        xor a
        ld (TFS_OBJECT_SELECTED_HALF),a
        ld hl,1
        ld (TFS_OBJECT_SELECTED_GEN),hl
tecfsObjectBeginReady:
        ld hl,0
        ld (TFS_OBJECT_SELECTED_LENGTH),hl
        call tecfsObjectWritePendingDescriptor
        ret c
        ld a,TFS_OBJECT_HANDLE_WRITE
        jp tecfsObjectAllocate

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsObjectValidateOpen:
        ld ix,(TFS_OBJECT_REQUEST_PTR)
        ld a,(ix+NucleusObjectRequestHandle)
        or (ix+NucleusObjectRequestHandle+1)
        jp nz,tecfsObjectInvalid
        ld a,(ix+NucleusObjectRequestOffset)
        or (ix+NucleusObjectRequestOffset+1)
        or (ix+NucleusObjectRequestOffset+2)
        or (ix+NucleusObjectRequestOffset+3)
        jp nz,tecfsObjectInvalid
        ld a,(ix+NucleusObjectRequestLength+1)
        or a
        jp nz,tecfsObjectInvalid
        ld c,(ix+NucleusObjectRequestLength)
        ld a,c
        or a
        jp z,tecfsObjectInvalid
        ld l,(ix+NucleusObjectRequestPointer)
        ld h,(ix+NucleusObjectRequestPointer+1)
        ld b,0
        jp tecfsObjectValidateRange

; Search the descriptor pairs. A=0 means found, A=1 means absent. Carry is
; reserved for storage failure. The first completely free slot is retained.
.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsObjectFindName:
        ld a,0xFF
        ld (TFS_OBJECT_FREE_SLOT),a
        xor a
        ld (TFS_OBJECT_SCAN_SLOT),a
tecfsObjectFindNextSlot:
        xor a
        ld (TFS_OBJECT_CANDIDATE),a
        ld (TFS_OBJECT_SELECTED_HALF),a
        call tecfsObjectLoadDescriptor
        ret c
        call tecfsObjectConsiderDescriptor
        ld a,1
        ld (TFS_OBJECT_SELECTED_HALF),a
        call tecfsObjectLoadDescriptor
        ret c
        call tecfsObjectConsiderDescriptor
        ld a,(TFS_OBJECT_CANDIDATE)
        or a
        jr nz,tecfsObjectFindCompare
        call tecfsObjectScanSlotBusy
        jr nz,tecfsObjectFindAdvance
        ld a,(TFS_OBJECT_FREE_SLOT)
        cp 0xFF
        jr nz,tecfsObjectFindAdvance
        ld a,(TFS_OBJECT_SCAN_SLOT)
        ld (TFS_OBJECT_FREE_SLOT),a
        jr tecfsObjectFindAdvance
tecfsObjectFindCompare:
        ld a,(TFS_OBJECT_CANDIDATE)
        dec a
        ld (TFS_OBJECT_SELECTED_HALF),a
        push af
        call tecfsObjectLoadDescriptor
        pop bc
        ret c
        ld a,b
        ld (TFS_OBJECT_SELECTED_HALF),a
        call tecfsObjectDescriptorNameEqual
        jr nz,tecfsObjectFindAdvance
        ld a,(TFS_OBJECT_SCAN_SLOT)
        ld (TFS_OBJECT_SELECTED_SLOT),a
        xor a
        ret
tecfsObjectFindAdvance:
        ld a,(TFS_OBJECT_SCAN_SLOT)
        inc a
        ld (TFS_OBJECT_SCAN_SLOT),a
        cp TFS_OBJECT_SLOT_COUNT
        jr c,tecfsObjectFindNextSlot
        ld a,1
        or a
        ret

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsObjectConsiderDescriptor:
        or a
        ret nz
        ld hl,TFS_OBJECT_SECTOR_BUFFER+TFS_OBJECT_DESC_GENERATION
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(TFS_OBJECT_CANDIDATE)
        or a
        jr z,tecfsObjectSelectDescriptor
        ld hl,(TFS_OBJECT_SELECTED_GEN)
        or a
        sbc hl,de
        ret nc
tecfsObjectSelectDescriptor:
        ld (TFS_OBJECT_SELECTED_GEN),de
        ld hl,(TFS_OBJECT_SECTOR_BUFFER+TFS_OBJECT_DESC_DATA_LENGTH)
        ld (TFS_OBJECT_SELECTED_LENGTH),hl
        ld a,(TFS_OBJECT_SELECTED_HALF)
        inc a
        ld (TFS_OBJECT_CANDIDATE),a
        dec a
        ld (TFS_OBJECT_SELECTED_HALF),a
        xor a
        ret

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsObjectDescriptorNameEqual:
        ld ix,(TFS_OBJECT_REQUEST_PTR)
        ld a,(TFS_OBJECT_SECTOR_BUFFER+TFS_OBJECT_DESC_NAME_LENGTH)
        cp (ix+NucleusObjectRequestLength)
        ret nz
        ld e,(ix+NucleusObjectRequestPointer)
        ld d,(ix+NucleusObjectRequestPointer+1)
        ld hl,TFS_OBJECT_SECTOR_BUFFER+TFS_OBJECT_DESC_NAME
        ld b,a
tecfsObjectNameCompareLoop:
        ld a,(de)
        cp (hl)
        ret nz
        inc de
        inc hl
        djnz tecfsObjectNameCompareLoop
        xor a
        ret

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsObjectLoadDescriptor:
        call tecfsObjectDescriptorSector
        ld (TFS_OBJECT_IO_SECTOR),hl
        call tecfsObjectReadIoSector
        ret c
        call tecfsObjectValidateDescriptor
        ret

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsObjectDescriptorSector:
        ld a,(TFS_OBJECT_SCAN_SLOT)
        add a,a
        ld l,a
        ld a,(TFS_OBJECT_SELECTED_HALF)
        add a,l
        ld l,a
        ld h,0
        ld de,TFS_OBJECT_DESC_SECTOR
        add hl,de
        ret

; A=0 is a valid committed descriptor; A=1 is an empty, pending, or damaged
; descriptor. Media failures have already returned through carry.
.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsObjectValidateDescriptor:
        ld c,TFS_OBJECT_DESC_MAGIC_2
        jr tecfsObjectValidateDescriptorMagic
.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsObjectValidatePendingDescriptor:
        ld c,TFS_OBJECT_PENDING_MAGIC_2
tecfsObjectValidateDescriptorMagic:
        ld hl,TFS_OBJECT_SECTOR_BUFFER
        ld a,(hl)
        cp TFS_OBJECT_DESC_MAGIC_0
        jr nz,tecfsObjectDescriptorInvalid
        inc hl
        ld a,(hl)
        cp TFS_OBJECT_DESC_MAGIC_1
        jr nz,tecfsObjectDescriptorInvalid
        inc hl
        ld a,(hl)
        cp c
        jr nz,tecfsObjectDescriptorInvalid
        inc hl
        ld a,(hl)
        cp TFS_OBJECT_DESC_MAGIC_3
        jr nz,tecfsObjectDescriptorInvalid
        inc hl
        ld a,(hl)
        cp TFS_OBJECT_DESC_VERSION
        jr nz,tecfsObjectDescriptorInvalid
        inc hl
        ld a,(TFS_OBJECT_SCAN_SLOT)
        cp (hl)
        jr nz,tecfsObjectDescriptorInvalid
        ld a,(TFS_OBJECT_SECTOR_BUFFER+TFS_OBJECT_DESC_HALF)
        ld hl,TFS_OBJECT_SELECTED_HALF
        cp (hl)
        jr nz,tecfsObjectDescriptorInvalid
        ld a,(TFS_OBJECT_SECTOR_BUFFER+TFS_OBJECT_DESC_NAME_LENGTH)
        or a
        jr z,tecfsObjectDescriptorInvalid
        ld hl,TFS_OBJECT_SECTOR_BUFFER
        ld bc,512
        call tecfsObjectSumBytes
        ld a,e
        or a
        jr nz,tecfsObjectDescriptorInvalid
        xor a
        ret
tecfsObjectDescriptorInvalid:
        ld a,1
        or a
        ret

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsObjectWritePendingDescriptor:
        ld hl,TFS_OBJECT_SECTOR_BUFFER
        ld de,TFS_OBJECT_SECTOR_BUFFER+1
        ld bc,511
        xor a
        ld (hl),a
        ldir
        ld a,TFS_OBJECT_DESC_VERSION
        ld (TFS_OBJECT_SECTOR_BUFFER+4),a
        ld a,TFS_OBJECT_DESC_MAGIC_0
        ld (TFS_OBJECT_SECTOR_BUFFER+0),a
        ld a,TFS_OBJECT_DESC_MAGIC_1
        ld (TFS_OBJECT_SECTOR_BUFFER+1),a
        ld a,TFS_OBJECT_PENDING_MAGIC_2
        ld (TFS_OBJECT_SECTOR_BUFFER+2),a
        ld a,TFS_OBJECT_DESC_MAGIC_3
        ld (TFS_OBJECT_SECTOR_BUFFER+3),a
        ld a,(TFS_OBJECT_SELECTED_SLOT)
        ld (TFS_OBJECT_SECTOR_BUFFER+5),a
        ld hl,(TFS_OBJECT_SELECTED_GEN)
        ld (TFS_OBJECT_SECTOR_BUFFER+TFS_OBJECT_DESC_GENERATION),hl
        ld a,(TFS_OBJECT_SELECTED_HALF)
        ld (TFS_OBJECT_SECTOR_BUFFER+TFS_OBJECT_DESC_HALF),a
        ld ix,(TFS_OBJECT_REQUEST_PTR)
        ld a,(ix+NucleusObjectRequestLength)
        ld (TFS_OBJECT_SECTOR_BUFFER+TFS_OBJECT_DESC_NAME_LENGTH),a
        ld l,(ix+NucleusObjectRequestPointer)
        ld h,(ix+NucleusObjectRequestPointer+1)
        ld de,TFS_OBJECT_SECTOR_BUFFER+TFS_OBJECT_DESC_NAME
        ld c,a
        ld b,0
        ldir
        ld a,(TFS_OBJECT_SELECTED_SLOT)
        ld (TFS_OBJECT_SCAN_SLOT),a
        call tecfsObjectSealDescriptor
        call tecfsObjectDescriptorSector
        ld (TFS_OBJECT_IO_SECTOR),hl
        call tecfsObjectWriteIoSector
        ret

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsObjectWriterConflict:
        ld iy,TFS_OBJECT_HANDLE_TABLE
        ld b,TFS_OBJECT_HANDLE_COUNT
tecfsObjectWriterConflictLoop:
        ld a,(iy+TFS_OBJECT_HANDLE_MODE)
        cp TFS_OBJECT_HANDLE_WRITE
        jr nc,tecfsObjectWriterConflictCheck
tecfsObjectWriterConflictNext:
        ld de,TFS_OBJECT_HANDLE_SIZE
        add iy,de
        djnz tecfsObjectWriterConflictLoop
        xor a
        ret
tecfsObjectWriterConflictCheck:
        ld a,(TFS_OBJECT_SELECTED_SLOT)
        cp (iy+TFS_OBJECT_HANDLE_SLOT)
        jr nz,tecfsObjectWriterConflictNext
        jp tecfsObjectConflict

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsObjectWriterNameConflict:
        ld iy,TFS_OBJECT_HANDLE_TABLE
        ld a,TFS_OBJECT_HANDLE_COUNT
        ld (TFS_OBJECT_CANDIDATE),a
tecfsObjectWriterNameLoop:
        ld a,(iy+TFS_OBJECT_HANDLE_MODE)
        cp TFS_OBJECT_HANDLE_WRITE
        jr c,tecfsObjectWriterNameNext
        ld a,(iy+TFS_OBJECT_HANDLE_SLOT)
        ld (TFS_OBJECT_SCAN_SLOT),a
        ld a,(iy+TFS_OBJECT_HANDLE_HALF)
        ld (TFS_OBJECT_SELECTED_HALF),a
        call tecfsObjectLoadDescriptor
        ret c
        call tecfsObjectDescriptorNameEqual
        jp z,tecfsObjectConflict
tecfsObjectWriterNameNext:
        ld de,TFS_OBJECT_HANDLE_SIZE
        add iy,de
        ld a,(TFS_OBJECT_CANDIDATE)
        dec a
        ld (TFS_OBJECT_CANDIDATE),a
        jr nz,tecfsObjectWriterNameLoop
        xor a
        ret

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsObjectScanSlotBusy:
        ld iy,TFS_OBJECT_HANDLE_TABLE
        ld b,TFS_OBJECT_HANDLE_COUNT
tecfsObjectScanSlotBusyLoop:
        ld a,(iy+TFS_OBJECT_HANDLE_MODE)
        cp TFS_OBJECT_HANDLE_WRITE
        jr c,tecfsObjectScanSlotBusyNext
        ld a,(TFS_OBJECT_SCAN_SLOT)
        cp (iy+TFS_OBJECT_HANDLE_SLOT)
        jr z,tecfsObjectBusy
tecfsObjectScanSlotBusyNext:
        ld de,TFS_OBJECT_HANDLE_SIZE
        add iy,de
        djnz tecfsObjectScanSlotBusyLoop
        xor a
        ret

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsObjectSelectedHalfBusy:
        ld iy,TFS_OBJECT_HANDLE_TABLE
        ld b,TFS_OBJECT_HANDLE_COUNT
tecfsObjectSelectedHalfBusyLoop:
        ld a,(iy+TFS_OBJECT_HANDLE_MODE)
        cp TFS_OBJECT_HANDLE_READ
        jr nz,tecfsObjectSelectedHalfBusyNext
        ld a,(TFS_OBJECT_SELECTED_SLOT)
        cp (iy+TFS_OBJECT_HANDLE_SLOT)
        jr nz,tecfsObjectSelectedHalfBusyNext
        ld a,(TFS_OBJECT_SELECTED_HALF)
        cp (iy+TFS_OBJECT_HANDLE_HALF)
        jr z,tecfsObjectBusy
tecfsObjectSelectedHalfBusyNext:
        ld de,TFS_OBJECT_HANDLE_SIZE
        add iy,de
        djnz tecfsObjectSelectedHalfBusyLoop
        xor a
        ret
tecfsObjectBusy:
        ld a,1
        or a
        ret

; Input A is the mode. The selected slot/half/generation/length fields become
; an opaque tokenised handle in the caller's request.
.routine in A out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsObjectAllocate:
        ld c,a
        ld iy,TFS_OBJECT_HANDLE_TABLE
        ld b,TFS_OBJECT_HANDLE_COUNT
        ld a,1
        ld (TFS_OBJECT_SCAN_SLOT),a
tecfsObjectAllocateLoop:
        ld a,(iy+TFS_OBJECT_HANDLE_MODE)
        or a
        jr z,tecfsObjectAllocateFound
        ld de,TFS_OBJECT_HANDLE_SIZE
        add iy,de
        ld a,(TFS_OBJECT_SCAN_SLOT)
        inc a
        ld (TFS_OBJECT_SCAN_SLOT),a
        djnz tecfsObjectAllocateLoop
        jp tecfsObjectCapacity
tecfsObjectAllocateFound:
        ld a,(TFS_OBJECT_NEXT_TOKEN)
        inc a
        jr nz,tecfsObjectAllocateTokenReady
        inc a
tecfsObjectAllocateTokenReady:
        ld (TFS_OBJECT_NEXT_TOKEN),a
        ld (iy+TFS_OBJECT_HANDLE_TOKEN),a
        ld (iy+TFS_OBJECT_HANDLE_MODE),c
        ld a,(TFS_OBJECT_SELECTED_SLOT)
        ld (iy+TFS_OBJECT_HANDLE_SLOT),a
        ld a,(TFS_OBJECT_SELECTED_HALF)
        ld (iy+TFS_OBJECT_HANDLE_HALF),a
        ld hl,(TFS_OBJECT_SELECTED_GEN)
        ld (iy+TFS_OBJECT_HANDLE_GEN),l
        ld (iy+TFS_OBJECT_HANDLE_GEN+1),h
        ld hl,0
        ld (iy+TFS_OBJECT_HANDLE_CURSOR),l
        ld (iy+TFS_OBJECT_HANDLE_CURSOR+1),h
        ld hl,(TFS_OBJECT_SELECTED_LENGTH)
        ld (iy+TFS_OBJECT_HANDLE_LENGTH),l
        ld (iy+TFS_OBJECT_HANDLE_LENGTH+1),h
        ld ix,(TFS_OBJECT_REQUEST_PTR)
        ld a,(TFS_OBJECT_SCAN_SLOT)
        ld e,a
        ld (ix+NucleusObjectRequestHandle),e
        ld a,(TFS_OBJECT_NEXT_TOKEN)
        ld (ix+NucleusObjectRequestHandle+1),a
        jp tecfsObjectSuccess

tecfsObjectRead:
        call tecfsObjectValidateTransfer
        ret c
        ld a,(iy+TFS_OBJECT_HANDLE_MODE)
        cp TFS_OBJECT_HANDLE_POISONED
        jp z,tecfsObjectAccess
        cp TFS_OBJECT_HANDLE_READ
        jr z,tecfsObjectReadReady
        cp TFS_OBJECT_HANDLE_WRITE
        jp nz,tecfsObjectAccess
tecfsObjectReadReady:
        call tecfsObjectBeginTransfer
        ld hl,(TFS_OBJECT_XFER_CURSOR)
        ld de,(TFS_OBJECT_XFER_LENGTH)
        or a
        sbc hl,de
        jp nc,tecfsObjectTransferSuccess
        add hl,de
        ex de,hl
        ld hl,(TFS_OBJECT_XFER_LENGTH)
        or a
        sbc hl,de
        ex de,hl
        ld hl,(TFS_OBJECT_XFER_REMAIN)
        or a
        sbc hl,de
        jr c,tecfsObjectReadLengthReady
        ld (TFS_OBJECT_XFER_REMAIN),de
tecfsObjectReadLengthReady:
        ld hl,(TFS_OBJECT_XFER_REMAIN)
        ld a,h
        or l
        jp z,tecfsObjectTransferSuccess
tecfsObjectReadLoop:
        call tecfsObjectPrepareDataSector
        call tecfsObjectReadIoSector
        jp c,tecfsObjectTransferFailure
        call tecfsObjectChooseChunk
        ld hl,TFS_OBJECT_SECTOR_BUFFER
        ld de,(TFS_OBJECT_XFER_OFFSET)
        add hl,de
        ld de,(TFS_OBJECT_XFER_PTR)
        ld bc,(TFS_OBJECT_XFER_CHUNK)
        ldir
        call tecfsObjectAdvanceTransfer
        ld hl,(TFS_OBJECT_XFER_REMAIN)
        ld a,h
        or l
        jr nz,tecfsObjectReadLoop
        jp tecfsObjectTransferSuccess

tecfsObjectWrite:
        call tecfsObjectValidateTransfer
        ret c
        ld a,(iy+TFS_OBJECT_HANDLE_MODE)
        cp TFS_OBJECT_HANDLE_WRITE
        jp nz,tecfsObjectAccess
        call tecfsObjectBeginTransfer
        ld hl,(TFS_OBJECT_XFER_REMAIN)
        ld a,h
        or l
        jp z,tecfsObjectTransferSuccess
        ld hl,(TFS_OBJECT_XFER_CURSOR)
        ld de,(TFS_OBJECT_XFER_REMAIN)
        add hl,de
        jr c,tecfsObjectWriteCapacity
        ld a,h
        or l
        jr z,tecfsObjectWriteCapacity
tecfsObjectWriteLoop:
        call tecfsObjectPrepareDataSector
        ld hl,(TFS_OBJECT_XFER_CURSOR)
        ld l,0
        res 0,h
        ld de,(TFS_OBJECT_XFER_LENGTH)
        or a
        sbc hl,de
        jr c,tecfsObjectWriteLoadSector
        ld hl,TFS_OBJECT_SECTOR_BUFFER
        ld de,TFS_OBJECT_SECTOR_BUFFER+1
        ld bc,511
        xor a
        ld (hl),a
        ldir
        jr tecfsObjectWriteBufferReady
tecfsObjectWriteLoadSector:
        call tecfsObjectReadIoSector
        jr c,tecfsObjectWriteFailed
tecfsObjectWriteBufferReady:
        call tecfsObjectChooseChunk
        ld hl,(TFS_OBJECT_XFER_PTR)
        ld de,TFS_OBJECT_SECTOR_BUFFER
        ld bc,(TFS_OBJECT_XFER_OFFSET)
        ex de,hl
        add hl,bc
        ex de,hl
        ld bc,(TFS_OBJECT_XFER_CHUNK)
        ldir
        call tecfsObjectWriteIoSector
        jr c,tecfsObjectWriteFailed
        call tecfsObjectAdvanceTransfer
        ld hl,(TFS_OBJECT_XFER_REMAIN)
        ld a,h
        or l
        jr nz,tecfsObjectWriteLoop
        ld hl,(TFS_OBJECT_XFER_CURSOR)
        ld de,(TFS_OBJECT_XFER_LENGTH)
        or a
        sbc hl,de
        jp c,tecfsObjectTransferSuccess
        add hl,de
        ld (TFS_OBJECT_XFER_LENGTH),hl
        jp tecfsObjectTransferSuccess
tecfsObjectWriteCapacity:
        ld a,NucleusStatusCapacity
tecfsObjectWriteFailed:
        ld (iy+TFS_OBJECT_HANDLE_MODE),TFS_OBJECT_HANDLE_POISONED
        jp tecfsObjectFailure

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsObjectValidateTransfer:
        ld ix,(TFS_OBJECT_REQUEST_PTR)
        ld a,(ix+NucleusObjectRequestOffset)
        or (ix+NucleusObjectRequestOffset+1)
        or (ix+NucleusObjectRequestOffset+2)
        or (ix+NucleusObjectRequestOffset+3)
        jp nz,tecfsObjectInvalid
        call tecfsObjectValidateHandle
        ret c
        ld c,(ix+NucleusObjectRequestLength)
        ld b,(ix+NucleusObjectRequestLength+1)
        ld l,(ix+NucleusObjectRequestPointer)
        ld h,(ix+NucleusObjectRequestPointer+1)
        ld a,b
        or c
        ret z
        jp tecfsObjectValidateRange

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsObjectBeginTransfer:
        ld ix,(TFS_OBJECT_REQUEST_PTR)
        ld l,(ix+NucleusObjectRequestPointer)
        ld h,(ix+NucleusObjectRequestPointer+1)
        ld (TFS_OBJECT_XFER_PTR),hl
        ld l,(ix+NucleusObjectRequestLength)
        ld h,(ix+NucleusObjectRequestLength+1)
        ld (TFS_OBJECT_XFER_REMAIN),hl
        ld hl,0
        ld (TFS_OBJECT_XFER_RESULT),hl
        ld l,(iy+TFS_OBJECT_HANDLE_CURSOR)
        ld h,(iy+TFS_OBJECT_HANDLE_CURSOR+1)
        ld (TFS_OBJECT_XFER_CURSOR),hl
        ld l,(iy+TFS_OBJECT_HANDLE_LENGTH)
        ld h,(iy+TFS_OBJECT_HANDLE_LENGTH+1)
        ld (TFS_OBJECT_XFER_LENGTH),hl
        ret

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsObjectPrepareDataSector:
        ld h,(iy+TFS_OBJECT_HANDLE_SLOT)
        ld l,0
        ld a,(iy+TFS_OBJECT_HANDLE_HALF)
        or a
        jr z,tecfsObjectDataHalfReady
        ld de,TFS_OBJECT_GEN_SECTORS
        add hl,de
tecfsObjectDataHalfReady:
        ld de,TFS_OBJECT_DATA_SECTOR
        add hl,de
        ld de,(TFS_OBJECT_XFER_CURSOR)
        srl d
        ld e,d
        ld d,0
        add hl,de
        ld (TFS_OBJECT_IO_SECTOR),hl
        ld hl,(TFS_OBJECT_XFER_CURSOR)
        ld a,h
        and 1
        ld h,a
        ld (TFS_OBJECT_XFER_OFFSET),hl
        ret

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsObjectChooseChunk:
        ld hl,512
        ld de,(TFS_OBJECT_XFER_OFFSET)
        or a
        sbc hl,de
        ex de,hl
        ld hl,(TFS_OBJECT_XFER_REMAIN)
        or a
        sbc hl,de
        jr c,tecfsObjectChunkRemaining
        ld (TFS_OBJECT_XFER_CHUNK),de
        ret
tecfsObjectChunkRemaining:
        add hl,de
        ld (TFS_OBJECT_XFER_CHUNK),hl
        ret

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsObjectAdvanceTransfer:
        ld de,(TFS_OBJECT_XFER_CHUNK)
        ld hl,(TFS_OBJECT_XFER_CURSOR)
        add hl,de
        ld (TFS_OBJECT_XFER_CURSOR),hl
        ld hl,(TFS_OBJECT_XFER_PTR)
        add hl,de
        ld (TFS_OBJECT_XFER_PTR),hl
        ld hl,(TFS_OBJECT_XFER_RESULT)
        add hl,de
        ld (TFS_OBJECT_XFER_RESULT),hl
        ld hl,(TFS_OBJECT_XFER_REMAIN)
        or a
        sbc hl,de
        ld (TFS_OBJECT_XFER_REMAIN),hl
        ret

tecfsObjectTransferSuccess:
        ld hl,(TFS_OBJECT_XFER_CURSOR)
        ld (iy+TFS_OBJECT_HANDLE_CURSOR),l
        ld (iy+TFS_OBJECT_HANDLE_CURSOR+1),h
        ld hl,(TFS_OBJECT_XFER_LENGTH)
        ld (iy+TFS_OBJECT_HANDLE_LENGTH),l
        ld (iy+TFS_OBJECT_HANDLE_LENGTH+1),h
        ld hl,(TFS_OBJECT_XFER_RESULT)
        ld ix,(TFS_OBJECT_REQUEST_PTR)
        ld (ix+NucleusObjectRequestResult),l
        ld (ix+NucleusObjectRequestResult+1),h
        jp tecfsObjectSuccess
tecfsObjectTransferFailure:
        ld ix,(TFS_OBJECT_REQUEST_PTR)
        xor a
        ld (ix+NucleusObjectRequestResult),a
        ld (ix+NucleusObjectRequestResult+1),a
        ld a,NucleusStatusStorage
        jp tecfsObjectFailure

tecfsObjectRewind:
        call tecfsObjectValidateSimple
        ret c
        call tecfsObjectValidateHandle
        ret c
        ld a,(iy+TFS_OBJECT_HANDLE_MODE)
        cp TFS_OBJECT_HANDLE_POISONED
        jp z,tecfsObjectAccess
        xor a
        ld (iy+TFS_OBJECT_HANDLE_CURSOR),a
        ld (iy+TFS_OBJECT_HANDLE_CURSOR+1),a
        jp tecfsObjectSuccess

tecfsObjectSeek:
        ld ix,(TFS_OBJECT_REQUEST_PTR)
        ld a,(ix+NucleusObjectRequestPointer)
        or (ix+NucleusObjectRequestPointer+1)
        or (ix+NucleusObjectRequestLength)
        or (ix+NucleusObjectRequestLength+1)
        jp nz,tecfsObjectInvalid
        call tecfsObjectValidateHandle
        ret c
        ld a,(iy+TFS_OBJECT_HANDLE_MODE)
        cp TFS_OBJECT_HANDLE_POISONED
        jp z,tecfsObjectAccess
        ld a,(ix+NucleusObjectRequestOffset+2)
        or (ix+NucleusObjectRequestOffset+3)
        jp nz,tecfsObjectUnsupported
        ld l,(ix+NucleusObjectRequestOffset)
        ld h,(ix+NucleusObjectRequestOffset+1)
        ld e,(iy+TFS_OBJECT_HANDLE_LENGTH)
        ld d,(iy+TFS_OBJECT_HANDLE_LENGTH+1)
        push hl
        or a
        sbc hl,de
        pop hl
        jp nc,tecfsObjectSeekAtOrBeyond
tecfsObjectSeekStore:
        ld (iy+TFS_OBJECT_HANDLE_CURSOR),l
        ld (iy+TFS_OBJECT_HANDLE_CURSOR+1),h
        jp tecfsObjectSuccess
tecfsObjectSeekAtOrBeyond:
        jr z,tecfsObjectSeekStore
        jp tecfsObjectUnsupported

tecfsObjectClose:
        call tecfsObjectValidateSimple
        ret c
        call tecfsObjectValidateHandle
        ret c
        ld a,(iy+TFS_OBJECT_HANDLE_MODE)
        cp TFS_OBJECT_HANDLE_READ
        jp nz,tecfsObjectAccess
        xor a
        ld (iy+TFS_OBJECT_HANDLE_MODE),a
        jp tecfsObjectSuccess

tecfsObjectAbort:
        call tecfsObjectValidateSimple
        ret c
        call tecfsObjectValidateHandle
        ret c
        ld a,(iy+TFS_OBJECT_HANDLE_MODE)
        cp TFS_OBJECT_HANDLE_WRITE
        jr z,tecfsObjectAbortReady
        cp TFS_OBJECT_HANDLE_POISONED
        jp nz,tecfsObjectAccess
tecfsObjectAbortReady:
        xor a
        ld (iy+TFS_OBJECT_HANDLE_MODE),a
        jp tecfsObjectSuccess

tecfsObjectCommit:
        call tecfsObjectValidateSimple
        ret c
        call tecfsObjectValidateHandle
        ret c
        ld a,(iy+TFS_OBJECT_HANDLE_MODE)
        cp TFS_OBJECT_HANDLE_WRITE
        jp nz,tecfsObjectAccess
        ld a,(iy+TFS_OBJECT_HANDLE_SLOT)
        ld (TFS_OBJECT_SCAN_SLOT),a
        ld (TFS_OBJECT_SELECTED_SLOT),a
        ld a,(iy+TFS_OBJECT_HANDLE_HALF)
        ld (TFS_OBJECT_SELECTED_HALF),a
        call tecfsObjectLoadDescriptor
        ret c
        call tecfsObjectValidatePendingDescriptor
        jp nz,tecfsObjectStorage
        ld l,(iy+TFS_OBJECT_HANDLE_GEN)
        ld h,(iy+TFS_OBJECT_HANDLE_GEN+1)
        ld de,(TFS_OBJECT_SECTOR_BUFFER+TFS_OBJECT_DESC_GENERATION)
        or a
        sbc hl,de
        jp nz,tecfsObjectStorage
        ld a,TFS_OBJECT_DESC_MAGIC_2
        ld (TFS_OBJECT_SECTOR_BUFFER+2),a
        ld l,(iy+TFS_OBJECT_HANDLE_LENGTH)
        ld h,(iy+TFS_OBJECT_HANDLE_LENGTH+1)
        ld (TFS_OBJECT_SECTOR_BUFFER+TFS_OBJECT_DESC_DATA_LENGTH),hl
        call tecfsObjectSealDescriptor
        call tecfsObjectDescriptorSector
        ld (TFS_OBJECT_IO_SECTOR),hl
        call tecfsObjectWriteIoSector
        ret c
        xor a
        ld (iy+TFS_OBJECT_HANDLE_MODE),a
        jp tecfsObjectSuccess

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsObjectSealDescriptor:
        xor a
        ld (TFS_OBJECT_SECTOR_BUFFER+TFS_OBJECT_DESC_CHECKSUM),a
        ld hl,TFS_OBJECT_SECTOR_BUFFER
        ld bc,TFS_OBJECT_DESC_CHECKSUM
        call tecfsObjectSumBytes
        xor a
        sub e
        ld (TFS_OBJECT_SECTOR_BUFFER+TFS_OBJECT_DESC_CHECKSUM),a
        ret

.routine in BC,HL out A,BC,E,HL,zero clobbers sign,parity,halfCarry
tecfsObjectSumBytes:
        ld e,0
tecfsObjectSumBytesLoop:
        ld a,e
        add a,(hl)
        ld e,a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,tecfsObjectSumBytesLoop
        ret

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsObjectValidateSimple:
        ld ix,(TFS_OBJECT_REQUEST_PTR)
        ld a,(ix+NucleusObjectRequestPointer)
        or (ix+NucleusObjectRequestPointer+1)
        or (ix+NucleusObjectRequestLength)
        or (ix+NucleusObjectRequestLength+1)
        or (ix+NucleusObjectRequestOffset)
        or (ix+NucleusObjectRequestOffset+1)
        or (ix+NucleusObjectRequestOffset+2)
        or (ix+NucleusObjectRequestOffset+3)
        jp nz,tecfsObjectInvalid
        ret

.routine out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsObjectValidateHandle:
        ld ix,(TFS_OBJECT_REQUEST_PTR)
        ld a,(ix+NucleusObjectRequestHandle)
        or a
        jp z,tecfsObjectInvalid
        cp TFS_OBJECT_HANDLE_COUNT+1
        jp nc,tecfsObjectInvalid
        ld e,a
        dec a
        ld l,a
        ld h,0
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ld de,TFS_OBJECT_HANDLE_TABLE
        add hl,de
        push hl
        pop iy
        ld a,(iy+TFS_OBJECT_HANDLE_MODE)
        or a
        jp z,tecfsObjectInvalid
        ld a,(ix+NucleusObjectRequestHandle+1)
        cp (iy+TFS_OBJECT_HANDLE_TOKEN)
        jp nz,tecfsObjectInvalid
        ret

.routine in BC,HL out A,BC,DE,HL,IX,IY,carry,zero clobbers sign,parity,halfCarry
tecfsObjectValidateRange:
        ld a,h
        cp 0x08
        jp c,tecfsObjectInvalid
        cp 0x80
        jp nc,tecfsObjectInvalid
        add hl,bc
        jp c,tecfsObjectInvalid
        ld a,h
        cp 0x80
        jp nc,tecfsObjectInvalid
        or a
        ret

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
tecfsObjectReadIoSector:
        call tecfsObjectPrepareIo
        call tecfsReadSectorImpl
        jr c,tecfsObjectStorage
        xor a
        ret

.routine out A,BC,DE,HL,carry,zero clobbers sign,parity,halfCarry
tecfsObjectWriteIoSector:
        call tecfsObjectPrepareIo
        call tecfsWriteSectorImpl
        jr c,tecfsObjectStorage
        xor a
        ret

.routine out H,L clobbers sign,parity,halfCarry
tecfsObjectPrepareIo:
        ld hl,TFS_OBJECT_SECTOR_BUFFER
        ld (TFS_PARAM_BUFFER_LO),hl
        ld hl,(TFS_OBJECT_IO_SECTOR)
        ld (TFS_PARAM_SECTOR_0),hl
        ld hl,0
        ld (TFS_PARAM_SECTOR_2),hl
        ret

tecfsObjectSuccess:
        xor a
        ret
tecfsObjectInvalid:
        ld a,NucleusStatusInvalid
        jr tecfsObjectFailure
tecfsObjectNotFound:
        ld a,NucleusStatusNotFound
        jr tecfsObjectFailure
tecfsObjectCapacity:
        ld a,NucleusStatusCapacity
        jr tecfsObjectFailure
tecfsObjectAccess:
        ld a,NucleusStatusAccess
        jr tecfsObjectFailure
tecfsObjectStorage:
        ld a,NucleusStatusStorage
        jr tecfsObjectFailure
tecfsObjectConflict:
        ld a,NucleusStatusConflict
        jr tecfsObjectFailure
tecfsObjectUnsupported:
        ld a,NucleusStatusUnsupported
tecfsObjectFailure:
        scf
        ret

tecfsBadLocator:
        ld a,TFS_ERR_BAD_LOCATOR
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        scf
        ret

tecfsBadCatalog:
        ld a,TFS_ERR_BAD_CATALOG
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        scf
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry
tecfsValidateSector:
        ld a,(TFS_PARAM_SECTOR_3)
        or a
        scf
        ret nz
        ld a,(TFS_PARAM_SECTOR_2)
        cp 0x7C
        ccf
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry
tecfsValidateCardSector:
        ld a,(TFS_PARAM_SECTOR_3)
        or a
        scf
        ret nz
        ld a,(TFS_PARAM_SECTOR_2)
        cp 0x7C
        jr c,tecfsCardSectorValid
        jr nz,tecfsCardSectorInvalid
        ld hl,(TFS_PARAM_SECTOR_0)
        ld de,TFS_IMAGE_BASE_LBA_0 + (TFS_IMAGE_BASE_LBA_1 * 256)
        or a
        sbc hl,de
        ccf
        ret

tecfsCardSectorValid:
        or a
        ret

tecfsCardSectorInvalid:
        scf
        ret

tecfsBadSector:
        ld a,TFS_ERR_BAD_SECTOR
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        scf
        ret

tecfsBadBuffer:
        ld a,TFS_ERR_BAD_BUFFER
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        scf
        ret

tecfsUnsupported:
        ld a,TFS_ERR_UNSUPPORTED
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        scf
        ret

Tecm8ExpansionBank2Info:
        .db     "T","M","8",EXP_BANK,EXP_VERSION
