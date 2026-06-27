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
        jr c,FailSelectValid
        ld a,(TECFS_PARAM_ACTIVE_VOLUME)
        cp 0x05
        jr nz,FailSelectValid
        ld a,(TECFS_PARAM_LAST_ERROR)
        cp TECFS_STATUS_OK
        jr nz,FailSelectValid

        ld a,0x1E
        ld (TECFS_PARAM_REQUEST_VOLUME),a
        farCall 0x02,TECM8_TECFS_SELECT_VOLUME
        jr c,FailSelectValid
        ld a,(TECFS_PARAM_ACTIVE_VOLUME)
        cp 0x1E
        jr nz,FailSelectValid

        ld a,0x1F
        ld (TECFS_PARAM_REQUEST_VOLUME),a
        farCall 0x02,TECM8_TECFS_SELECT_VOLUME
        jr nc,FailSelectInvalid
        cp TECFS_ERR_BAD_VOLUME
        jr nz,FailSelectInvalid
        ld a,(TECFS_PARAM_LAST_ERROR)
        cp TECFS_ERR_BAD_VOLUME
        jr nz,FailSelectInvalid

        farCall 0x02,TECM8_TECFS_READ
        jr nc,FailUnsupported
        cp TECFS_ERR_UNSUPPORTED
        jr nz,FailUnsupported
        ld a,(TECFS_PARAM_LAST_ERROR)
        cp TECFS_ERR_UNSUPPORTED
        jr nz,FailUnsupported

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
Fail:
        ld (TECFS_PROOF_RESULT),a
        halt
