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
        ld a,(TFS_PARAM_SOURCE_IO_KIND)
        cp TFS_SOURCE_IO_META
        jr z,tecfsSectorBridgeReadMeta
        cp TFS_ARTIFACT_IO_BINARY_DATA
        jr z,tecfsSectorBridgeReadBinary
        cp TFS_ARTIFACT_IO_BINARY_META
        jr z,tecfsSectorBridgeReadBinaryMeta
        cp TFS_ARTIFACT_IO_MAP_DATA
        jr z,tecfsSectorBridgeReadMap
        cp TFS_ARTIFACT_IO_MAP_META
        jr z,tecfsSectorBridgeReadMapMeta
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
