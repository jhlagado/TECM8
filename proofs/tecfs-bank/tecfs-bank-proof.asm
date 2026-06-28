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
TECFS_PROOF_TRACE_BASE      .equ    0x3B80
TECFS_PROOF_RESULT          .equ    0x3BA0

;! out carry,zero
;! clobbers sign,parity,halfCarry,A,B,C,D,E,H,L
@Start:
        ld hl,TECFS_PARAM_BASE
        ld b,64
ClearParams:
        ld (hl),0
        inc hl
        djnz ClearParams

        ld a,TECM8_TECFS_SVC_MOUNT
        farCall 0x02,TECM8_TECFS_ENTRY
        jp c,FailMount
        cp 0x82
        jp nz,FailMount

        ld a,(TECFS_PARAM_BLOCK_BYTES_LO)
        cp 0x00
        jp nz,FailBlockBytes
        ld a,(TECFS_PARAM_BLOCK_BYTES_HI)
        cp 0x10
        jp nz,FailBlockBytes

        ld a,(TECFS_PARAM_VOLUME_BLOCKS_LO)
        cp 0x00
        jp nz,FailVolumeBlocks
        ld a,(TECFS_PARAM_VOLUME_BLOCKS_HI)
        cp 0x80
        jp nz,FailVolumeBlocks

        ld a,(TECFS_PARAM_LOCATOR_SECTOR_0)
        cp TECFS_LOCATOR_LBA_0
        jp nz,FailLocator
        ld a,(TECFS_PARAM_LOCATOR_SECTOR_1)
        cp TECFS_LOCATOR_LBA_1
        jp nz,FailLocator
        ld a,(TECFS_PARAM_LOCATOR_SECTOR_2)
        cp TECFS_LOCATOR_LBA_2
        jp nz,FailLocator
        ld a,(TECFS_PARAM_LOCATOR_SECTOR_3)
        cp TECFS_LOCATOR_LBA_3
        jp nz,FailLocator

        ld a,(TECFS_PARAM_VOLUME_SECTORS_0)
        cp TECFS_VOLUME_SECTORS_0
        jp nz,FailVolumeSectors
        ld a,(TECFS_PARAM_VOLUME_SECTORS_1)
        cp TECFS_VOLUME_SECTORS_1
        jp nz,FailVolumeSectors
        ld a,(TECFS_PARAM_VOLUME_SECTORS_2)
        cp TECFS_VOLUME_SECTORS_2
        jp nz,FailVolumeSectors
        ld a,(TECFS_PARAM_VOLUME_SECTORS_3)
        cp TECFS_VOLUME_SECTORS_3
        jp nz,FailVolumeSectors

        ld a,0x05
        ld (TECFS_PARAM_REQUEST_VOLUME),a
        ld a,TECM8_TECFS_SVC_SELECT_VOLUME
        farCall 0x02,TECM8_TECFS_ENTRY
        jp c,FailSelectValid
        ld a,(TECFS_PARAM_ACTIVE_VOLUME)
        cp 0x05
        jp nz,FailSelectValid
        ld a,(TECFS_PARAM_LAST_ERROR)
        cp TECFS_STATUS_OK
        jp nz,FailSelectValid

        ld a,0x1E
        ld (TECFS_PARAM_REQUEST_VOLUME),a
        ld a,TECM8_TECFS_SVC_SELECT_VOLUME
        farCall 0x02,TECM8_TECFS_ENTRY
        jp c,FailSelectValid
        ld a,(TECFS_PARAM_ACTIVE_VOLUME)
        cp 0x1E
        jp nz,FailSelectValid

        ld a,0x1F
        ld (TECFS_PARAM_REQUEST_VOLUME),a
        ld a,TECM8_TECFS_SVC_SELECT_VOLUME
        farCall 0x02,TECM8_TECFS_ENTRY
        jp nc,FailSelectInvalid
        cp TECFS_ERR_BAD_VOLUME
        jp nz,FailSelectInvalid
        ld a,(TECFS_PARAM_LAST_ERROR)
        cp TECFS_ERR_BAD_VOLUME
        jp nz,FailSelectInvalid
        ld a,(TECFS_PARAM_ACTIVE_VOLUME)
        cp 0x1E
        jp nz,FailSelectInvalid

        ld a,0x05
        ld (TECFS_PARAM_REQUEST_VOLUME),a
        ld a,TECM8_TECFS_SVC_SELECT_VOLUME
        farCall 0x02,TECM8_TECFS_ENTRY
        jp c,FailSelectValid
        ld a,0x34
        ld (TECFS_PARAM_BLOCK_INDEX_LO),a
        ld a,0x12
        ld (TECFS_PARAM_BLOCK_INDEX_HI),a
        ld a,TECM8_TECFS_SVC_MAP_BLOCK
        farCall 0x02,TECM8_TECFS_ENTRY
        jp c,FailMapBlock
        cp 0x82
        jp nz,FailMapBlock
        ld a,(TECFS_PARAM_SECTOR_0)
        cp 0xA0
        jp nz,FailMapBlock
        ld a,(TECFS_PARAM_SECTOR_1)
        cp 0x91
        jp nz,FailMapBlock
        ld a,(TECFS_PARAM_SECTOR_2)
        cp 0x14
        jp nz,FailMapBlock
        ld a,(TECFS_PARAM_SECTOR_3)
        cp 0x00
        jp nz,FailMapBlock

        ld a,TECM8_TECFS_SVC_TRANSLATE_SECTOR
        farCall 0x02,TECM8_TECFS_ENTRY
        jp c,FailTranslate
        cp 0x82
        jp nz,FailTranslate
        ld a,(TECFS_PARAM_SECTOR_0)
        cp 0xA2
        jp nz,FailTranslate
        ld a,(TECFS_PARAM_SECTOR_1)
        cp 0x91
        jp nz,FailTranslate
        ld a,(TECFS_PARAM_SECTOR_2)
        cp 0x14
        jp nz,FailTranslate
        ld a,(TECFS_PARAM_SECTOR_3)
        cp 0x00
        jp nz,FailTranslate

        ld a,0x1D
        ld (TECFS_PARAM_REQUEST_VOLUME),a
        ld a,TECM8_TECFS_SVC_SELECT_VOLUME
        farCall 0x02,TECM8_TECFS_ENTRY
        jp c,FailSelectValid
        ld a,0x34
        ld (TECFS_PARAM_BLOCK_INDEX_LO),a
        ld a,0x12
        ld (TECFS_PARAM_BLOCK_INDEX_HI),a
        ld a,TECM8_TECFS_SVC_MAP_BLOCK
        farCall 0x02,TECM8_TECFS_ENTRY
        jp c,FailMapBlock
        ld a,(TECFS_PARAM_SECTOR_0)
        cp 0xA0
        jp nz,FailMapBlock
        ld a,(TECFS_PARAM_SECTOR_1)
        cp 0x91
        jp nz,FailMapBlock
        ld a,(TECFS_PARAM_SECTOR_2)
        cp 0x74
        jp nz,FailMapBlock
        ld a,(TECFS_PARAM_SECTOR_3)
        cp 0x00
        jp nz,FailMapBlock

        ld a,TECM8_TECFS_SVC_TRANSLATE_SECTOR
        farCall 0x02,TECM8_TECFS_ENTRY
        jp c,FailTranslate
        cp 0x82
        jp nz,FailTranslate
        ld a,(TECFS_PARAM_SECTOR_0)
        cp 0xA2
        jp nz,FailTranslate
        ld a,(TECFS_PARAM_SECTOR_1)
        cp 0x91
        jp nz,FailTranslate
        ld a,(TECFS_PARAM_SECTOR_2)
        cp 0x74
        jp nz,FailTranslate
        ld a,(TECFS_PARAM_SECTOR_3)
        cp 0x00
        jp nz,FailTranslate

        ld a,0xFF
        ld (TECFS_PARAM_SECTOR_0),a
        ld (TECFS_PARAM_SECTOR_1),a
        xor a
        ld (TECFS_PARAM_SECTOR_2),a
        ld (TECFS_PARAM_SECTOR_3),a
        ld a,TECM8_TECFS_SVC_TRANSLATE_SECTOR
        farCall 0x02,TECM8_TECFS_ENTRY
        jp c,FailTranslate
        ld a,(TECFS_PARAM_SECTOR_0)
        cp 0x01
        jp nz,FailTranslate
        ld a,(TECFS_PARAM_SECTOR_1)
        cp 0x00
        jp nz,FailTranslate
        ld a,(TECFS_PARAM_SECTOR_2)
        cp 0x01
        jp nz,FailTranslate
        ld a,(TECFS_PARAM_SECTOR_3)
        cp 0x00
        jp nz,FailTranslate

        ld a,0x80
        ld (TECFS_PARAM_BLOCK_INDEX_HI),a
        ld a,TECM8_TECFS_SVC_MAP_BLOCK
        farCall 0x02,TECM8_TECFS_ENTRY
        jp nc,FailMapInvalid
        cp TECFS_ERR_BAD_BLOCK
        jp nz,FailMapInvalid
        ld a,(TECFS_PARAM_LAST_ERROR)
        cp TECFS_ERR_BAD_BLOCK
        jp nz,FailMapInvalid

        ld a,0x34
        ld (TECFS_PARAM_BLOCK_INDEX_LO),a
        ld a,0x12
        ld (TECFS_PARAM_BLOCK_INDEX_HI),a
        ld a,TECM8_TECFS_SVC_MAP_BLOCK
        farCall 0x02,TECM8_TECFS_ENTRY
        jp c,FailMapBlock
        ld hl,0x6000
        ld (TECFS_PARAM_BUFFER_LO),hl

        ld a,TECM8_TECFS_SVC_TRANSLATE_SECTOR
        farCall 0x02,TECM8_TECFS_ENTRY
        jp c,FailTranslate
        ld a,TECM8_TECFS_SVC_READ
        farCall 0x02,TECM8_TECFS_ENTRY
        jp nc,FailReadContract
        cp TECFS_ERR_NO_DRIVER
        jp nz,FailReadContract
        ld a,(TECFS_PARAM_LAST_ERROR)
        cp TECFS_ERR_NO_DRIVER
        jp nz,FailReadContract
        ld a,(TECFS_PARAM_DRIVER_OP)
        cp TECFS_DRIVER_OP_READ
        jp nz,FailDriverHook

        ld a,TECM8_TECFS_SVC_WRITE
        farCall 0x02,TECM8_TECFS_ENTRY
        jp nc,FailWriteContract
        cp TECFS_ERR_NO_DRIVER
        jp nz,FailWriteContract
        ld a,(TECFS_PARAM_LAST_ERROR)
        cp TECFS_ERR_NO_DRIVER
        jp nz,FailWriteContract
        ld a,(TECFS_PARAM_DRIVER_OP)
        cp TECFS_DRIVER_OP_WRITE
        jp nz,FailDriverHook

        ld hl,0x0000
        ld (TECFS_PARAM_BUFFER_LO),hl
        ld a,TECM8_TECFS_SVC_READ
        farCall 0x02,TECM8_TECFS_ENTRY
        jp nc,FailBadBuffer
        cp TECFS_ERR_BAD_BUFFER
        jp nz,FailBadBuffer

        ld hl,0x6000
        ld (TECFS_PARAM_BUFFER_LO),hl
        ld a,0x7C
        ld (TECFS_PARAM_SECTOR_2),a
        ld a,0x02
        ld (TECFS_PARAM_SECTOR_0),a
        xor a
        ld (TECFS_PARAM_SECTOR_1),a
        ld (TECFS_PARAM_SECTOR_3),a
        ld a,TECM8_TECFS_SVC_READ
        farCall 0x02,TECM8_TECFS_ENTRY
        jp nc,FailBadSector
        cp TECFS_ERR_BAD_SECTOR
        jp nz,FailBadSector

        ld a,0xA0
        ld (TECFS_PARAM_SECTOR_0),a
        ld a,0x91
        ld (TECFS_PARAM_SECTOR_1),a
        ld a,0x14
        ld (TECFS_PARAM_SECTOR_2),a
        xor a
        ld (TECFS_PARAM_SECTOR_3),a
        ld a,TECM8_TECFS_SVC_TRANSLATE_SECTOR
        farCall 0x02,TECM8_TECFS_ENTRY
        jp c,FailTranslate

        ld a,0x34
        ld (TECFS_PARAM_BLOCK_INDEX_LO),a
        ld a,0x12
        ld (TECFS_PARAM_BLOCK_INDEX_HI),a
        ld a,TECM8_TECFS_SVC_MAP_BLOCK
        farCall 0x02,TECM8_TECFS_ENTRY
        jp c,FailMapBlock
        ld a,TECM8_TECFS_SVC_TRANSLATE_SECTOR
        farCall 0x02,TECM8_TECFS_ENTRY
        jp c,FailTranslate
        ld a,(TECFS_PARAM_SECTOR_0)
        cp 0xA2
        jp nz,FailTranslate
        ld a,(TECFS_PARAM_SECTOR_1)
        cp 0x91
        jp nz,FailTranslate
        ld a,(TECFS_PARAM_SECTOR_2)
        cp 0x74
        jp nz,FailTranslate
        ld a,(TECFS_PARAM_SECTOR_3)
        cp 0x00
        jp nz,FailTranslate

        ld a,TECM8_TECFS_SVC_LOAD_RANGE
        farCall 0x02,TECM8_TECFS_ENTRY
        jp nc,FailUnsupported
        cp TECFS_ERR_UNSUPPORTED
        jp nz,FailUnsupported

        ld a,PROOF_PASS
        ld (TECFS_PROOF_RESULT),a
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
Fail:
        ld (TECFS_PROOF_RESULT),a
        halt
