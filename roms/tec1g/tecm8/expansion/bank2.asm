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
        cp TFS_SVC_LOAD_SOURCE
        jp z,tecfsLoadSourceImpl
        cp TFS_SVC_LOAD_SOURCE_PAGE
        jp z,tecfsLoadSourcePageImpl
        cp TFS_SVC_SAVE_SOURCE_PAGE
        jp z,tecfsSaveSourcePageImpl
        cp TFS_SVC_COMMIT_SOURCE_META
        jp z,tecfsCommitSourceMetaImpl
        cp TFS_SVC_SAVE_ARTIFACT
        jp z,tecfsSaveArtifactImpl
        cp TFS_SVC_LOAD_ARTIFACT
        jp z,tecfsLoadArtifactImpl
        cp TFS_SVC_FIND_PATH
        jp z,tecfsFindPathImpl
        cp TFS_SVC_LIST_PATH
        jp z,tecfsListPathImpl
        cp TFS_SVC_CREATE_SOURCE
        jp z,tecfsCreateSourceImpl
        cp TFS_SVC_CREATE_FILE
        jp z,tecfsCreateFileImpl
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

tecfsFindPath:
        jp tecfsFindPathImpl

tecfsListPath:
        jp tecfsListPathImpl

tecfsCreateSource:
        jp tecfsCreateSourceImpl

tecfsLoadSource:
        jp tecfsLoadSourceImpl

BankAbiNestedTarget:
        ld c,MON_SYS_GET
        .expectout A
        rst 10H
        ld (ABI_TRACE_8),a
        ld a,0xB2
        ret

tecfsMountImpl:
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
        xor a
        ld (TFS_PARAM_DRIVER_BANK),a
        ld (TFS_PARAM_DRIVER_ADDR_LO),a
        ld (TFS_PARAM_DRIVER_ADDR_HI),a
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

.routine out A,carry,zero clobbers sign,parity,halfCarry,D,E,H,L
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

.routine out A,carry,zero clobbers sign,parity,halfCarry,D,E,H,L
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

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
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
        ld a,(TFS_PARAM_DRIVER_OP)
        push hl
        push de
        push af
        ld a,(TFS_PARAM_DRIVER_BANK)
        ld b,a
        ld c,MON_BANK_CALL
        rst 10H
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

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,D,E,H,L
tecfsFormatMetaRecordImpl:
        ld hl,(TFS_PARAM_BUFFER_LO)
        ld a,h
        or l
        jp z,tecfsBadBuffer
        ld b,TFS_META_RECORD_BYTES
        xor a
tecfsFormatMetaRecordClear:
        ld (hl),a
        inc hl
        djnz tecfsFormatMetaRecordClear
        ld hl,(TFS_PARAM_BUFFER_LO)
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

; Resolve one bounded TM8 v1 path into a resident 64-byte catalogue entry.
; Input: TFS_PARAM_PATH_LO/HI -> "/name" or "/prefix/name".
; Output: TFS_PARAM_BUFFER_LO/HI and TFS_PARAM_LOAD_CATALOG_LO/HI point at
; TFS_CATALOG_BUFFER. The catalogue sector/slot are retained for an atomic
; metadata commit after source data pages have been saved.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsFindPathImpl:
        call tecfsParsePath
        ret c
        ld a,(TFS_SCAN_PREFIX_LEN)
        or a
        jr z,tecfsFindPathRoot
        call tecfsFindPrefix
        ret c
        jr tecfsFindPathCatalog
tecfsFindPathRoot:
        ld (TFS_SCAN_PREFIX_ID),a
tecfsFindPathCatalog:
        call tecfsFindCatalog
        ret c
        ld hl,TFS_CATALOG_BUFFER
        ld (TFS_PARAM_BUFFER_LO),hl
        ld (TFS_PARAM_LOAD_CATALOG_LO),hl
        call tecfsDecodeCatalogImpl
        ret c
        xor a
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        ld a,0x82
        or a
        ret

; List visible local filenames in one bounded TM8 v1 prefix.
; Input:
;   TFS_PARAM_PATH_LO/HI      -> "/" or "/prefix"
;   TFS_PARAM_LIST_DEST_LO/HI -> output buffer
;   TFS_PARAM_LIST_CAP_LO/HI  -> capacity including the final NUL
; Output:
;   newline-separated local filenames, final NUL, count/used fields
;   TFS_LIST_FLAG_TRUNCATED when another complete name would not fit
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsListPathImpl:
        call tecfsListInitialize
        ret c
        call tecfsParseListPath
        ret c
        ld a,(TFS_SCAN_PREFIX_LEN)
        or a
        jr z,tecfsListPathRoot
        call tecfsFindPrefix
        ret c
        jr tecfsListPathCatalog
tecfsListPathRoot:
        ld (TFS_SCAN_PREFIX_ID),a
tecfsListPathCatalog:
        ld a,TFS_CATALOG_SECTOR
        ld (TFS_SCAN_SECTOR),a
        ld a,TFS_CATALOG_SECTORS
        ld (TFS_SCAN_SECTORS_LEFT),a
tecfsListPathSector:
        call tecfsReadScanSector
        ret c
        xor a
        ld (TFS_SCAN_ENTRY_INDEX),a
tecfsListPathEntry:
        call tecfsCatalogEntryAddress
        call tecfsListMaybeAppendEntry
        jr c,tecfsListPathDone
        ld a,(TFS_SCAN_ENTRY_INDEX)
        inc a
        ld (TFS_SCAN_ENTRY_INDEX),a
        cp TFS_CATALOG_ENTRIES_SECTOR
        jr nz,tecfsListPathEntry
        call tecfsAdvanceScanSector
        jr nz,tecfsListPathSector
tecfsListPathDone:
        xor a
        call tecfsListAppendByte
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        ld a,0x82
        or a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,H,L
tecfsListInitialize:
        xor a
        ld (TFS_PARAM_LIST_USED_LO),a
        ld (TFS_PARAM_LIST_USED_HI),a
        ld (TFS_PARAM_LIST_COUNT),a
        ld (TFS_PARAM_LIST_FLAGS),a
        ld hl,(TFS_PARAM_LIST_DEST_LO)
        ld a,h
        or l
        jp z,tecfsBadBuffer
        ld (TFS_LIST_WORK_PTR_LO),hl
        ld hl,(TFS_PARAM_LIST_CAP_LO)
        ld a,h
        or l
        jp z,tecfsBadBuffer
        ld (TFS_LIST_REMAINING_LO),hl
        ld hl,(TFS_LIST_WORK_PTR_LO)
        xor a
        ld (hl),a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,H,L
tecfsParseListPath:
        ld hl,(TFS_PARAM_PATH_LO)
        ld a,h
        or l
        jr nz,tecfsParseListPathHavePath
        ld hl,TecfsDefaultListPath
tecfsParseListPathHavePath:
        ld a,(hl)
        cp "/"
        jp nz,tecfsBadPath
        inc hl
        ld (TFS_SCAN_PREFIX_PTR),hl
        ld b,0
tecfsParseListPathNext:
        ld a,(hl)
        or a
        jr z,tecfsParseListPathDone
        cp "/"
        jp z,tecfsBadPath
        inc b
        ld a,b
        cp TFS_PREFIX_NAME_BYTES+1
        jp nc,tecfsBadPath
        inc hl
        jr tecfsParseListPathNext
tecfsParseListPathDone:
        ld a,b
        ld (TFS_SCAN_PREFIX_LEN),a
        xor a
        ret

TecfsDefaultListPath:
        .db     "/src",0

.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsListMaybeAppendEntry:
        ld a,(hl)
        cp TFS_ENTRY_STATUS_ACTIVE
        jr nz,tecfsListEntrySkipped
        inc hl
        inc hl
        ld a,(TFS_SCAN_PREFIX_ID)
        cp (hl)
        jr nz,tecfsListEntrySkipped
        inc hl
        ld a,(hl)
        or a
        jr z,tecfsListEntrySkipped
        cp TFS_CATALOG_NAME_BYTES+1
        jr nc,tecfsListEntrySkipped
        ld b,a
        inc hl
        ld a,(hl)
        cp "."
        jr z,tecfsListEntrySkipped
        push hl
        call tecfsListHasRoomForName
        pop hl
        jr c,tecfsListEntryTruncated
