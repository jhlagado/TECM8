; TECM8 expansion ROM physical bank 2: TEC-FS service skeleton.

        .include "bank_ops.asmi"

        .org    0x8000

TECM8_EXPANSION_BANK          .equ    0x02
TECM8_EXPANSION_VERSION       .equ    0x01
TECFS_VOLUME_MIB              .equ    128
TECFS_BLOCK_BYTES             .equ    4096
TECFS_VOLUME_BLOCKS           .equ    32768
TECFS_USER_VOLUMES            .equ    30
TECFS_SPARE_VOLUME            .equ    30
TECFS_TOTAL_VOLUMES           .equ    31

@Tecm8ExpansionBank2Entry:
        cp TECM8_ABI_PROBE_NESTED
        jp z,BankAbiNestedTarget
        cp TECM8_TECFS_SVC_MOUNT
        jp z,tecfsMountImpl
        cp TECM8_TECFS_SVC_SELECT_VOLUME
        jp z,tecfsSelectVolumeImpl
        cp TECM8_TECFS_SVC_READ
        jp z,tecfsReadSectorImpl
        cp TECM8_TECFS_SVC_WRITE
        jp z,tecfsWriteSectorImpl
        cp TECM8_TECFS_SVC_LOAD_RANGE
        jp z,tecfsUnsupported
        cp TECM8_TECFS_SVC_SAVE_RANGE
        jp z,tecfsUnsupported
        cp TECM8_TECFS_SVC_MAP_BLOCK
        jp z,tecfsMapBlockImpl
        cp TECM8_TECFS_SVC_TRANSLATE_SECTOR
        jp z,tecfsTranslateSectorImpl
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

@BankAbiNestedTarget:
        ld c,TECM8_BIOS_SYS_GET
        rst 10H
        ld (TECM8_ABI_TRACE_8),a
        ld a,0xB2
        ret

@tecfsMountImpl:
        xor a
        ld (TECFS_PARAM_STATUS),a
        ld (TECFS_PARAM_LAST_ERROR),a
        ld a,TECFS_VOLUME_MIB
        ld (TECFS_PARAM_VOLUME_MIB),a
        ld hl,TECFS_BLOCK_BYTES
        ld (TECFS_PARAM_BLOCK_BYTES_LO),hl
        ld hl,TECFS_VOLUME_BLOCKS
        ld (TECFS_PARAM_VOLUME_BLOCKS_LO),hl
        ld a,TECFS_USER_VOLUMES
        ld (TECFS_PARAM_USER_VOLUMES),a
        ld a,TECFS_SPARE_VOLUME
        ld (TECFS_PARAM_SPARE_VOLUME),a
        ld a,TECFS_TOTAL_VOLUMES
        ld (TECFS_PARAM_TOTAL_VOLUMES),a
        ld a,TECFS_LOCATOR_LBA_0
        ld (TECFS_PARAM_LOCATOR_SECTOR_0),a
        ld a,TECFS_LOCATOR_LBA_1
        ld (TECFS_PARAM_LOCATOR_SECTOR_1),a
        ld a,TECFS_LOCATOR_LBA_2
        ld (TECFS_PARAM_LOCATOR_SECTOR_2),a
        ld a,TECFS_LOCATOR_LBA_3
        ld (TECFS_PARAM_LOCATOR_SECTOR_3),a
        ld a,TECFS_VOLUME_SECTORS_0
        ld (TECFS_PARAM_VOLUME_SECTORS_0),a
        ld a,TECFS_VOLUME_SECTORS_1
        ld (TECFS_PARAM_VOLUME_SECTORS_1),a
        ld a,TECFS_VOLUME_SECTORS_2
        ld (TECFS_PARAM_VOLUME_SECTORS_2),a
        ld a,TECFS_VOLUME_SECTORS_3
        ld (TECFS_PARAM_VOLUME_SECTORS_3),a
        ld a,0x82
        or a
        ret

@tecfsSelectVolumeImpl:
        ld a,(TECFS_PARAM_REQUEST_VOLUME)
        cp TECFS_TOTAL_VOLUMES
        jr nc,tecfsBadVolume
        ld (TECFS_PARAM_ACTIVE_VOLUME),a
        xor a
        ld (TECFS_PARAM_STATUS),a
        ld (TECFS_PARAM_LAST_ERROR),a
        ld a,0x82
        or a
        ret

@tecfsBadVolume:
        ld a,TECFS_ERR_BAD_VOLUME
        ld (TECFS_PARAM_STATUS),a
        ld (TECFS_PARAM_LAST_ERROR),a
        scf
        ret

