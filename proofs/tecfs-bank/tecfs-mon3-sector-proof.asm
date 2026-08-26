; Real MON3/FAT32 VOLUME.TM8 sector-driver proof.

        .org    0x4000

        .include "../../roms/tec1g/tecm8/expansion/bank_ops.asmi"

PROOF_PASS        .equ    0x42
PROOF_RESULT      .equ    0x3A10
PROOF_PHASE       .equ    0x3A11
PROOF_BUFFER      .equ    0x6000

.routine out carry,zero clobbers sign,parity,halfCarry,A,B,C,D,E,H,L
Start:
        xor a
        ld (PROOF_RESULT),a
        ld a,TFS_SVC_MOUNT
        callService TFS_MOUNT
        jp c,Fail
        ld hl,PROOF_BUFFER
        ld (TFS_PARAM_BUFFER_LO),hl
        ld hl,7
        ld (TFS_PARAM_SECTOR_0),hl
        xor a
        ld (TFS_PARAM_SECTOR_2),a
        ld (TFS_PARAM_SECTOR_3),a

        ld a,1
        ld (PROOF_PHASE),a
        ld a,TFS_SVC_READ
        farCall TFS_BANK,TFS_ENTRY
        jp c,Fail
        ld hl,PROOF_BUFFER
        ld de,ProofMarker
        ld b,8
CheckMarker:
        ld a,(de)
        cp (hl)
        jp nz,Fail
        inc de
        inc hl
        djnz CheckMarker

        ld hl,ProofBinary
        ld de,PROOF_BUFFER
        ld bc,5
        ldir
        ld a,2
        ld (PROOF_PHASE),a
        ld a,TFS_SVC_WRITE
        farCall TFS_BANK,TFS_ENTRY
        jp c,Fail

        ld hl,PROOF_BUFFER
        ld b,5
ClearWritten:
        ld (hl),0
        inc hl
        djnz ClearWritten
        ld a,3
        ld (PROOF_PHASE),a
        ld a,TFS_SVC_READ
        farCall TFS_BANK,TFS_ENTRY
        jp c,Fail
        ld hl,PROOF_BUFFER
        ld de,ProofBinary
        ld b,5
CheckBinary:
        ld a,(de)
        cp (hl)
        jp nz,Fail
        inc de
        inc hl
        djnz CheckBinary

        xor a
        ld (TFS_PARAM_BUFFER_LO),a
        ld (TFS_PARAM_BUFFER_HI),a
        ld a,4
        ld (PROOF_PHASE),a
        ld a,TFS_SVC_READ
        farCall TFS_BANK,TFS_ENTRY
        jp nc,Fail
        cp TFS_ERR_BAD_BUFFER
        jp nz,Fail

        ld hl,PROOF_BUFFER
        ld (TFS_PARAM_BUFFER_LO),hl
        xor a
        ld (TFS_PARAM_SECTOR_0),a
        ld (TFS_PARAM_SECTOR_1),a
        ld (TFS_PARAM_SECTOR_3),a
        ld a,0x80
        ld (TFS_PARAM_SECTOR_2),a
        ld a,5
        ld (PROOF_PHASE),a
        ld a,TFS_SVC_READ
        farCall TFS_BANK,TFS_ENTRY
        jp nc,Fail
        cp TFS_ERR_BAD_SECTOR
        jp nz,Fail

        ld a,PROOF_PASS
        ld (PROOF_RESULT),a
        ld a,6
        ld (PROOF_PHASE),a
        halt

Fail:
        ld a,0xE0
        ld (PROOF_RESULT),a
        halt

ProofMarker:
        .db     "TM8PROOF"
ProofBinary:
        .db     0x00,0x1A,0x7F,0x80,0xFF