tecfsListCopyName:
        ld a,(hl)
        push hl
        call tecfsListAppendByte
        pop hl
        inc hl
        djnz tecfsListCopyName
        ld a,0x0A
        call tecfsListAppendByte
        ld a,(TFS_PARAM_LIST_COUNT)
        inc a
        ld (TFS_PARAM_LIST_COUNT),a
tecfsListEntrySkipped:
        or a
        ret
tecfsListEntryTruncated:
        ld a,TFS_LIST_FLAG_TRUNCATED
        ld (TFS_PARAM_LIST_FLAGS),a
        scf
        ret

.routine in B out A,carry,zero clobbers sign,parity,halfCarry,D,E,H,L
tecfsListHasRoomForName:
        ld hl,(TFS_LIST_REMAINING_LO)
        ld d,0
        ld e,b
        inc de
        inc de
        or a
        sbc hl,de
        ret

.routine in A out A,zero clobbers sign,parity,halfCarry,D,E,H,L
tecfsListAppendByte:
        ld de,(TFS_LIST_WORK_PTR_LO)
        ld (de),a
        inc de
        ld (TFS_LIST_WORK_PTR_LO),de
        ld hl,(TFS_LIST_REMAINING_LO)
        dec hl
        ld (TFS_LIST_REMAINING_LO),hl
        ld hl,(TFS_PARAM_LIST_USED_LO)
        inc hl
        ld (TFS_PARAM_LIST_USED_LO),hl
        ret

; Create one empty, one-block source file in an existing TM8 prefix.
; The data block is cleared and allocated before the catalogue entry is
; published, so an interrupted create cannot expose uninitialised source data.
; Input: TFS_PARAM_PATH_LO/HI -> "/name" or "/prefix/name".
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsCreateSourceImpl:
        ld a,TFS_FILE_SOURCE_V1
        ld (TFS_PARAM_CREATE_FILE_TYPE),a
        jr tecfsCreateFileCommon

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsCreateFileImpl:
        ld a,(TFS_PARAM_CREATE_FILE_TYPE)
        cp TFS_FILE_BINARY
        jr z,tecfsCreateFileCommon
        cp TFS_FILE_ASSET
        jp nz,tecfsCreateBadCatalog
tecfsCreateFileCommon:
        call tecfsParsePath
        ret c
        call tecfsCreateValidateName
        ret c
        ld a,(TFS_SCAN_PREFIX_LEN)
        or a
        jr z,tecfsCreateSourceRoot
        call tecfsFindPrefix
        ret c
        jr tecfsCreateSourcePrefixReady
tecfsCreateSourceRoot:
        ld (TFS_SCAN_PREFIX_ID),a
tecfsCreateSourcePrefixReady:
        call tecfsCreateScanCatalog
        ret c
        call tecfsCreateFindFreeBlock
        ret c
        call tecfsCreateClearDataBlock
        ret c
        call tecfsCreateMarkAllocated
        ret c
        call tecfsCreateUpdateSuperblock
        ret c
        call tecfsCreateWriteCatalog
        ret c
        xor a
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        ld a,0x82
        or a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,H,L
tecfsCreateValidateName:
        ld hl,(TFS_SCAN_NAME_PTR)
        ld a,(TFS_SCAN_NAME_LEN)
        ld b,a
tecfsCreateValidateNameNext:
        ld a,(hl)
        cp "a"
        jr c,tecfsCreateValidateNameDigit
        cp "z"+1
        jr c,tecfsCreateValidateNameOk
tecfsCreateValidateNameDigit:
        cp "0"
        jr c,tecfsCreateValidateNamePunctuation
        cp "9"+1
        jr c,tecfsCreateValidateNameOk
tecfsCreateValidateNamePunctuation:
        cp "."
        jr z,tecfsCreateValidateNameOk
        cp "_"
        jr z,tecfsCreateValidateNameOk
        cp "-"
        jp nz,tecfsBadPath
tecfsCreateValidateNameOk:
        inc hl
        djnz tecfsCreateValidateNameNext
        or a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsCreateScanCatalog:
        ld hl,TFS_CREATE_ID_BITMAP
        ld de,TFS_CREATE_ID_BITMAP+1
        ld bc,TFS_CREATE_ID_BITMAP_BYTES-1
        xor a
        ld (hl),a
        ldir
        dec a
        ld (TFS_CREATE_CATALOG_SECTOR),a
        ld a,TFS_CATALOG_SECTOR
        ld (TFS_SCAN_SECTOR),a
        ld a,TFS_CATALOG_SECTORS
        ld (TFS_SCAN_SECTORS_LEFT),a
tecfsCreateCatalogSector:
        call tecfsReadScanSector
        ret c
        xor a
        ld (TFS_SCAN_ENTRY_INDEX),a
tecfsCreateCatalogEntry:
        call tecfsCatalogEntryAddress
        ld a,(hl)
        or a
        jr z,tecfsCreateCatalogFree
        cp TFS_ENTRY_STATUS_ACTIVE
        jp nz,tecfsCreateBadCatalog
        push hl
        call tecfsCreateMarkFileId
        pop hl
        push hl
        call tecfsMatchCatalogEntry
        pop hl
        jp nc,tecfsCreateExists
        jr tecfsCreateCatalogAdvance
tecfsCreateCatalogFree:
        ld a,(TFS_CREATE_CATALOG_SECTOR)
        inc a
        jr nz,tecfsCreateCatalogAdvance
        push hl
        call tecfsCreateFreeEntryClean
        pop hl
        ret c
        ld a,(TFS_SCAN_SECTOR)
        ld (TFS_CREATE_CATALOG_SECTOR),a
        ld a,(TFS_SCAN_ENTRY_INDEX)
        ld (TFS_CREATE_CATALOG_INDEX),a
tecfsCreateCatalogAdvance:
        ld a,(TFS_SCAN_ENTRY_INDEX)
        inc a
        ld (TFS_SCAN_ENTRY_INDEX),a
        cp TFS_CATALOG_ENTRIES_SECTOR
        jr nz,tecfsCreateCatalogEntry
        call tecfsAdvanceScanSector
        jr nz,tecfsCreateCatalogSector
        ld a,(TFS_CREATE_CATALOG_SECTOR)
        inc a
        jp z,tecfsCreateNoSpace
        jp tecfsCreateChooseFileId

.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B,H,L
tecfsCreateFreeEntryClean:
        ld b,TFS_CATALOG_ENTRY_BYTES
tecfsCreateFreeEntryCleanNext:
        ld a,(hl)
        or a
        jp nz,tecfsCreateBadCatalog
        inc hl
        djnz tecfsCreateFreeEntryCleanNext
        or a
        ret

.routine in HL out A,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsCreateMarkFileId:
        inc hl
        ld a,(hl)
        ld c,a
        and 0x07
        ld b,a
        ld d,0x01
        jr z,tecfsCreateFileIdMaskReady
tecfsCreateFileIdMask:
        rlc d
        djnz tecfsCreateFileIdMask
tecfsCreateFileIdMaskReady:
        ld b,d
        ld a,c
        srl a
        srl a
        srl a
        ld l,a
        ld h,0x00
        ld de,TFS_CREATE_ID_BITMAP
        add hl,de
        ld a,(hl)
        or b
        ld (hl),a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsCreateChooseFileId:
        ld hl,TFS_CREATE_ID_BITMAP
        ld c,0x00
tecfsCreateChooseFileIdByte:
        ld a,(hl)
        cp 0xFF
        jr nz,tecfsCreateChooseFileIdBit
        inc hl
        ld a,c
        add a,0x08
        ld c,a
        jr nz,tecfsCreateChooseFileIdByte
        jp tecfsCreateNoSpace
