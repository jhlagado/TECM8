; TECM8 expansion ROM physical bank 5: TEC-FS monitor-sector bridge.

        .include "bank_ops.asmi"

        .org    0x8000

EXP_BANK          .equ    0x05
EXP_VERSION       .equ    0x01

Tecm8ExpansionBank5Entry:
        cp TFS_DRIVER_OP_READ
        jp z,tecfsSectorBridgeRead
        cp TFS_DRIVER_OP_WRITE
        jp z,tecfsSectorBridgeWrite
        ld a,SVC_ERR_UNKNOWN
        scf
        ret

tecfsSectorBridgeRead:
        call tecfsSectorBridgeInit
        ld a,(TFS_BRIDGE_READ_COUNT)
        inc a
        ld (TFS_BRIDGE_READ_COUNT),a
        call tecfsSectorBridgeReadIncludeFixture
        ret nc
        ld a,(TFS_PARAM_SOURCE_IO_KIND)
        cp TFS_SOURCE_IO_META
        jp z,tecfsSectorBridgeReadMeta
        cp TFS_ARTIFACT_IO_BINARY_DATA
        jp z,tecfsSectorBridgeReadBinary
        cp TFS_ARTIFACT_IO_BINARY_META
        jp z,tecfsSectorBridgeReadBinaryMeta
        cp TFS_ARTIFACT_IO_MAP_DATA
        jp z,tecfsSectorBridgeReadMap
        cp TFS_ARTIFACT_IO_MAP_META
        jp z,tecfsSectorBridgeReadMapMeta
        call tecfsSectorBridgePageAddress
        ld de,(TFS_PARAM_BUFFER_LO)
        ld bc,EDT_PAGE_BYTES
        ldir
        jp tecfsSectorBridgeOk

tecfsSectorBridgeReadMeta:
        ld hl,TFS_BRIDGE_META_BASE
        ld de,(TFS_PARAM_BUFFER_LO)
        ld bc,TFS_CATALOG_ENTRY_BYTES
        ldir
        jp tecfsSectorBridgeOk

tecfsSectorBridgeReadBinary:
        ld hl,TFS_BRIDGE_BINARY_BASE
        jr tecfsSectorBridgeReadArtifactData

tecfsSectorBridgeReadMap:
        ld hl,TFS_BRIDGE_MAP_BASE
tecfsSectorBridgeReadArtifactData:
        ld de,(TFS_PARAM_BUFFER_LO)
        ld bc,TFS_ARTIFACT_MAX_BYTES
        ldir
        jp tecfsSectorBridgeOk

tecfsSectorBridgeReadBinaryMeta:
        ld hl,TFS_BRIDGE_BINARY_META_BASE
        jr tecfsSectorBridgeReadArtifactMeta

tecfsSectorBridgeReadMapMeta:
        ld hl,TFS_BRIDGE_MAP_META_BASE
tecfsSectorBridgeReadArtifactMeta:
        ld de,(TFS_PARAM_BUFFER_LO)
        ld bc,TFS_META_RECORD_BYTES
        ldir
        jp tecfsSectorBridgeOk

tecfsSectorBridgeWrite:
        call tecfsSectorBridgeInit
        ld a,(TFS_BRIDGE_WRITE_COUNT)
        inc a
        ld (TFS_BRIDGE_WRITE_COUNT),a
        ld a,(TFS_PARAM_SOURCE_IO_KIND)
        cp TFS_SOURCE_IO_META
        jr z,tecfsSectorBridgeWriteMeta
        cp TFS_ARTIFACT_IO_BINARY_DATA
        jr z,tecfsSectorBridgeWriteBinary
        cp TFS_ARTIFACT_IO_BINARY_META
        jr z,tecfsSectorBridgeWriteBinaryMeta
        cp TFS_ARTIFACT_IO_MAP_DATA
        jr z,tecfsSectorBridgeWriteMap
        cp TFS_ARTIFACT_IO_MAP_META
        jr z,tecfsSectorBridgeWriteMapMeta
        call tecfsSectorBridgePageAddress
        ex de,hl
        ld hl,(TFS_PARAM_BUFFER_LO)
        ld bc,EDT_PAGE_BYTES
        ldir
        ld a,(TFS_BRIDGE_DATA_WRITE_COUNT)
        inc a
        ld (TFS_BRIDGE_DATA_WRITE_COUNT),a
        jp tecfsSectorBridgeOk

