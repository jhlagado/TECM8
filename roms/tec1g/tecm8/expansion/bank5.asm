; TECM8 expansion ROM physical bank 5: TEC-FS monitor-sector bridge.

        .include "bank_ops.asmi"

        .org    0x8000

EXP_BANK          .equ    0x05
EXP_VERSION       .equ    0x01

@Tecm8ExpansionBank5Entry:
        cp TFS_DRIVER_OP_READ
        jp z,tecfsSectorBridgeRead
        cp TFS_DRIVER_OP_WRITE
        jp z,tecfsSectorBridgeWrite
        ld a,SVC_ERR_UNKNOWN
        scf
        ret

tecfsSectorBridgeRead:
        ld hl,(TFS_PARAM_BUFFER_LO)
        ld a,TFS_BRIDGE_READ_MARKER
        ld (hl),a
        jr tecfsSectorBridgeOk

tecfsSectorBridgeWrite:
        jr tecfsSectorBridgeOk

tecfsSectorBridgeOk:
        xor a
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        ld a,0x85
        or a
        ret

@Tecm8ExpansionBank5Info:
        .db     "T","M","8",EXP_BANK,EXP_VERSION