tecfsCreateChooseFileIdBit:
        ld b,0x08
        ld d,0x01
tecfsCreateChooseFileIdBitNext:
        ld a,(hl)
        and d
        jr z,tecfsCreateChooseFileIdFound
        rlc d
        inc c
        djnz tecfsCreateChooseFileIdBitNext
        jp tecfsCreateNoSpace
tecfsCreateChooseFileIdFound:
        ld a,c
        ld (TFS_CREATE_FILE_ID),a
        or a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsCreateFindFreeBlock:
        ld hl,TFS_DATA_START_BLOCK
        ld (TFS_CREATE_CANDIDATE_LO),hl
        ld a,TFS_ALLOCATION_SECTOR
        ld (TFS_SCAN_SECTOR),a
        ld a,TFS_ALLOCATION_USED_SECTORS
        ld (TFS_SCAN_SECTORS_LEFT),a
tecfsCreateAllocSector:
        call tecfsReadScanSector
        ret c
        ld a,(TFS_SCAN_SECTOR)
        cp TFS_ALLOCATION_SECTOR
        jr nz,tecfsCreateAllocWholeSector
        ld hl,TFS_CATALOG_BUFFER+(TFS_DATA_START_BLOCK*2)
        ld de,TFS_DATA_START_BLOCK
        ld b,0x100-TFS_DATA_START_BLOCK
        jr tecfsCreateAllocLoop
tecfsCreateAllocWholeSector:
        ld hl,TFS_CATALOG_BUFFER
        ld de,(TFS_CREATE_CANDIDATE_LO)
        ld b,0x00
tecfsCreateAllocLoop:
        ld a,(hl)
        inc hl
        or (hl)
        jr z,tecfsCreateAllocFound
        inc hl
        inc de
        djnz tecfsCreateAllocLoop
        ld (TFS_CREATE_CANDIDATE_LO),de
        call tecfsAdvanceScanSector
        jr nz,tecfsCreateAllocSector
        jp tecfsCreateNoSpace
tecfsCreateAllocFound:
        ld (TFS_CREATE_FREE_BLOCK_LO),de
        ld a,(TFS_SCAN_SECTOR)
        ld (TFS_CREATE_ALLOC_SECTOR),a
        or a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsCreateClearDataBlock:
        ld hl,TFS_CATALOG_BUFFER
        ld de,TFS_CATALOG_BUFFER+1
        ld bc,0x01FF
        xor a
        ld (hl),a
        ldir
        ld hl,(TFS_CREATE_FREE_BLOCK_LO)
        add hl,hl
        add hl,hl
        add hl,hl
        ld (TFS_CREATE_DATA_SECTOR_LO),hl
        ld a,TFS_SECTORS_PER_BLOCK
        ld (TFS_SCAN_SECTORS_LEFT),a
tecfsCreateClearDataSector:
        ld hl,(TFS_CREATE_DATA_SECTOR_LO)
        call tecfsCreateSetSector
        ld hl,TFS_CATALOG_BUFFER
        ld (TFS_PARAM_BUFFER_LO),hl
        call tecfsWriteSectorImpl
        ret c
        ld hl,(TFS_CREATE_DATA_SECTOR_LO)
        inc hl
        ld (TFS_CREATE_DATA_SECTOR_LO),hl
        ld hl,TFS_SCAN_SECTORS_LEFT
        dec (hl)
        jr nz,tecfsCreateClearDataSector
        or a
        ret

.routine in HL out A,zero clobbers sign,parity,halfCarry,H,L
tecfsCreateSetSector:
        ld (TFS_PARAM_SECTOR_0),hl
        xor a
        ld (TFS_PARAM_SECTOR_2),a
        ld (TFS_PARAM_SECTOR_3),a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsCreateMarkAllocated:
        ld a,(TFS_CREATE_ALLOC_SECTOR)
        ld (TFS_SCAN_SECTOR),a
        call tecfsReadScanSector
        ret c
        ld a,(TFS_CREATE_FREE_BLOCK_LO)
        add a,a
        ld l,a
        ld h,0x00
        jr nc,tecfsCreateAllocOffsetReady
        inc h
tecfsCreateAllocOffsetReady:
        ld de,TFS_CATALOG_BUFFER
        add hl,de
        ld (hl),0xFF
        inc hl
        ld (hl),0xFF
        jp tecfsWriteScanSector

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsCreateUpdateSuperblock:
        xor a
        ld (TFS_SCAN_SECTOR),a
        call tecfsReadScanSector
        ret c
        ld hl,TFS_CATALOG_BUFFER
        ld de,TecfsCreateSuperblockHeader
        ld b,TecfsCreateSuperblockHeaderEnd-TecfsCreateSuperblockHeader
        call tecfsMatchScanBytes
        jp c,tecfsCreateBadVolume
        call tecfsCreateValidateChecksum
        ret c
        ld hl,TFS_CATALOG_BUFFER+42
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,d
        or e
        jp z,tecfsCreateNoSpace
        dec de
        ld (hl),d
        dec hl
        ld (hl),e
        call tecfsCreateRecomputeChecksum
        jp tecfsWriteScanSector

TecfsCreateSuperblockHeader:
        .db     "TECM8VOL"
        .db     0x01,0x00
        .db     0x00,0x02
        .db     0x00,0x10
        .db     0x00,0x04
        .db     0x00,0x00,0x40,0x00
        .db     0x01,0x00
        .db     0x01,0x00
        .db     0x02,0x00
        .db     0x04,0x00
        .db     0x80,0x00
        .db     0x80,0x00
        .db     0x06,0x00
        .db     0x04,0x00
        .db     0x40,0x00
        .db     0x00,0x01
        .db     0x0A,0x00
TecfsCreateSuperblockHeaderEnd:

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsCreateValidateChecksum:
        ld hl,TFS_CATALOG_BUFFER+72
        ld a,(hl)
        ld (TFS_CREATE_CHECKSUM_LO),a
        inc hl
        ld a,(hl)
        ld (TFS_CREATE_CHECKSUM_HI),a
        inc hl
        ld a,(hl)
        or a
        jp nz,tecfsCreateBadVolume
        inc hl
        ld a,(hl)
        or a
        jp nz,tecfsCreateBadVolume
        call tecfsCreateRecomputeChecksum
        ld hl,TFS_CATALOG_BUFFER+72
        ld a,(TFS_CREATE_CHECKSUM_LO)
        cp (hl)
        jp nz,tecfsCreateBadVolume
        inc hl
        ld a,(TFS_CREATE_CHECKSUM_HI)
        cp (hl)
        jp nz,tecfsCreateBadVolume
        or a
        ret

.routine out A,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsCreateRecomputeChecksum:
        ld hl,TFS_CATALOG_BUFFER+72
        xor a
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        ld hl,TFS_CATALOG_BUFFER
        ld bc,0x0200
        ld de,0x0000
tecfsCreateChecksumNext:
        ld a,e
        add a,(hl)
        ld e,a
        jr nc,tecfsCreateChecksumNoCarry
        inc d
tecfsCreateChecksumNoCarry:
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,tecfsCreateChecksumNext
        ld hl,TFS_CATALOG_BUFFER+72
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        xor a
        ld (hl),a
        inc hl
        ld (hl),a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsCreateWriteCatalog:
        ld a,(TFS_CREATE_CATALOG_SECTOR)
        ld (TFS_SCAN_SECTOR),a
        call tecfsReadScanSector
        ret c
        ld a,(TFS_CREATE_CATALOG_INDEX)
        ld (TFS_SCAN_ENTRY_INDEX),a
        call tecfsCatalogEntryAddress
        push hl
        call tecfsCreateFreeEntryClean
        pop hl
        ret c
        ld a,TFS_ENTRY_STATUS_ACTIVE
        ld (hl),a
        inc hl
        ld a,(TFS_CREATE_FILE_ID)
        ld (hl),a
        inc hl
        ld a,(TFS_SCAN_PREFIX_ID)
        ld (hl),a
        inc hl
        ld a,(TFS_SCAN_NAME_LEN)
        ld (hl),a
        inc hl
        ld de,(TFS_SCAN_NAME_PTR)
        ld b,a
