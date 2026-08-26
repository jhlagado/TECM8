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

Tecm8ExpansionBank5Info:
        .db     "T","M","8",EXP_BANK,EXP_VERSION

; Public MON3/FAT32 driver for the private TEC-FS layer. Sector numbers are
; relative to the contiguous VOLUME.TM8 file. Opening the file on every call
; avoids depending on MON3's previous C_FILENO selection.

        .org    TFS_MON3_FILE_DRIVER

Tecm8Mon3FileDriverEntry:
        cp TFS_DRIVER_OP_READ
        jp z,tecfsMon3FileRead
        cp TFS_DRIVER_OP_WRITE
        jp z,tecfsMon3FileWrite
        ld a,SVC_ERR_UNKNOWN
        scf
        ret

tecfsMon3FileRead:
        call tecfsMon3FilePrepare
        ret c
        ld a,2
        ld (TFS_MON3_ERROR_STAGE),a
        call readSector
        jp c,tecfsMon3FileError
        ld hl,MON_DISK_BUFFER
        ld de,(TFS_MON3_BUFFER_PTR)
        ld bc,0x0200
        ldir
        jp tecfsMon3FileOk

tecfsMon3FileWrite:
        call tecfsMon3FilePrepare
        ret c
        ; MON3 records the physical target during readSector, so prime that
        ; state from the same file offset before replacing the sector.
        ld a,2
        ld (TFS_MON3_ERROR_STAGE),a
        call readSector
        jp c,tecfsMon3FileError
        ld hl,(TFS_MON3_BUFFER_PTR)
        ld de,MON_DISK_BUFFER
        ld bc,0x0200
        ldir
        ld a,3
        ld (TFS_MON3_ERROR_STAGE),a
        call writeSector
        jp c,tecfsMon3FileError
        jp tecfsMon3FileOk

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
tecfsMon3FilePrepare:
        ld hl,(TFS_PARAM_BUFFER_LO)
        ld a,h
        or l
        jr z,tecfsMon3FileBadBuffer
        ld (TFS_MON3_BUFFER_PTR),hl
        ld a,1
        ld (TFS_MON3_ERROR_STAGE),a
        ld hl,Tecm8Mon3VolumeName
        call openFile
        jp c,tecfsMon3FileError
        call tecfsMon3SectorToOffset
        ret

tecfsMon3FileBadBuffer:
        ld a,TFS_ERR_BAD_BUFFER
        jr tecfsMon3FilePublishError

tecfsMon3FileError:
        ld a,TFS_ERR_DRIVER_IO
tecfsMon3FilePublishError:
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        scf
        ret

; Convert a little-endian 32-bit sector number to MON3's HLDE byte offset.
; Reject any value whose shift by nine would overflow 32 bits.
.routine out A,DE,HL,carry,zero clobbers sign,parity,halfCarry
tecfsMon3SectorToOffset:
        ld a,(TFS_PARAM_SECTOR_3)
        or a
        jr nz,tecfsMon3FileBadSector
        ld a,(TFS_PARAM_SECTOR_0)
        add a,a
        ld d,a
        ld e,0
        ld a,(TFS_PARAM_SECTOR_1)
        rla
        ld l,a
        ld a,(TFS_PARAM_SECTOR_2)
        rla
        ld h,a
        jr c,tecfsMon3FileBadSector
        or a
        ret

tecfsMon3FileBadSector:
        ld a,TFS_ERR_BAD_SECTOR
        jr tecfsMon3FilePublishError

tecfsMon3FileOk:
        xor a
        ld (TFS_MON3_ERROR_STAGE),a
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        ld a,0x85
        or a
        ret

Tecm8Mon3VolumeName:
        .db     "VOLUME.TM8",0

; Relocated MON3 storage package. Only openFile, readSector, and writeSector
; are exported by this bank; the legacy display paths are inert here.
MCB_SD_CARD     .equ    0x80
SDIO            .equ    0xFD
loadHEX:
        xor a
        ret
commandToLCD:
HLtoLCD:
setExpand:
charToLCD:
stringToLCD:
        ret

        .include "../monitor/pata_fat32.asm"
