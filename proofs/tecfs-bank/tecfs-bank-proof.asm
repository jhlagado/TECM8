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

        farCall 0x02,TECM8_TECFS_MOUNT
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

        ld a,0x05
        ld (TECFS_PARAM_REQUEST_VOLUME),a
        farCall 0x02,TECM8_TECFS_SELECT_VOLUME
        jp c,FailSelectValid
        ld a,(TECFS_PARAM_ACTIVE_VOLUME)
        cp 0x05
        jp nz,FailSelectValid
        ld a,(TECFS_PARAM_LAST_ERROR)
        cp TECFS_STATUS_OK
        jp nz,FailSelectValid

        ld a,0x1E
        ld (TECFS_PARAM_REQUEST_VOLUME),a
        farCall 0x02,TECM8_TECFS_SELECT_VOLUME
        jp c,FailSelectValid
        ld a,(TECFS_PARAM_ACTIVE_VOLUME)
        cp 0x1E
        jp nz,FailSelectValid

        ld a,0x1F
        ld (TECFS_PARAM_REQUEST_VOLUME),a
        farCall 0x02,TECM8_TECFS_SELECT_VOLUME
        jp nc,FailSelectInvalid
        cp TECFS_ERR_BAD_VOLUME
        jp nz,FailSelectInvalid
        ld a,(TECFS_PARAM_LAST_ERROR)
        cp TECFS_ERR_BAD_VOLUME
        jp nz,FailSelectInvalid

        ld a,0x05
        ld (TECFS_PARAM_REQUEST_VOLUME),a
        farCall 0x02,TECM8_TECFS_SELECT_VOLUME
        jp c,FailSelectValid
        ld a,0x34
        ld (TECFS_PARAM_BLOCK_INDEX_LO),a
        ld a,0x12
        ld (TECFS_PARAM_BLOCK_INDEX_HI),a
        farCall 0x02,TECM8_TECFS_MAP_BLOCK
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

        ld a,0x80
        ld (TECFS_PARAM_BLOCK_INDEX_HI),a
        farCall 0x02,TECM8_TECFS_MAP_BLOCK
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
        farCall 0x02,TECM8_TECFS_MAP_BLOCK
        jp c,FailMapBlock
        ld hl,0x6000
        ld (TECFS_PARAM_BUFFER_LO),hl

        farCall 0x02,TECM8_TECFS_READ
        jp nc,FailReadContract
        cp TECFS_ERR_NO_DRIVER
        jp nz,FailReadContract
        ld a,(TECFS_PARAM_LAST_ERROR)
        cp TECFS_ERR_NO_DRIVER
        jp nz,FailReadContract
        ld a,(TECFS_PARAM_DRIVER_OP)
        cp TECFS_DRIVER_OP_READ
        jp nz,FailDriverHook

        farCall 0x02,TECM8_TECFS_WRITE
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
        farCall 0x02,TECM8_TECFS_READ
        jp nc,FailBadBuffer
        cp TECFS_ERR_BAD_BUFFER
        jp nz,FailBadBuffer

        ld hl,0x6000
        ld (TECFS_PARAM_BUFFER_LO),hl
        ld a,0x7C
        ld (TECFS_PARAM_SECTOR_2),a
        xor a
        ld (TECFS_PARAM_SECTOR_0),a
        ld (TECFS_PARAM_SECTOR_1),a
        ld (TECFS_PARAM_SECTOR_3),a
        farCall 0x02,TECM8_TECFS_READ
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

        farCall 0x02,TECM8_TECFS_LOAD_RANGE
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
Fail:
        ld (TECFS_PROOF_RESULT),a
        halt