tecfsCreateCopyName:
        ld a,(de)
        ld (hl),a
        inc de
        inc hl
        djnz tecfsCreateCopyName
        call tecfsCatalogEntryAddress
        ld de,TFS_CATALOG_OFFSET_FIRST_BLOCK
        add hl,de
        ld de,(TFS_CREATE_FREE_BLOCK_LO)
        ld (hl),e
        inc hl
        ld (hl),d
        ld de,TFS_CATALOG_OFFSET_FILE_TYPE-TFS_CATALOG_OFFSET_FIRST_BLOCK-1
        add hl,de
        ld a,(TFS_PARAM_CREATE_FILE_TYPE)
        ld (hl),a
        jp tecfsWriteScanSector

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsWriteScanSector:
        ld a,(TFS_SCAN_SECTOR)
        ld l,a
        ld h,0x00
        call tecfsCreateSetSector
        ld hl,TFS_CATALOG_BUFFER
        ld (TFS_PARAM_BUFFER_LO),hl
        jp tecfsWriteSectorImpl

tecfsCreateBadCatalog:
        ld a,TFS_ERR_BAD_CATALOG
        jp tecfsPublishScanError
tecfsCreateNoSpace:
        ld a,TFS_ERR_NO_SPACE
        jp tecfsPublishScanError
tecfsCreateExists:
        ld a,TFS_ERR_EXISTS
        jp tecfsPublishScanError
tecfsCreateBadVolume:
        ld a,TFS_ERR_BAD_VOLUME_FORMAT
        jp tecfsPublishScanError

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,H,L
tecfsParsePath:
        ld hl,(TFS_PARAM_PATH_LO)
        ld a,h
        or l
        jr z,tecfsBadPath
        ld a,(hl)
        cp "/"
        jr nz,tecfsBadPath
        inc hl
        ld (TFS_SCAN_PREFIX_PTR),hl
        ld (TFS_SCAN_NAME_PTR),hl
        ld b,0
tecfsParsePathFirst:
        ld a,(hl)
        or a
        jr z,tecfsParseRootDone
        cp "/"
        jr z,tecfsParsePrefixDone
        inc b
        ld a,b
        cp TFS_CATALOG_NAME_BYTES+1
        jr nc,tecfsBadPath
        inc hl
        jr tecfsParsePathFirst
tecfsParseRootDone:
        ld a,b
        or a
        jr z,tecfsBadPath
        ld (TFS_SCAN_NAME_LEN),a
        xor a
        ld (TFS_SCAN_PREFIX_LEN),a
        ret
tecfsParsePrefixDone:
        ld a,b
        or a
        jr z,tecfsBadPath
        cp TFS_PREFIX_NAME_BYTES+1
        jr nc,tecfsBadPath
        ld (TFS_SCAN_PREFIX_LEN),a
        inc hl
        ld (TFS_SCAN_NAME_PTR),hl
        ld b,0
tecfsParsePathName:
        ld a,(hl)
        or a
        jr z,tecfsParseNameDone
        cp "/"
        jr z,tecfsBadPath
        inc b
        ld a,b
        cp TFS_CATALOG_NAME_BYTES+1
        jr nc,tecfsBadPath
        inc hl
        jr tecfsParsePathName
tecfsParseNameDone:
        ld a,b
        or a
        jr z,tecfsBadPath
        ld (TFS_SCAN_NAME_LEN),a
        xor a
        ret

tecfsBadPath:
        ld a,TFS_ERR_BAD_PATH
        jp tecfsPublishScanError

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsFindPrefix:
        ld a,TFS_PREFIX_SECTOR
        ld (TFS_SCAN_SECTOR),a
        ld a,TFS_PREFIX_SECTORS
        ld (TFS_SCAN_SECTORS_LEFT),a
tecfsFindPrefixSector:
        call tecfsReadScanSector
        ret c
        xor a
        ld (TFS_SCAN_ENTRY_INDEX),a
tecfsFindPrefixEntry:
        call tecfsPrefixEntryAddress
        call tecfsMatchPrefixEntry
        ret nc
        ld a,(TFS_SCAN_ENTRY_INDEX)
        inc a
        ld (TFS_SCAN_ENTRY_INDEX),a
        cp TFS_PREFIX_ENTRIES_SECTOR
        jr nz,tecfsFindPrefixEntry
        call tecfsAdvanceScanSector
        jr nz,tecfsFindPrefixSector
        ld a,TFS_ERR_NOT_FOUND
        jp tecfsPublishScanError

.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsMatchPrefixEntry:
        ld a,(hl)
        cp TFS_ENTRY_STATUS_ACTIVE
        jp nz,tecfsScanNoMatch
        inc hl
        ld c,(hl)
        inc hl
        ld a,(TFS_SCAN_PREFIX_LEN)
        cp (hl)
        jp nz,tecfsScanNoMatch
        inc hl
        ld de,(TFS_SCAN_PREFIX_PTR)
        ld b,a
        call tecfsMatchScanBytes
        ret c
        ld a,c
        ld (TFS_SCAN_PREFIX_ID),a
        or a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsFindCatalog:
        ld a,TFS_CATALOG_SECTOR
        ld (TFS_SCAN_SECTOR),a
        ld a,TFS_CATALOG_SECTORS
        ld (TFS_SCAN_SECTORS_LEFT),a
tecfsFindCatalogSector:
        call tecfsReadScanSector
        ret c
        xor a
        ld (TFS_SCAN_ENTRY_INDEX),a
tecfsFindCatalogEntry:
        call tecfsCatalogEntryAddress
        push hl
        call tecfsMatchCatalogEntry
        pop hl
        jr nc,tecfsFindCatalogFound
        ld a,(TFS_SCAN_ENTRY_INDEX)
        inc a
        ld (TFS_SCAN_ENTRY_INDEX),a
        cp TFS_CATALOG_ENTRIES_SECTOR
        jr nz,tecfsFindCatalogEntry
        call tecfsAdvanceScanSector
        jr nz,tecfsFindCatalogSector
        ld a,TFS_ERR_NOT_FOUND
        jp tecfsPublishScanError
tecfsFindCatalogFound:
        ld a,(TFS_SCAN_SECTOR)
        ld (TFS_SCAN_CATALOG_SECTOR),a
        push hl
        ld de,TFS_CATALOG_BUFFER
        or a
        sbc hl,de
        ld (TFS_SCAN_CATALOG_OFFSET_LO),hl
        pop hl
        ld de,TFS_CATALOG_BUFFER
        ld bc,TFS_CATALOG_ENTRY_BYTES
        ldir
        or a
        ret

.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B,D,E,H,L
tecfsMatchCatalogEntry:
        ld a,(hl)
        cp TFS_ENTRY_STATUS_ACTIVE
        jr nz,tecfsScanNoMatch
        inc hl
        inc hl
        ld a,(TFS_SCAN_PREFIX_ID)
        cp (hl)
        jr nz,tecfsScanNoMatch
        inc hl
        ld a,(TFS_SCAN_NAME_LEN)
        cp (hl)
        jr nz,tecfsScanNoMatch
        inc hl
        ld de,(TFS_SCAN_NAME_PTR)
        ld b,a
        jp tecfsMatchScanBytes

tecfsScanNoMatch:
        scf
        ret

.routine in B,DE,HL out A,carry,zero clobbers sign,parity,halfCarry,B,D,E,H,L
tecfsMatchScanBytes:
        ld a,(de)
        cp (hl)
        jr nz,tecfsScanNoMatch
        inc de
        inc hl
        djnz tecfsMatchScanBytes
        or a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsReadScanSector:
        ld a,(TFS_SCAN_SECTOR)
        ld (TFS_PARAM_SECTOR_0),a
        xor a
        ld (TFS_PARAM_SECTOR_1),a
        ld (TFS_PARAM_SECTOR_2),a
        ld (TFS_PARAM_SECTOR_3),a
        ld hl,TFS_CATALOG_BUFFER
        ld (TFS_PARAM_BUFFER_LO),hl
        jp tecfsReadSectorImpl