tecfsSectorBridgeWriteMeta:
        ld hl,(TFS_PARAM_BUFFER_LO)
        ld de,TFS_BRIDGE_META_BASE
        ld bc,TFS_CATALOG_ENTRY_BYTES
        ldir
        ld a,(TFS_BRIDGE_META_WRITE_COUNT)
        inc a
        ld (TFS_BRIDGE_META_WRITE_COUNT),a
        jp tecfsSectorBridgeOk

tecfsSectorBridgeWriteBinary:
        ld de,TFS_BRIDGE_BINARY_BASE
        jr tecfsSectorBridgeWriteArtifactData

tecfsSectorBridgeWriteMap:
        ld de,TFS_BRIDGE_MAP_BASE
tecfsSectorBridgeWriteArtifactData:
        ld hl,(TFS_PARAM_BUFFER_LO)
        ld bc,TFS_ARTIFACT_MAX_BYTES
        ldir
        ld a,(TFS_BRIDGE_ARTIFACT_DATA_WRITES)
        inc a
        ld (TFS_BRIDGE_ARTIFACT_DATA_WRITES),a
        jp tecfsSectorBridgeOk

tecfsSectorBridgeWriteBinaryMeta:
        ld de,TFS_BRIDGE_BINARY_META_BASE
        jr tecfsSectorBridgeWriteArtifactMeta

tecfsSectorBridgeWriteMapMeta:
        ld de,TFS_BRIDGE_MAP_META_BASE
tecfsSectorBridgeWriteArtifactMeta:
        ld hl,(TFS_PARAM_BUFFER_LO)
        ld bc,TFS_META_RECORD_BYTES
        ldir
        ld a,(TFS_BRIDGE_ARTIFACT_META_WRITES)
        inc a
        ld (TFS_BRIDGE_ARTIFACT_META_WRITES),a
        jp tecfsSectorBridgeOk

tecfsSectorBridgeOk:
        xor a
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        ld a,0x85
        or a
        ret

.routine out A,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsSectorBridgeInit:
        ld a,(TFS_BRIDGE_INITIALIZED)
        cp TFS_BRIDGE_READ_MARKER
        ret z
        ld hl,TFS_BRIDGE_STORE_BASE
        ld de,TFS_BRIDGE_STORE_BASE+1
        ld bc,(EDT_PAGE_BYTES*EDT_BUFFER_PAGES)-1
        xor a
        ld (hl),a
        ldir
        ld hl,Tecm8SourceFixture
        ld de,TFS_BRIDGE_STORE_BASE
        ld bc,Tecm8SourceFixtureEnd-Tecm8SourceFixture
        ldir
        ld hl,TFS_BRIDGE_META_BASE
        ld de,TFS_BRIDGE_META_BASE+1
        ld bc,TFS_CATALOG_ENTRY_BYTES-1
        xor a
        ld (hl),a
        ldir
        ld hl,TFS_BRIDGE_BINARY_BASE
        ld de,TFS_BRIDGE_BINARY_BASE+1
        ld bc,(TFS_BRIDGE_MAP_META_BASE+TFS_META_RECORD_BYTES)-TFS_BRIDGE_BINARY_BASE-1
        ld (hl),a
        ldir
        ld a,TFS_BRIDGE_READ_MARKER
        ld (TFS_BRIDGE_INITIALIZED),a
        xor a
        ld (TFS_BRIDGE_READ_COUNT),a
        ld (TFS_BRIDGE_WRITE_COUNT),a
        ld (TFS_BRIDGE_DATA_WRITE_COUNT),a
        ld (TFS_BRIDGE_META_WRITE_COUNT),a
        ld (TFS_BRIDGE_ARTIFACT_DATA_WRITES),a
        ld (TFS_BRIDGE_ARTIFACT_META_WRITES),a
        ret

.routine out A,H,L clobbers zero,sign,parity,halfCarry,B,D,E
tecfsSectorBridgePageAddress:
        ld hl,TFS_BRIDGE_STORE_BASE
        ld a,(TFS_PARAM_SOURCE_PAGE)
        or a
        ret z
        ld b,a
        ld de,EDT_PAGE_BYTES
tecfsSectorBridgePageAddressNext:
        add hl,de
        djnz tecfsSectorBridgePageAddressNext
        ret

Tecm8ExpansionBank5Info:
        .db     "T","M","8",EXP_BANK,EXP_VERSION

