; TecMate TEC-FS bank-service proof.
;
; Runs from RAM with the project monitor and expansion ROM loaded. It proves
; bank-2 TEC-FS services publish the selected filesystem geometry and reject
; invalid volume selections through the fixed-ROM bank-call ABI.

        .org    0x4000

        .include "../../roms/tec1g/tecm8/expansion/bank_ops.asmi"

PROOF_PASS                  .equ    0x42
PROOF_FAIL_MOUNT            .equ    0xE0
PROOF_FAIL_BLOCK_BYTES      .equ    0xE1
PROOF_FAIL_VOLUME_BLOCKS    .equ    0xE2
PROOF_FAIL_SELECT_VALID     .equ    0xE3
PROOF_FAIL_SELECT_INVALID   .equ    0xE4
PROOF_FAIL_UNSUPPORTED      .equ    0xE5
PROOF_FAIL_MAP_BLOCK        .equ    0xE6
PROOF_FAIL_MAP_INVALID      .equ    0xE7
PROOF_FAIL_READ_CONTRACT    .equ    0xE8
PROOF_FAIL_WRITE_CONTRACT   .equ    0xE9
PROOF_FAIL_BAD_BUFFER       .equ    0xEA
PROOF_FAIL_BAD_SECTOR       .equ    0xEB
PROOF_FAIL_DRIVER_HOOK      .equ    0xEC
PROOF_FAIL_LOCATOR          .equ    0xED
PROOF_FAIL_VOLUME_SECTORS   .equ    0xEE
PROOF_FAIL_TRANSLATE        .equ    0xEF
PROOF_FAIL_DRIVER_READ      .equ    0xF0
PROOF_FAIL_DRIVER_WRITE     .equ    0xF1
PROOF_FAIL_FORMAT_LOCATOR   .equ    0xF2
PROOF_FAIL_READ_LOCATOR     .equ    0xF3
PROOF_FAIL_BAD_LOCATOR      .equ    0xF4
TFS_PROOF_READ_MARKER       .equ    0xA5
TFS_PROOF_TRACE_BASE      .equ    0x3B80
TFS_PROOF_RESULT          .equ    0x3BA0

;! out carry,zero
;! clobbers sign,parity,halfCarry,A,B,C,D,E,H,L
@Start:
        ld hl,TFS_PARAM_BASE
        ld b,64