.routine out A,zero clobbers sign,parity,halfCarry,H,L
tecfsAdvanceScanSector:
        ld hl,TFS_SCAN_SECTOR
        inc (hl)
        ld hl,TFS_SCAN_SECTORS_LEFT
        dec (hl)
        ld a,(hl)
        or a
        ret

.routine out A,H,L clobbers zero,sign,parity,halfCarry,B,D,E
tecfsPrefixEntryAddress:
        ld hl,TFS_CATALOG_BUFFER
        ld a,(TFS_SCAN_ENTRY_INDEX)
        or a
        ret z
        ld b,a
        ld de,TFS_PREFIX_ENTRY_BYTES
tecfsPrefixEntryAddressNext:
        add hl,de
        djnz tecfsPrefixEntryAddressNext
        ret

.routine out A,H,L clobbers zero,sign,parity,halfCarry,B,D,E
tecfsCatalogEntryAddress:
        ld hl,TFS_CATALOG_BUFFER
        ld a,(TFS_SCAN_ENTRY_INDEX)
        or a
        ret z
        ld b,a
        ld de,TFS_CATALOG_ENTRY_BYTES
tecfsCatalogEntryAddressNext:
        add hl,de
        djnz tecfsCatalogEntryAddressNext
        ret

tecfsPublishScanError:
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        scf
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsLoadSourceImpl:
        ld hl,(TFS_PARAM_BUFFER_LO)
        ld a,h
        or l
        jp z,tecfsBadBuffer
        ld (TFS_PARAM_LOAD_CATALOG_LO),hl
        call tecfsDecodeCatalogImpl
        jp c,tecfsLoadSourceRestore
        ld a,(TFS_PARAM_ENTRY_FILE_TYPE)
        cp TFS_FILE_SOURCE
        jr z,tecfsLoadSourceTypeOk
        cp TFS_FILE_SOURCE_V1
        jp nz,tecfsLoadSourceBadCatalog
tecfsLoadSourceTypeOk:
        ld hl,(TFS_PARAM_ENTRY_SIZE_0)
        ld (TFS_PARAM_SOURCE_SIZE_LO),hl
        call tecfsSourcePageCount
        ld a,(TFS_PARAM_SOURCE_PAGE_COUNT)
        ld (TFS_PARAM_SOURCE_ALLOCATED_PAGES),a
        ld hl,(TFS_PARAM_LOAD_DEST_LO)
        ld a,h
        or l
        jp z,tecfsLoadSourceBadBuffer
        ld hl,(TFS_PARAM_LOAD_BYTES_LO)
        ld de,EDT_BUFFER_BYTES
        or a
        sbc hl,de
        jp c,tecfsLoadSourceBadBuffer
        xor a
        ld (TFS_PARAM_SOURCE_PAGE),a
tecfsLoadSourceNextPage:
        ld a,(TFS_PARAM_SOURCE_PAGE)
        ld b,a
        ld a,(TFS_PARAM_SOURCE_PAGE_COUNT)
        cp b
        jr z,tecfsLoadSourcePagesDone
        ld hl,(TFS_PARAM_LOAD_DEST_LO)
        ld a,b
        or a
        jr z,tecfsLoadSourceDestReady
        ld de,EDT_PAGE_BYTES
tecfsLoadSourceDestNext:
        add hl,de
        djnz tecfsLoadSourceDestNext
tecfsLoadSourceDestReady:
        ld (TFS_PARAM_BUFFER_LO),hl
        call tecfsLoadSourcePageCore
        jp c,tecfsLoadSourceRestore
        ld a,(TFS_PARAM_SOURCE_PAGE)
        inc a
        ld (TFS_PARAM_SOURCE_PAGE),a
        jr tecfsLoadSourceNextPage
tecfsLoadSourcePagesDone:
        call tecfsSourceLineCount
        xor a
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        ld a,0x82
        or a
tecfsLoadSourceRestore:
        ld hl,(TFS_PARAM_LOAD_CATALOG_LO)
        ld (TFS_PARAM_BUFFER_LO),hl
        ret

tecfsLoadSourceBadCatalog:
        ld a,TFS_ERR_BAD_CATALOG
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        scf
        jr tecfsLoadSourceRestore

tecfsLoadSourceBadBuffer:
        ld a,TFS_ERR_BAD_BUFFER
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        scf
        jr tecfsLoadSourceRestore

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsLoadSourcePageImpl:
        ld hl,(TFS_PARAM_LOAD_CATALOG_LO)
        ld a,h
        or l
        jp z,tecfsLoadSourceBadCatalog
        ld (TFS_PARAM_BUFFER_LO),hl
        call tecfsDecodeCatalogImpl
        ret c
        ld hl,(TFS_PARAM_LOAD_DEST_LO)
        ld (TFS_PARAM_BUFFER_LO),hl
        call tecfsLoadSourcePageCore
        ld hl,(TFS_PARAM_LOAD_CATALOG_LO)
        ld (TFS_PARAM_BUFFER_LO),hl
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsLoadSourcePageCore:
        call tecfsSourceMapPage
        ret c
        ld a,TFS_SOURCE_IO_DATA
        ld (TFS_PARAM_SOURCE_IO_KIND),a
        jp tecfsReadSectorImpl

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsSaveSourcePageImpl:
        ld hl,(TFS_PARAM_LOAD_CATALOG_LO)
        ld a,h
        or l
        jp z,tecfsLoadSourceBadCatalog
        ld (TFS_PARAM_BUFFER_LO),hl
        call tecfsDecodeCatalogImpl
        ret c
        ld hl,(TFS_PARAM_LOAD_DEST_LO)
        ld (TFS_PARAM_BUFFER_LO),hl
        call tecfsSourceMapPage
        jr c,tecfsSaveSourcePageRestore
        ld a,TFS_SOURCE_IO_DATA
        ld (TFS_PARAM_SOURCE_IO_KIND),a
        call tecfsWriteSectorImpl
        jr c,tecfsSaveSourcePageRestore
        ld a,(TFS_PARAM_SOURCE_DATA_WRITES)
        inc a
        ld (TFS_PARAM_SOURCE_DATA_WRITES),a
tecfsSaveSourcePageRestore:
        ld hl,(TFS_PARAM_LOAD_CATALOG_LO)
        ld (TFS_PARAM_BUFFER_LO),hl
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsCommitSourceMetaImpl:
        ld hl,(TFS_PARAM_LOAD_CATALOG_LO)
        ld a,h
        or l
        jp z,tecfsLoadSourceBadCatalog
        ld (TFS_PARAM_BUFFER_LO),hl
        ld de,TFS_CATALOG_OFFSET_SIZE
        add hl,de
        ld a,(TFS_PARAM_SOURCE_SIZE_LO)
        ld (hl),a
        inc hl
        ld a,(TFS_PARAM_SOURCE_SIZE_HI)
        ld (hl),a
        inc hl
        xor a
        ld (hl),a
        inc hl
        ld (hl),a
        call tecfsUsingMon3FileDriver
        jp z,tecfsCommitSourceMetaMon3
        ld hl,(TFS_PARAM_LOAD_CATALOG_LO)
        ld (TFS_PARAM_BUFFER_LO),hl
        ld hl,TFS_IMAGE_BASE_LBA_0 + (TFS_IMAGE_BASE_LBA_1 * 256)
        ld (TFS_PARAM_SECTOR_0),hl
        ld a,TFS_IMAGE_BASE_LBA_2
        ld (TFS_PARAM_SECTOR_2),a
        ld a,TFS_IMAGE_BASE_LBA_3
        ld (TFS_PARAM_SECTOR_3),a
        ld a,TFS_SOURCE_IO_META
        ld (TFS_PARAM_SOURCE_IO_KIND),a
        call tecfsWriteSectorImpl
        ret c
        ld a,(TFS_PARAM_SOURCE_META_WRITES)
        inc a
        ld (TFS_PARAM_SOURCE_META_WRITES),a
        ld hl,(TFS_PARAM_LOAD_CATALOG_LO)
        ld (TFS_PARAM_BUFFER_LO),hl
        ret