@tecfsMapBlockImpl:
        ld a,(TECFS_PARAM_BLOCK_INDEX_HI)
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
        ld a,(TECFS_PARAM_ACTIVE_VOLUME)
        cp TECFS_TOTAL_VOLUMES
        jr nc,tecfsBadVolume
        add a,a
        add a,a
        add a,e
        ld (TECFS_PARAM_SECTOR_2),a
        xor a
        ld (TECFS_PARAM_SECTOR_3),a
        ld hl,(TECFS_PARAM_BLOCK_INDEX_LO)
        add hl,hl
        add hl,hl
        add hl,hl
        ld (TECFS_PARAM_SECTOR_0),hl
        xor a
        ld (TECFS_PARAM_STATUS),a
        ld (TECFS_PARAM_LAST_ERROR),a
        ld a,0x82
        or a
        ret

@tecfsBadBlock:
        ld a,TECFS_ERR_BAD_BLOCK
        ld (TECFS_PARAM_STATUS),a
        ld (TECFS_PARAM_LAST_ERROR),a
        scf
        ret

@tecfsTranslateSectorImpl:
        call tecfsValidateSector
        jr c,tecfsBadSector
        ld hl,(TECFS_PARAM_SECTOR_0)
        ld de,TECFS_IMAGE_BASE_LBA_0 + (TECFS_IMAGE_BASE_LBA_1 * 256)
        add hl,de
        ld (TECFS_PARAM_SECTOR_0),hl
        ld a,(TECFS_PARAM_SECTOR_2)
        adc a,TECFS_IMAGE_BASE_LBA_2
        ld (TECFS_PARAM_SECTOR_2),a
        ld a,(TECFS_PARAM_SECTOR_3)
        adc a,TECFS_IMAGE_BASE_LBA_3
        ld (TECFS_PARAM_SECTOR_3),a
        xor a
        ld (TECFS_PARAM_STATUS),a
        ld (TECFS_PARAM_LAST_ERROR),a
        ld a,0x82
        or a
        ret

@tecfsReadSectorImpl:
        ld a,TECFS_DRIVER_OP_READ
        jr tecfsSectorIoWithDriverOp

@tecfsWriteSectorImpl:
        ld a,TECFS_DRIVER_OP_WRITE
        jr tecfsSectorIoWithDriverOp

@tecfsSectorIoWithDriverOp:
        ld (TECFS_PARAM_DRIVER_OP),a
        call tecfsValidateCardSector
        jr c,tecfsBadSector
        ld hl,(TECFS_PARAM_BUFFER_LO)
        ld a,h
        or l
        jr z,tecfsBadBuffer
        call tecfsSectorDriverHook
        ret

@tecfsSectorDriverHook:
        ld a,TECFS_ERR_NO_DRIVER
        ld (TECFS_PARAM_STATUS),a
        ld (TECFS_PARAM_LAST_ERROR),a
        scf
        ret

@tecfsValidateSector:
        ld a,(TECFS_PARAM_SECTOR_3)
        or a
        scf
        ret nz
        ld a,(TECFS_PARAM_SECTOR_2)
        cp 0x7C
        ccf
        ret

@tecfsValidateCardSector:
        ld a,(TECFS_PARAM_SECTOR_3)
        or a
        scf
        ret nz
        ld a,(TECFS_PARAM_SECTOR_2)
        cp 0x7C
        jr c,tecfsCardSectorValid
        jr nz,tecfsCardSectorInvalid
        ld hl,(TECFS_PARAM_SECTOR_0)
        ld de,TECFS_IMAGE_BASE_LBA_0 + (TECFS_IMAGE_BASE_LBA_1 * 256)
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
        ld a,TECFS_ERR_BAD_SECTOR
        ld (TECFS_PARAM_STATUS),a
        ld (TECFS_PARAM_LAST_ERROR),a
        scf
        ret

@tecfsBadBuffer:
        ld a,TECFS_ERR_BAD_BUFFER
        ld (TECFS_PARAM_STATUS),a
        ld (TECFS_PARAM_LAST_ERROR),a
        scf
        ret

@tecfsUnsupported:
        ld a,TECFS_ERR_UNSUPPORTED
        ld (TECFS_PARAM_STATUS),a
        ld (TECFS_PARAM_LAST_ERROR),a
        scf
        ret

@Tecm8ExpansionBank2Info:
        .db     "T","M","8",TECM8_EXPANSION_BANK,TECM8_EXPANSION_VERSION