ClearParams:
        ld (hl),0
        inc hl
        djnz ClearParams

        ld a,TFS_SVC_MOUNT
        farCall 0x02,TFS_ENTRY
        jp c,FailMount
        cp 0x82
        jp nz,FailMount

        ld a,(TFS_PARAM_BLOCK_BYTES_LO)
        cp 0x00
        jp nz,FailBlockBytes
        ld a,(TFS_PARAM_BLOCK_BYTES_HI)
        cp 0x10
        jp nz,FailBlockBytes

        ld a,(TFS_PARAM_VOLUME_BLOCKS_LO)
        cp 0x00
        jp nz,FailVolumeBlocks
        ld a,(TFS_PARAM_VOLUME_BLOCKS_HI)
        cp 0x80
        jp nz,FailVolumeBlocks

        ld a,(TFS_PARAM_LOCATOR_SECTOR_0)
        cp TFS_LOC_LBA_0
        jp nz,FailLocator
        ld a,(TFS_PARAM_LOCATOR_SECTOR_1)
        cp TFS_LOC_LBA_1
        jp nz,FailLocator
        ld a,(TFS_PARAM_LOCATOR_SECTOR_2)
        cp TFS_LOC_LBA_2
        jp nz,FailLocator
        ld a,(TFS_PARAM_LOCATOR_SECTOR_3)
        cp TFS_LOC_LBA_3
        jp nz,FailLocator

        ld a,(TFS_PARAM_VOLUME_SECTORS_0)
        cp TFS_VOLUME_SECTORS_0
        jp nz,FailVolumeSectors
        ld a,(TFS_PARAM_VOLUME_SECTORS_1)
        cp TFS_VOLUME_SECTORS_1
        jp nz,FailVolumeSectors
        ld a,(TFS_PARAM_VOLUME_SECTORS_2)
        cp TFS_VOLUME_SECTORS_2
        jp nz,FailVolumeSectors
        ld a,(TFS_PARAM_VOLUME_SECTORS_3)
        cp TFS_VOLUME_SECTORS_3
        jp nz,FailVolumeSectors

        ld hl,0x6200
        ld (TFS_PARAM_BUFFER_LO),hl
        ld a,TFS_SVC_FORMAT_LOCATOR
        farCall 0x02,TFS_ENTRY
        jp c,FailFormatLocator
        cp 0x82
        jp nz,FailFormatLocator
        ld a,(0x6200)
        cp TFS_LOC_MAGIC_0
        jp nz,FailFormatLocator
        ld a,(0x6201)
        cp TFS_LOC_MAGIC_1
        jp nz,FailFormatLocator
        ld a,(0x6202)
        cp TFS_LOC_MAGIC_2
        jp nz,FailFormatLocator
        ld a,(0x6203)
        cp TFS_LOC_MAGIC_3
        jp nz,FailFormatLocator
        ld a,(0x6206)
        cp 31
        jp nz,FailFormatLocator
        ld a,(0x6209)
        cp TFS_VOLUME_SECTORS_0
        jp nz,FailFormatLocator
        ld a,(0x620B)
        cp TFS_VOLUME_SECTORS_2
        jp nz,FailFormatLocator

        xor a
        ld (TFS_PARAM_TOTAL_VOLUMES),a
        ld (TFS_PARAM_USER_VOLUMES),a
        ld (TFS_PARAM_SPARE_VOLUME),a
        ld (TFS_PARAM_VOLUME_SECTORS_2),a
        ld a,TFS_SVC_READ_LOCATOR
        farCall 0x02,TFS_ENTRY
        jp c,FailReadLocator
        cp 0x82
        jp nz,FailReadLocator
        ld a,(TFS_PARAM_TOTAL_VOLUMES)
        cp 31
        jp nz,FailReadLocator
        ld a,(TFS_PARAM_USER_VOLUMES)
        cp 30
        jp nz,FailReadLocator
        ld a,(TFS_PARAM_SPARE_VOLUME)
        cp 30
        jp nz,FailReadLocator
        ld a,(TFS_PARAM_VOLUME_SECTORS_2)
        cp TFS_VOLUME_SECTORS_2
        jp nz,FailReadLocator

        xor a
        ld (0x6200),a
        ld a,TFS_SVC_READ_LOCATOR
        farCall 0x02,TFS_ENTRY
        jp nc,FailBadLocator
        cp TFS_ERR_BAD_LOCATOR
        jp nz,FailBadLocator

        ld a,0x05
        ld (TFS_PARAM_REQUEST_VOLUME),a
        ld a,TFS_SVC_SELECT_VOLUME
        farCall 0x02,TFS_ENTRY
        jp c,FailSelectValid
        ld a,(TFS_PARAM_ACTIVE_VOLUME)
        cp 0x05
        jp nz,FailSelectValid
        ld a,(TFS_PARAM_LAST_ERROR)
        cp TFS_STATUS_OK
        jp nz,FailSelectValid

        ld a,0x1E
        ld (TFS_PARAM_REQUEST_VOLUME),a
        ld a,TFS_SVC_SELECT_VOLUME
        farCall 0x02,TFS_ENTRY
        jp c,FailSelectValid
        ld a,(TFS_PARAM_ACTIVE_VOLUME)
        cp 0x1E
        jp nz,FailSelectValid

        ld a,0x1F
        ld (TFS_PARAM_REQUEST_VOLUME),a
        ld a,TFS_SVC_SELECT_VOLUME
        farCall 0x02,TFS_ENTRY
        jp nc,FailSelectInvalid
        cp TFS_ERR_BAD_VOLUME
        jp nz,FailSelectInvalid
        ld a,(TFS_PARAM_LAST_ERROR)
        cp TFS_ERR_BAD_VOLUME
        jp nz,FailSelectInvalid
        ld a,(TFS_PARAM_ACTIVE_VOLUME)
        cp 0x1E
        jp nz,FailSelectInvalid

        ld a,0x05
        ld (TFS_PARAM_REQUEST_VOLUME),a
        ld a,TFS_SVC_SELECT_VOLUME
        farCall 0x02,TFS_ENTRY
        jp c,FailSelectValid
        ld a,0x34
        ld (TFS_PARAM_BLOCK_INDEX_LO),a
        ld a,0x12
        ld (TFS_PARAM_BLOCK_INDEX_HI),a
        ld a,TFS_SVC_MAP_BLOCK
        farCall 0x02,TFS_ENTRY
        jp c,FailMapBlock
        cp 0x82
        jp nz,FailMapBlock
        ld a,(TFS_PARAM_SECTOR_0)
        cp 0xA0
        jp nz,FailMapBlock
        ld a,(TFS_PARAM_SECTOR_1)
        cp 0x91
        jp nz,FailMapBlock
        ld a,(TFS_PARAM_SECTOR_2)
        cp 0x14
        jp nz,FailMapBlock
        ld a,(TFS_PARAM_SECTOR_3)
        cp 0x00
        jp nz,FailMapBlock

        ld a,TFS_SVC_TRANSLATE_SECTOR
        farCall 0x02,TFS_ENTRY
        jp c,FailTranslate
        cp 0x82
        jp nz,FailTranslate
        ld a,(TFS_PARAM_SECTOR_0)
        cp 0xA2
        jp nz,FailTranslate
        ld a,(TFS_PARAM_SECTOR_1)
        cp 0x91
        jp nz,FailTranslate
        ld a,(TFS_PARAM_SECTOR_2)
        cp 0x14
        jp nz,FailTranslate
        ld a,(TFS_PARAM_SECTOR_3)
        cp 0x00
        jp nz,FailTranslate

        ld a,0x1D
        ld (TFS_PARAM_REQUEST_VOLUME),a
        ld a,TFS_SVC_SELECT_VOLUME
        farCall 0x02,TFS_ENTRY
        jp c,FailSelectValid
        ld a,0x34
        ld (TFS_PARAM_BLOCK_INDEX_LO),a
        ld a,0x12
        ld (TFS_PARAM_BLOCK_INDEX_HI),a
        ld a,TFS_SVC_MAP_BLOCK
        farCall 0x02,TFS_ENTRY
        jp c,FailMapBlock
        ld a,(TFS_PARAM_SECTOR_0)
        cp 0xA0
        jp nz,FailMapBlock
        ld a,(TFS_PARAM_SECTOR_1)
        cp 0x91
        jp nz,FailMapBlock
        ld a,(TFS_PARAM_SECTOR_2)
        cp 0x74
        jp nz,FailMapBlock
        ld a,(TFS_PARAM_SECTOR_3)
        cp 0x00
        jp nz,FailMapBlock

        ld a,TFS_SVC_TRANSLATE_SECTOR
        farCall 0x02,TFS_ENTRY
        jp c,FailTranslate
        cp 0x82
        jp nz,FailTranslate
        ld a,(TFS_PARAM_SECTOR_0)
        cp 0xA2
        jp nz,FailTranslate
        ld a,(TFS_PARAM_SECTOR_1)
        cp 0x91
        jp nz,FailTranslate
        ld a,(TFS_PARAM_SECTOR_2)
        cp 0x74
        jp nz,FailTranslate
        ld a,(TFS_PARAM_SECTOR_3)
        cp 0x00
        jp nz,FailTranslate

        ld a,0xFF
        ld (TFS_PARAM_SECTOR_0),a
        ld (TFS_PARAM_SECTOR_1),a
        xor a
        ld (TFS_PARAM_SECTOR_2),a
        ld (TFS_PARAM_SECTOR_3),a
        ld a,TFS_SVC_TRANSLATE_SECTOR
        farCall 0x02,TFS_ENTRY
        jp c,FailTranslate
        ld a,(TFS_PARAM_SECTOR_0)
        cp 0x01
        jp nz,FailTranslate
        ld a,(TFS_PARAM_SECTOR_1)
        cp 0x00
        jp nz,FailTranslate
        ld a,(TFS_PARAM_SECTOR_2)
        cp 0x01
        jp nz,FailTranslate
        ld a,(TFS_PARAM_SECTOR_3)
        cp 0x00
        jp nz,FailTranslate

        ld a,0x80
        ld (TFS_PARAM_BLOCK_INDEX_HI),a
        ld a,TFS_SVC_MAP_BLOCK
        farCall 0x02,TFS_ENTRY
        jp nc,FailMapInvalid
        cp TFS_ERR_BAD_BLOCK
        jp nz,FailMapInvalid
        ld a,(TFS_PARAM_LAST_ERROR)
        cp TFS_ERR_BAD_BLOCK
        jp nz,FailMapInvalid

        ld a,0x34
        ld (TFS_PARAM_BLOCK_INDEX_LO),a
        ld a,0x12
        ld (TFS_PARAM_BLOCK_INDEX_HI),a
        ld a,TFS_SVC_MAP_BLOCK
        farCall 0x02,TFS_ENTRY
        jp c,FailMapBlock
        ld hl,0x6000
        ld (TFS_PARAM_BUFFER_LO),hl

        ld a,TFS_SVC_TRANSLATE_SECTOR
        farCall 0x02,TFS_ENTRY
        jp c,FailTranslate
        ld a,TFS_SVC_READ
        farCall 0x02,TFS_ENTRY
        jp nc,FailReadContract
        cp TFS_ERR_NO_DRIVER
        jp nz,FailReadContract
        ld a,(TFS_PARAM_LAST_ERROR)
        cp TFS_ERR_NO_DRIVER
        jp nz,FailReadContract
        ld a,(TFS_PARAM_DRIVER_OP)
        cp TFS_DRIVER_OP_READ
        jp nz,FailDriverHook

        ld a,TFS_SVC_WRITE
        farCall 0x02,TFS_ENTRY
        jp nc,FailWriteContract
        cp TFS_ERR_NO_DRIVER
        jp nz,FailWriteContract
        ld a,(TFS_PARAM_LAST_ERROR)
        cp TFS_ERR_NO_DRIVER
        jp nz,FailWriteContract
        ld a,(TFS_PARAM_DRIVER_OP)
        cp TFS_DRIVER_OP_WRITE
        jp nz,FailDriverHook

        ld a,0x05
        ld (TFS_PARAM_DRIVER_BANK),a
        ld hl,0x8000
        ld (TFS_PARAM_DRIVER_ADDR_LO),hl
        xor a
        ld (0x6000),a
        ld a,TFS_SVC_READ
        farCall 0x02,TFS_ENTRY
        jp c,FailDriverRead
        cp 0x85
        jp nz,FailDriverRead
        ld a,(0x6000)
        cp TFS_PROOF_READ_MARKER
        jp nz,FailDriverRead
        ld a,(TFS_PARAM_STATUS)
        cp TFS_STATUS_OK
        jp nz,FailDriverRead

        ld a,0x5A
        ld (0x6000),a
        ld a,TFS_SVC_WRITE
        farCall 0x02,TFS_ENTRY
        jp c,FailDriverWrite
        cp 0x85
        jp nz,FailDriverWrite
        ld a,(TFS_PARAM_STATUS)
        cp TFS_STATUS_OK
        jp nz,FailDriverWrite

        ld hl,0x0000
        ld (TFS_PARAM_BUFFER_LO),hl
        ld a,TFS_SVC_READ
        farCall 0x02,TFS_ENTRY
        jp nc,FailBadBuffer
        cp TFS_ERR_BAD_BUFFER
        jp nz,FailBadBuffer

        ld hl,0x6000
        ld (TFS_PARAM_BUFFER_LO),hl
        ld a,0x7C
        ld (TFS_PARAM_SECTOR_2),a
        ld a,0x02
        ld (TFS_PARAM_SECTOR_0),a
        xor a
        ld (TFS_PARAM_SECTOR_1),a
        ld (TFS_PARAM_SECTOR_3),a
        ld a,TFS_SVC_READ
        farCall 0x02,TFS_ENTRY
        jp nc,FailBadSector
        cp TFS_ERR_BAD_SECTOR
        jp nz,FailBadSector

        ld a,0xA0
        ld (TFS_PARAM_SECTOR_0),a
        ld a,0x91
        ld (TFS_PARAM_SECTOR_1),a
        ld a,0x14
        ld (TFS_PARAM_SECTOR_2),a
        xor a
        ld (TFS_PARAM_SECTOR_3),a
        ld a,TFS_SVC_TRANSLATE_SECTOR
        farCall 0x02,TFS_ENTRY
        jp c,FailTranslate

        ld a,0x34
        ld (TFS_PARAM_BLOCK_INDEX_LO),a
        ld a,0x12
        ld (TFS_PARAM_BLOCK_INDEX_HI),a
        ld a,TFS_SVC_MAP_BLOCK
        farCall 0x02,TFS_ENTRY
        jp c,FailMapBlock
        ld a,TFS_SVC_TRANSLATE_SECTOR
        farCall 0x02,TFS_ENTRY
        jp c,FailTranslate
        ld a,(TFS_PARAM_SECTOR_0)
        cp 0xA2
        jp nz,FailTranslate
        ld a,(TFS_PARAM_SECTOR_1)
        cp 0x91
        jp nz,FailTranslate
        ld a,(TFS_PARAM_SECTOR_2)
        cp 0x74
        jp nz,FailTranslate
        ld a,(TFS_PARAM_SECTOR_3)
        cp 0x00
        jp nz,FailTranslate

        ld a,TFS_SVC_LOAD_RANGE
        farCall 0x02,TFS_ENTRY
        jp nc,FailUnsupported
        cp TFS_ERR_UNSUPPORTED
        jp nz,FailUnsupported

        ld a,PROOF_PASS
        ld (TFS_PROOF_RESULT),a
        halt