; Commit the size into the exact catalogue sector/slot found by
; TFS_SVC_FIND_PATH. Data pages are written first; the catalogue sector is
; read-modify-written last, so an interrupted save never publishes a size for
; data which did not reach the SD image.
tecfsCommitSourceMetaMon3:
        ld a,(TFS_SCAN_CATALOG_SECTOR)
        ld (TFS_PARAM_SECTOR_0),a
        xor a
        ld (TFS_PARAM_SECTOR_1),a
        ld (TFS_PARAM_SECTOR_2),a
        ld (TFS_PARAM_SECTOR_3),a
        ld hl,TFS_CATALOG_BUFFER
        ld (TFS_PARAM_BUFFER_LO),hl
        ld a,TFS_SOURCE_IO_META
        ld (TFS_PARAM_SOURCE_IO_KIND),a
        call tecfsReadSectorImpl
        ret c
        call tecfsCatalogCommitEntryAddress
        ld de,TFS_CATALOG_OFFSET_SIZE
        add hl,de
        ld a,(TFS_PARAM_SOURCE_SIZE_LO)
        ld (hl),a
        inc hl
        ld a,(TFS_PARAM_SOURCE_SIZE_HI)
        ld (hl),a
        inc hl
        xor a
        ld (hl),a
        inc hl
        ld (hl),a
        ld hl,TFS_CATALOG_BUFFER
        ld (TFS_PARAM_BUFFER_LO),hl
        call tecfsWriteSectorImpl
        ret c
        call tecfsCatalogCommitEntryAddress
        ld de,TFS_CATALOG_BUFFER
        ld bc,TFS_CATALOG_ENTRY_BYTES
        ldir
        ld hl,TFS_CATALOG_BUFFER
        ld (TFS_PARAM_BUFFER_LO),hl
        ld (TFS_PARAM_LOAD_CATALOG_LO),hl
        ld a,(TFS_PARAM_SOURCE_META_WRITES)
        inc a
        ld (TFS_PARAM_SOURCE_META_WRITES),a
        xor a
        ret

.routine out H,L clobbers F,D,E
tecfsCatalogCommitEntryAddress:
        ld hl,TFS_CATALOG_BUFFER
        ld de,(TFS_SCAN_CATALOG_OFFSET_LO)
        add hl,de
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsSaveArtifactImpl:
        call tecfsValidateArtifactParams
        ret c
        call tecfsUsingMon3FileDriver
        jp z,tecfsSaveArtifactReal
        call tecfsArtifactSetSector
        ld hl,(TFS_PARAM_ARTIFACT_BUFFER_LO)
        ld (TFS_PARAM_BUFFER_LO),hl
        ld a,(TFS_PARAM_ARTIFACT_KIND)
        cp TFS_ARTIFACT_KIND_BINARY
        ld a,TFS_ARTIFACT_IO_BINARY_DATA
        jr z,tecfsSaveArtifactDataKindReady
        ld a,TFS_ARTIFACT_IO_MAP_DATA
tecfsSaveArtifactDataKindReady:
        ld (TFS_PARAM_ARTIFACT_IO_KIND),a
        ld (TFS_PARAM_SOURCE_IO_KIND),a
        call tecfsWriteSectorImpl
        ret c
        ld a,(TFS_PARAM_ARTIFACT_DATA_WRITES)
        inc a
        ld (TFS_PARAM_ARTIFACT_DATA_WRITES),a
        call tecfsBuildArtifactMeta
        ret c
        call tecfsArtifactSetSector
        ld hl,TFS_ARTIFACT_META_BUFFER
        ld (TFS_PARAM_BUFFER_LO),hl
        ld a,(TFS_PARAM_ARTIFACT_KIND)
        cp TFS_ARTIFACT_KIND_BINARY
        ld a,TFS_ARTIFACT_IO_BINARY_META
        jr z,tecfsSaveArtifactMetaKindReady
        ld a,TFS_ARTIFACT_IO_MAP_META
tecfsSaveArtifactMetaKindReady:
        ld (TFS_PARAM_ARTIFACT_IO_KIND),a
        ld (TFS_PARAM_SOURCE_IO_KIND),a
        call tecfsWriteSectorImpl
        ret c
        ld a,(TFS_PARAM_ARTIFACT_META_WRITES)
        inc a
        ld (TFS_PARAM_ARTIFACT_META_WRITES),a
        xor a
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        ld a,0x82
        or a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsLoadArtifactImpl:
        ld a,(TFS_PARAM_ARTIFACT_KIND)
        cp TFS_ARTIFACT_KIND_BINARY
        jp nz,tecfsBadArtifact
        call tecfsUsingMon3FileDriver
        jp z,tecfsLoadArtifactReal
        call tecfsArtifactSetSector
        ld hl,TFS_ARTIFACT_META_BUFFER
        ld (TFS_PARAM_BUFFER_LO),hl
        ld a,TFS_ARTIFACT_IO_BINARY_META
        ld (TFS_PARAM_ARTIFACT_IO_KIND),a
        ld (TFS_PARAM_SOURCE_IO_KIND),a
        call tecfsReadSectorImpl
        ret c
        call tecfsReadArtifactMeta
        ret c
        call tecfsValidateRunnableArtifact
        ret c
        call tecfsArtifactSetSector
        ld hl,(TFS_PARAM_ARTIFACT_LOAD_LO)
        ld (TFS_PARAM_BUFFER_LO),hl
        ld a,TFS_ARTIFACT_IO_BINARY_DATA
        ld (TFS_PARAM_ARTIFACT_IO_KIND),a
        ld (TFS_PARAM_SOURCE_IO_KIND),a
        call tecfsReadSectorImpl
        ret c
        xor a
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        ld a,0x82
        or a
        ret

; Real MON3/SD artifact path. The catalogue entry names the raw .bin/.map
; payload stored in sector zero of its allocation block. Sector seven is a
; private TFM1 sidecar, leaving host export of the catalogue file byte-exact.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsSaveArtifactReal:
        call tecfsArtifactResolveForSave
        ret c
        xor a
        call tecfsArtifactMapSectorReal
        ret c
        ld hl,(TFS_PARAM_ARTIFACT_BUFFER_LO)
        ld (TFS_PARAM_BUFFER_LO),hl
        call tecfsArtifactPublishDataKind
        call tecfsWriteSectorImpl
        ret c
        ld a,(TFS_PARAM_ARTIFACT_DATA_WRITES)
        inc a
        ld (TFS_PARAM_ARTIFACT_DATA_WRITES),a
        call tecfsBuildArtifactMeta
        ret c
        ld a,0x07
        call tecfsArtifactMapSectorReal
        ret c
        ld hl,TFS_ARTIFACT_META_BUFFER
        ld (TFS_PARAM_BUFFER_LO),hl
        call tecfsArtifactPublishMetaKind
        call tecfsWriteSectorImpl
        ret c
        ld a,(TFS_PARAM_ARTIFACT_META_WRITES)
        inc a
        ld (TFS_PARAM_ARTIFACT_META_WRITES),a
        call tecfsCommitArtifactCatalog
        ret c
        xor a
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        ld a,0x82
        or a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsLoadArtifactReal:
        call tecfsArtifactFindPath
        ret c
        ld a,(TFS_PARAM_ENTRY_FILE_TYPE)
        cp TFS_FILE_BINARY
        jp nz,tecfsBadArtifact
        ld hl,(TFS_PARAM_ENTRY_SIZE_0)
        ld a,h
        cp 0x02
        jp nc,tecfsBadArtifact
        ld a,h
        or l
        jp z,tecfsBadArtifact
        ld (TFS_PARAM_SOURCE_SIZE_LO),hl
        ld a,0x07
        call tecfsArtifactMapSectorReal
        ret c
        ld hl,TFS_ARTIFACT_META_BUFFER
        ld (TFS_PARAM_BUFFER_LO),hl
        ld a,TFS_ARTIFACT_IO_BINARY_META
        ld (TFS_PARAM_ARTIFACT_IO_KIND),a
        ld (TFS_PARAM_SOURCE_IO_KIND),a
        call tecfsReadSectorImpl
        ret c
        call tecfsReadArtifactMeta
        ret c
        call tecfsValidateRunnableArtifact
        ret c
        ld hl,(TFS_PARAM_ARTIFACT_SIZE_LO)
        ld de,(TFS_PARAM_SOURCE_SIZE_LO)
        or a
        sbc hl,de
        jp nz,tecfsBadArtifact
        xor a
        call tecfsArtifactMapSectorReal
        ret c
        ld hl,(TFS_PARAM_ARTIFACT_LOAD_LO)
        ld (TFS_PARAM_BUFFER_LO),hl
        ld a,TFS_ARTIFACT_IO_BINARY_DATA
        ld (TFS_PARAM_ARTIFACT_IO_KIND),a
        ld (TFS_PARAM_SOURCE_IO_KIND),a
        call tecfsReadSectorImpl
        ret c
        xor a
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        ld a,0x82
        or a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsArtifactResolveForSave:
        call tecfsArtifactFindPath
        jr nc,tecfsArtifactValidateResolvedType
        ld a,(TFS_PARAM_LAST_ERROR)
        cp TFS_ERR_NOT_FOUND
        ret nz
        ld a,(TFS_PARAM_ARTIFACT_KIND)
        cp TFS_ARTIFACT_KIND_BINARY
        ld a,TFS_FILE_BINARY
        jr z,tecfsArtifactCreateTypeReady
        ld a,TFS_FILE_ASSET