Tecm8SourceFixture:
        .db     0xA5,"ORG 0"
        .ds     26
        .db     0x06,"LD A,1"
        .ds     25
        .db     0x03,"RET"
        .ds     28
Tecm8SourceFixtureEnd:

; Real MON3/FAT32 sector driver.
;
; This entry treats TFS_PARAM_SECTOR_0..3 as a sector number relative to the
; VOLUME.TM8 host file. It deliberately opens the file for every operation so
; another MON3 client cannot leave C_FILENO pointing at an unrelated file.
; The legacy 8000h entry above remains the deterministic RAM-backed proof
; bridge.

        .org    TFS_MON3_FILE_DRIVER

Tecm8Mon3FileDriverEntry:
        cp TFS_DRIVER_OP_READ
        jp z,tecfsMon3FileRead
        cp TFS_DRIVER_OP_WRITE
        jp z,tecfsMon3FileWrite
        ld a,SVC_ERR_UNKNOWN
        scf
        ret

tecfsMon3FileRead:
        call tecfsMon3FilePrepare
        ret c
        ld a,2
        ld (TFS_MON3_ERROR_STAGE),a
        call readSector
        jp c,tecfsMon3FileError
        ld hl,MON_DISK_BUFFER
        ld de,(TFS_MON3_BUFFER_PTR)
        ld bc,EDT_PAGE_BYTES
        ldir
        jp tecfsMon3FileOk

tecfsMon3FileWrite:
        call tecfsMon3FilePrepare
        ret c
        ld a,(TFS_MON3_FAIL_WRITE_COUNTDOWN)
        or a
        jr z,tecfsMon3FileWriteReady
        dec a
        ld (TFS_MON3_FAIL_WRITE_COUNTDOWN),a
        jr nz,tecfsMon3FileWriteReady
        ld a,(TFS_MON3_FAIL_WRITE_COUNT)
        inc a
        ld (TFS_MON3_FAIL_WRITE_COUNT),a
        ld a,TFS_ERR_DRIVER_IO
        jp tecfsMon3FilePublishError
tecfsMon3FileWriteReady:
        ; MON3 records the target physical sector during readSector; every
        ; write must therefore be preceded by a read of the same file offset.
        ld a,2
        ld (TFS_MON3_ERROR_STAGE),a
        call readSector
        jp c,tecfsMon3FileError
        ld hl,(TFS_MON3_BUFFER_PTR)
        ld de,MON_DISK_BUFFER
        ld bc,EDT_PAGE_BYTES
        ldir
        ld a,3
        ld (TFS_MON3_ERROR_STAGE),a
        call writeSector
        jp c,tecfsMon3FileError
        jp tecfsMon3FileOk

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsMon3FilePrepare:
        ld hl,(TFS_PARAM_BUFFER_LO)
        ld a,h
        or l
        jr z,tecfsMon3FileBadBuffer
        ld (TFS_MON3_BUFFER_PTR),hl
        ld a,1
        ld (TFS_MON3_ERROR_STAGE),a
        ld hl,Tecm8Mon3VolumeName
        call openFile
        jp c,tecfsMon3FileError
        call tecfsMon3SectorToOffset
        ret

tecfsMon3FileBadBuffer:
        ld a,TFS_ERR_BAD_BUFFER
        jr tecfsMon3FilePublishError

tecfsMon3FileError:
        ld a,TFS_ERR_DRIVER_IO
tecfsMon3FilePublishError:
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        scf
        ret

; Convert a little-endian 32-bit sector number to MON3's HLDE byte offset.
; VOLUME.TM8 is currently 4 MiB, so accepting the full 23-bit sector range
; remains comfortably bounded while rejecting values that overflow on << 9.
.routine out A,DE,HL,carry,zero clobbers sign,parity,halfCarry
tecfsMon3SectorToOffset:
        ld a,(TFS_PARAM_SECTOR_3)
        or a
        jr nz,tecfsMon3FileBadSector
        ld a,(TFS_PARAM_SECTOR_0)
        add a,a
        ld d,a
        ld e,0
        ld a,(TFS_PARAM_SECTOR_1)
        rla
        ld l,a
        ld a,(TFS_PARAM_SECTOR_2)
        rla
        ld h,a
        jr c,tecfsMon3FileBadSector
        or a
        ret

tecfsMon3FileBadSector:
        ld a,TFS_ERR_BAD_SECTOR
        jr tecfsMon3FilePublishError

tecfsMon3FileOk:
        xor a
        ld (TFS_MON3_ERROR_STAGE),a
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        ld a,0x85
        or a
        ret