FailMount:
        ld a,PROOF_FAIL_MOUNT
        jr Fail
FailBlockBytes:
        ld a,PROOF_FAIL_BLOCK_BYTES
        jr Fail
FailVolumeBlocks:
        ld a,PROOF_FAIL_VOLUME_BLOCKS
        jr Fail
FailSelectValid:
        ld a,PROOF_FAIL_SELECT_VALID
        jr Fail
FailSelectInvalid:
        ld a,PROOF_FAIL_SELECT_INVALID
        jr Fail
FailUnsupported:
        ld a,PROOF_FAIL_UNSUPPORTED
        jr Fail
FailMapBlock:
        ld a,PROOF_FAIL_MAP_BLOCK
        jr Fail
FailMapInvalid:
        ld a,PROOF_FAIL_MAP_INVALID
        jr Fail
FailReadContract:
        ld a,PROOF_FAIL_READ_CONTRACT
        jr Fail
FailWriteContract:
        ld a,PROOF_FAIL_WRITE_CONTRACT
        jr Fail
FailBadBuffer:
        ld a,PROOF_FAIL_BAD_BUFFER
        jr Fail
FailBadSector:
        ld a,PROOF_FAIL_BAD_SECTOR
        jr Fail
FailDriverHook:
        ld a,PROOF_FAIL_DRIVER_HOOK
        jr Fail
FailLocator:
        ld a,PROOF_FAIL_LOCATOR
        jr Fail
FailVolumeSectors:
        ld a,PROOF_FAIL_VOLUME_SECTORS
        jr Fail
FailTranslate:
        ld a,PROOF_FAIL_TRANSLATE
        jr Fail
FailDriverRead:
        ld a,PROOF_FAIL_DRIVER_READ
        jr Fail
FailDriverWrite:
        ld a,PROOF_FAIL_DRIVER_WRITE
        jr Fail
FailFormatLocator:
        ld a,PROOF_FAIL_FORMAT_LOCATOR
        jr Fail
FailReadLocator:
        ld a,PROOF_FAIL_READ_LOCATOR
        jr Fail
FailBadLocator:
        ld a,PROOF_FAIL_BAD_LOCATOR
Fail:
        ld (TFS_PROOF_RESULT),a
        halt