tecfsArtifactCreateTypeReady:
        ld (TFS_PARAM_CREATE_FILE_TYPE),a
        call tecfsCreateFileImpl
        ret c
        call tecfsArtifactFindPath
        ret c
tecfsArtifactValidateResolvedType:
        ld a,(TFS_PARAM_ARTIFACT_KIND)
        cp TFS_ARTIFACT_KIND_BINARY
        ld a,TFS_FILE_BINARY
        jr z,tecfsArtifactExpectedTypeReady
        ld a,TFS_FILE_ASSET
tecfsArtifactExpectedTypeReady:
        ld b,a
        ld a,(TFS_PARAM_ENTRY_FILE_TYPE)
        cp b
        jp nz,tecfsBadArtifact
        or a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsArtifactFindPath:
        ld hl,(TFS_PARAM_ARTIFACT_PATH_LO)
        ld a,h
        or l
        jp z,tecfsBadArtifact
        ld (TFS_PARAM_PATH_LO),hl
        jp tecfsFindPathImpl

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,D,E,H,L
tecfsArtifactMapSectorReal:
        ld (TFS_PARAM_SOURCE_PAGE),a
        ld a,(TFS_PARAM_ENTRY_FIRST_BLOCK_LO)
        ld (TFS_PARAM_BLOCK_INDEX_LO),a
        ld a,(TFS_PARAM_ENTRY_FIRST_BLOCK_HI)
        ld (TFS_PARAM_BLOCK_INDEX_HI),a
        call tecfsMapBlockImpl
        ret c
        ld a,(TFS_PARAM_SOURCE_PAGE)
        ld e,a
        ld d,0x00
        ld hl,(TFS_PARAM_SECTOR_0)
        add hl,de
        ld (TFS_PARAM_SECTOR_0),hl
        or a
        ret

.routine out A,zero clobbers sign,parity,halfCarry
tecfsArtifactPublishDataKind:
        ld a,(TFS_PARAM_ARTIFACT_KIND)
        cp TFS_ARTIFACT_KIND_BINARY
        ld a,TFS_ARTIFACT_IO_BINARY_DATA
        jr z,tecfsArtifactPublishKind
        ld a,TFS_ARTIFACT_IO_MAP_DATA
        jr tecfsArtifactPublishKind

.routine out A,zero clobbers sign,parity,halfCarry
tecfsArtifactPublishMetaKind:
        ld a,(TFS_PARAM_ARTIFACT_KIND)
        cp TFS_ARTIFACT_KIND_BINARY
        ld a,TFS_ARTIFACT_IO_BINARY_META
        jr z,tecfsArtifactPublishKind
        ld a,TFS_ARTIFACT_IO_MAP_META
tecfsArtifactPublishKind:
        ld (TFS_PARAM_ARTIFACT_IO_KIND),a
        ld (TFS_PARAM_SOURCE_IO_KIND),a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsCommitArtifactCatalog:
        ld a,(TFS_SCAN_CATALOG_SECTOR)
        ld (TFS_PARAM_SECTOR_0),a
        xor a
        ld (TFS_PARAM_SECTOR_1),a
        ld (TFS_PARAM_SECTOR_2),a
        ld (TFS_PARAM_SECTOR_3),a
        ld hl,TFS_CATALOG_BUFFER
        ld (TFS_PARAM_BUFFER_LO),hl
        call tecfsArtifactPublishMetaKind
        call tecfsReadSectorImpl
        ret c
        call tecfsCatalogCommitEntryAddress
        ld de,TFS_CATALOG_OFFSET_SIZE
        add hl,de
        ld de,(TFS_PARAM_ARTIFACT_SIZE_LO)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        xor a
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld a,(TFS_PARAM_ARTIFACT_KIND)
        cp TFS_ARTIFACT_KIND_BINARY
        ld a,TFS_FILE_BINARY
        jr z,tecfsCommitArtifactTypeReady
        ld a,TFS_FILE_ASSET
tecfsCommitArtifactTypeReady:
        ld (hl),a
        ld hl,TFS_CATALOG_BUFFER
        ld (TFS_PARAM_BUFFER_LO),hl
        call tecfsWriteSectorImpl
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,H,L
tecfsValidateArtifactParams:
        ld a,(TFS_PARAM_ARTIFACT_KIND)
        cp TFS_ARTIFACT_KIND_BINARY
        jr z,tecfsValidateArtifactKindOk
        cp TFS_ARTIFACT_KIND_MAP
        jp nz,tecfsBadArtifact
tecfsValidateArtifactKindOk:
        ld hl,(TFS_PARAM_ARTIFACT_BUFFER_LO)
        ld a,h
        or l
        jp z,tecfsBadBuffer
        ld hl,(TFS_PARAM_ARTIFACT_SIZE_LO)
        ld a,h
        cp 0x02
        jr c,tecfsValidateArtifactSizeOk
        jp nz,tecfsBadArtifact
        ld a,l
        or a
        jp nz,tecfsBadArtifact
tecfsValidateArtifactSizeOk:
        ld a,h
        or l
        jp z,tecfsBadArtifact
        or a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,D,E,H,L
tecfsBuildArtifactMeta:
        ld hl,TFS_ARTIFACT_META_BUFFER
        ld (TFS_PARAM_BUFFER_LO),hl
        call tecfsFormatMetaRecordImpl
        ret c
        ld a,(TFS_PARAM_ARTIFACT_KIND)
        cp TFS_ARTIFACT_KIND_BINARY
        jr z,tecfsBuildBinaryMeta
        ld a,TFS_FILE_ASSET
        ld (TFS_META_PATCH_FILE_TYPE),a
        xor a
        ld (TFS_META_PATCH_FLAGS),a
        ld (TFS_META_PATCH_LOAD_LO),a
        ld (TFS_META_PATCH_LOAD_HI),a
        ld (TFS_META_PATCH_RUN_LO),a
        ld (TFS_META_PATCH_RUN_HI),a
        ld hl,(TFS_PARAM_ARTIFACT_SIZE_LO)
        ld (TFS_META_PATCH_END_LO),hl
        jr tecfsBuildArtifactMetaCommon
