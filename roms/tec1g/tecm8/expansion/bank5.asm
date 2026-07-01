; TECM8 expansion ROM physical bank 5.

        .include "bank_ops.asmi"

        .org    0x8000

EXP_BANK          .equ    0x05
EXP_VERSION       .equ    0x01
TFS_PROOF_READ_MARKER .equ 0xA5

@Tecm8ExpansionBank5Entry:
        cp TFS_DRIVER_OP_READ
        jp z,tecfsProofDriverRead
        cp TFS_DRIVER_OP_WRITE
        jp z,tecfsProofDriverWrite
        ld a,SVC_ERR_UNKNOWN
        scf
        ret

tecfsProofDriverRead:
        ld hl,(TFS_PARAM_BUFFER_LO)
        ld a,TFS_PROOF_READ_MARKER
        ld (hl),a
        jr tecfsProofDriverOk

tecfsProofDriverWrite:
        jr tecfsProofDriverOk

tecfsProofDriverOk:
        xor a
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        ld a,0x85
        or a
        ret

@Tecm8ExpansionBank5Info:
        .db     "T","M","8",EXP_BANK,EXP_VERSION