Tecm8Mon3VolumeName:
        .db     "VOLUME.TM8",0

; Deterministic include catalogue used only by the 8000h RAM bridge. Keeping
; this behind the fixed 8200h MON3 entry prevents proof growth from shadowing
; the real SD driver.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsSectorBridgeReadIncludeFixture:
        ld a,(TFS_PARAM_SECTOR_3)
        or a
        jr nz,tecfsSectorBridgeReadIncludeMissing
        ld a,(TFS_PARAM_SECTOR_2)
        or a
        jr nz,tecfsSectorBridgeReadIncludeMissing
        ld hl,(TFS_PARAM_SECTOR_0)
        ld de,0x0010
        or a
        sbc hl,de
        jr z,tecfsSectorBridgeReadPrefixFixture
        ld hl,(TFS_PARAM_SECTOR_0)
        ld de,0x0030
        or a
        sbc hl,de
        jr z,tecfsSectorBridgeReadCatalogFixture
        ld hl,(TFS_PARAM_SECTOR_0)
        ld de,0x0102
        or a
        sbc hl,de
        jr z,tecfsSectorBridgeReadSourceFixture
tecfsSectorBridgeReadIncludeMissing:
        scf
        ret
tecfsSectorBridgeReadPrefixFixture:
        call tecfsSectorBridgeClearDestination
        ld hl,(TFS_PARAM_BUFFER_LO)
        ld (hl),TFS_ENTRY_STATUS_ACTIVE
        inc hl
        ld (hl),0x01
        inc hl
        ld (hl),0x03
        inc hl
        ld (hl),"s"
        inc hl
        ld (hl),"r"
        inc hl
        ld (hl),"c"
        jp tecfsSectorBridgeOk
tecfsSectorBridgeReadCatalogFixture:
        call tecfsSectorBridgeClearDestination
        ld hl,(TFS_PARAM_BUFFER_LO)
        ld (hl),TFS_ENTRY_STATUS_ACTIVE
        inc hl
        ld (hl),0x02
        inc hl
        ld (hl),0x01
        inc hl
        ld (hl),0x07
        inc hl
        ld de,Tecm8IncludeName
        ex de,hl
        ld bc,0x0007
        ldir
        ld hl,(TFS_PARAM_BUFFER_LO)
        ld de,TFS_CATALOG_OFFSET_FIRST_BLOCK
        add hl,de
        ld (hl),0x20
        inc hl
        ld (hl),0x00
        inc hl
        ld (hl),Tecm8IncludeFixtureEnd-Tecm8IncludeFixture
        inc hl
        ld (hl),0x00
        ld hl,(TFS_PARAM_BUFFER_LO)
        ld de,TFS_CATALOG_OFFSET_FILE_TYPE
        add hl,de
        ld (hl),TFS_FILE_SOURCE_V1
        jp tecfsSectorBridgeOk
tecfsSectorBridgeReadSourceFixture:
        call tecfsSectorBridgeClearDestination
        ld hl,Tecm8IncludeFixture
        ld de,(TFS_PARAM_BUFFER_LO)
        ld bc,Tecm8IncludeFixtureEnd-Tecm8IncludeFixture
        ldir
        jp tecfsSectorBridgeOk

.routine out A,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsSectorBridgeClearDestination:
        ld hl,(TFS_PARAM_BUFFER_LO)
        ld d,h
        ld e,l
        inc de
        ld bc,EDT_PAGE_BYTES-1
        xor a
        ld (hl),a
        ldir
        ret

Tecm8IncludeName:
        .db     "lib.asm"

Tecm8IncludeFixture:
        .db     0x07,"HELPER:"
        .ds     EDT_RECORD_BYTES-8
        .db     0x0A,"LD A,VALUE"
        .ds     EDT_RECORD_BYTES-11
        .db     0x03,"RET"
        .ds     EDT_RECORD_BYTES-4
Tecm8IncludeFixtureEnd:

        .org    0x8400

; Compatibility definitions needed by the relocated MON3 storage package.
; TecMate only exposes openFile/readSector/writeSector from this copy; the
; legacy load/save UI paths remain linked but their display hooks are inert.
MCB_SD_CARD     .equ    0x80
SDIO            .equ    0xFD
loadHEX:
        xor a
        ret
commandToLCD:
HLtoLCD:
setExpand:
charToLCD:
stringToLCD:
        ret

        .include "../monitor/pata_fat32.asm"