tecfsBuildBinaryMeta:
        ld a,TFS_FILE_BINARY
        ld (TFS_META_PATCH_FILE_TYPE),a
        ld a,TFS_META_FLAG_EXECUTABLE
        ld (TFS_META_PATCH_FLAGS),a
        ld hl,(TFS_PARAM_ARTIFACT_LOAD_LO)
        ld (TFS_META_PATCH_LOAD_LO),hl
        ld de,(TFS_PARAM_ARTIFACT_SIZE_LO)
        add hl,de
        ld (TFS_META_PATCH_END_LO),hl
        ld hl,(TFS_PARAM_ARTIFACT_RUN_LO)
        ld (TFS_META_PATCH_RUN_LO),hl
tecfsBuildArtifactMetaCommon:
        xor a
        ld (TFS_META_PATCH_HW_LO),a
        ld (TFS_META_PATCH_HW_HI),a
        ld (TFS_META_PATCH_NAME_REF_LO),a
        ld (TFS_META_PATCH_NAME_REF_HI),a
        ld hl,TFS_ARTIFACT_META_BUFFER
        ld (TFS_PARAM_BUFFER_LO),hl
        jp tecfsPatchMetaRecordImpl

.routine out A,carry,zero clobbers sign,parity,halfCarry,D,E,H,L
tecfsReadArtifactMeta:
        ld hl,TFS_ARTIFACT_META_BUFFER
        ld a,(hl)
        cp TFS_META_MAGIC_0
        jp nz,tecfsBadArtifact
        inc hl
        ld a,(hl)
        cp TFS_META_MAGIC_1
        jp nz,tecfsBadArtifact
        inc hl
        ld a,(hl)
        cp TFS_META_MAGIC_2
        jp nz,tecfsBadArtifact
        inc hl
        ld a,(hl)
        cp TFS_META_MAGIC_3
        jp nz,tecfsBadArtifact
        inc hl
        ld a,(hl)
        cp TFS_META_VERSION
        jp nz,tecfsBadArtifact
        ld de,TFS_META_OFFSET_FILE_TYPE-TFS_META_OFFSET_VERSION
        add hl,de
        ld a,(hl)
        cp TFS_FILE_BINARY
        jp nz,tecfsBadArtifact
        inc hl
        ld a,(hl)
        and TFS_META_FLAG_EXECUTABLE
        jp z,tecfsBadArtifact
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (TFS_PARAM_ARTIFACT_LOAD_LO),de
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (RUN_PARAM_END_LO),de
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (TFS_PARAM_ARTIFACT_RUN_LO),de
        or a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,D,E,H,L
tecfsValidateRunnableArtifact:
        ld hl,(TFS_PARAM_ARTIFACT_LOAD_LO)
        ld de,RUN_LOAD_MIN
        or a
        sbc hl,de
        jp c,tecfsBadArtifact
        ld hl,(RUN_PARAM_END_LO)
        ld de,RUN_LOAD_MAX+1
        or a
        sbc hl,de
        jp nc,tecfsBadArtifact
        ld hl,(RUN_PARAM_END_LO)
        ld de,(TFS_PARAM_ARTIFACT_LOAD_LO)
        or a
        sbc hl,de
        jp c,tecfsBadArtifact
        ld a,h
        or l
        jp z,tecfsBadArtifact
        ld (TFS_PARAM_ARTIFACT_SIZE_LO),hl
        ld hl,(TFS_PARAM_ARTIFACT_RUN_LO)
        ld de,(TFS_PARAM_ARTIFACT_LOAD_LO)
        or a
        sbc hl,de
        jp c,tecfsBadArtifact
        ld hl,(TFS_PARAM_ARTIFACT_RUN_LO)
        ld de,(RUN_PARAM_END_LO)
        or a
        sbc hl,de
        jp nc,tecfsBadArtifact
        or a
        ret

.routine out A,zero clobbers sign,parity,halfCarry,H,L
tecfsArtifactSetSector:
        ld hl,TFS_IMAGE_BASE_LBA_0 + (TFS_IMAGE_BASE_LBA_1 * 256)
        ld (TFS_PARAM_SECTOR_0),hl
        ld a,TFS_IMAGE_BASE_LBA_2
        ld (TFS_PARAM_SECTOR_2),a
        ld a,TFS_IMAGE_BASE_LBA_3
        ld (TFS_PARAM_SECTOR_3),a
        ret

tecfsBadArtifact:
        ld a,TFS_ERR_BAD_CATALOG
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        scf
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,D,E,H,L
tecfsSourceMapPage:
        ld a,(TFS_PARAM_ENTRY_FIRST_BLOCK_LO)
        ld (TFS_PARAM_BLOCK_INDEX_LO),a
        ld a,(TFS_PARAM_ENTRY_FIRST_BLOCK_HI)
        ld (TFS_PARAM_BLOCK_INDEX_HI),a
        call tecfsMapBlockImpl
        ret c
        ld a,(TFS_PARAM_SOURCE_PAGE)
        ld e,a
        ld d,0x00
        ld hl,(TFS_PARAM_SECTOR_0)
        add hl,de
        ld (TFS_PARAM_SECTOR_0),hl
        call tecfsUsingMon3FileDriver
        ret z
        jp tecfsTranslateSectorImpl

.routine out A,carry,zero clobbers sign,parity,halfCarry,H,L
tecfsUsingMon3FileDriver:
        ld hl,(TFS_PARAM_DRIVER_ADDR_LO)
        ld a,h
        cp TFS_MON3_FILE_DRIVER / 256
        ret nz
        ld a,l
        cp TFS_MON3_FILE_DRIVER & 0xFF
        ret

.routine out A,zero clobbers sign,parity,halfCarry,H,L
tecfsSourcePageCount:
        ld hl,(TFS_PARAM_SOURCE_SIZE_LO)
        ld a,h
        or l
        jr nz,tecfsSourcePageCountNonzero
        ld a,0x01
        jr tecfsSourcePageCountStore
tecfsSourcePageCountNonzero:
        ld a,h
        cp 0x02
        jr c,tecfsSourcePageCountOne
        cp 0x04
        jr c,tecfsSourcePageCountUpToTwo
        cp 0x06
        jr nc,tecfsSourcePageCountMax
        cp 0x04
        jr nz,tecfsSourcePageCountMax
        ld a,l
        or a
        ld a,0x02
        jr z,tecfsSourcePageCountStore
        ld a,0x03
        jr tecfsSourcePageCountStore
tecfsSourcePageCountUpToTwo:
        cp 0x02
        jr nz,tecfsSourcePageCountTwo
        ld a,l
        or a
        jr z,tecfsSourcePageCountOne
tecfsSourcePageCountTwo:
        ld a,0x02
        jr tecfsSourcePageCountStore
tecfsSourcePageCountOne:
        ld a,0x01
        jr tecfsSourcePageCountStore
tecfsSourcePageCountMax:
        ld a,TFS_SOURCE_MAX_PAGES
tecfsSourcePageCountStore:
        ld (TFS_PARAM_SOURCE_PAGE_COUNT),a
        ret

.routine out A,zero clobbers sign,parity,halfCarry,H,L
tecfsSourceLineCount:
        ld a,(TFS_PARAM_ENTRY_SIZE_2)
        ld h,a
        ld a,(TFS_PARAM_ENTRY_SIZE_3)
        or h
        jr nz,tecfsSourceLineCountFull
        ld hl,(TFS_PARAM_ENTRY_SIZE_0)
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld a,h
        or a
        jr nz,tecfsSourceLineCountFull
        ld a,l
        cp EDT_BUFFER_RECORDS+1
        jr nc,tecfsSourceLineCountFull
        ld (TFS_PARAM_LOAD_LINES_LO),a
        xor a
        ld (TFS_PARAM_LOAD_LINES_HI),a
        ret
tecfsSourceLineCountFull:
        ld a,EDT_BUFFER_RECORDS
        ld (TFS_PARAM_LOAD_LINES_LO),a
        xor a
        ld (TFS_PARAM_LOAD_LINES_HI),a
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
