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

@Tecm8ExpansionBank2Entry:
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
        ld a,SVC_ERR_UNKNOWN
        scf
        ret

@tecfsMount:
        jp tecfsMountImpl

@tecfsSelectVolume:
        jp tecfsSelectVolumeImpl

@tecfsRead:
        jp tecfsReadSectorImpl

@tecfsWrite:
        jp tecfsWriteSectorImpl

@tecfsLoadRange:
        jp tecfsUnsupported

@tecfsSaveRange:
        jp tecfsUnsupported

@tecfsMapBlock:
        jp tecfsMapBlockImpl

@tecfsTranslateSector:
        jp tecfsTranslateSectorImpl

@tecfsFormatLocator:
        jp tecfsFormatLocatorImpl

@tecfsReadLocator:
        jp tecfsReadLocatorImpl

@BankAbiNestedTarget:
        ld c,MON_SYS_GET
        ; expects out A
        rst 10H
        ld (ABI_TRACE_8),a
        ld a,0xB2
        ret

@tecfsMountImpl:
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

@tecfsSelectVolumeImpl:
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

@tecfsBadVolume:
        ld a,TFS_ERR_BAD_VOLUME
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        scf
        ret

@tecfsMapBlockImpl:
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

@tecfsBadBlock:
        ld a,TFS_ERR_BAD_BLOCK
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        scf
        ret

@tecfsTranslateSectorImpl:
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

@tecfsReadSectorImpl:
        ld a,TFS_DRIVER_OP_READ
        jr tecfsSectorIoWithDriverOp

@tecfsWriteSectorImpl:
        ld a,TFS_DRIVER_OP_WRITE
        jr tecfsSectorIoWithDriverOp

@tecfsSectorIoWithDriverOp:
        ld (TFS_PARAM_DRIVER_OP),a
        call tecfsValidateCardSector
        jp c,tecfsBadSector
        ld hl,(TFS_PARAM_BUFFER_LO)
        ld a,h
        or l
        jp z,tecfsBadBuffer
        call tecfsSectorDriverHook
        ret

@tecfsSectorDriverHook:
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

@tecfsNoSectorDriver:
        ld a,TFS_ERR_NO_DRIVER
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        scf
        ret

@tecfsFormatLocatorImpl:
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

@tecfsReadLocatorImpl:
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

@tecfsBadLocator:
        ld a,TFS_ERR_BAD_LOCATOR
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        scf
        ret

@tecfsValidateSector:
        ld a,(TFS_PARAM_SECTOR_3)
        or a
        scf
        ret nz
        ld a,(TFS_PARAM_SECTOR_2)
        cp 0x7C
        ccf
        ret

@tecfsValidateCardSector:
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

@tecfsCardSectorValid:
        or a
        ret

@tecfsCardSectorInvalid:
        scf
        ret

@tecfsBadSector:
        ld a,TFS_ERR_BAD_SECTOR
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        scf
        ret

@tecfsBadBuffer:
        ld a,TFS_ERR_BAD_BUFFER
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        scf
        ret

@tecfsUnsupported:
        ld a,TFS_ERR_UNSUPPORTED
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        scf
        ret

@Tecm8ExpansionBank2Info:
        .db     "T","M","8",EXP_BANK,EXP_VERSION
