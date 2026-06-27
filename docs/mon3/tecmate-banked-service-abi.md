# TecMate Banked Service ABI

This document records the current expansion-bank service slots used by the
TecMate ROM work. It is the concrete companion to the higher-level banked
service architecture note.

The fixed monitor remains the stable doorway. Callers enter banked services
through the fixed-ROM RST 10h bank services and the AZM helpers:

```asm
        farCall bank,target
        farJump bank,target
```

`farCall` and `farJump` use `B` for the physical bank, `C` for the RST 10h
service selector, and `HL` for the target address while entering the monitor
trampoline. The helper saves caller `AF`, `DE`, and `HL` before loading those
control values, and the fixed-ROM service restores them before entering the
banked target. `B`, `C`, `IX`, and `IY` are gateway scratch. Larger service
arguments still use small RAM parameter blocks.

## Fixed Bank Calls

| Constant | Value | Meaning |
| --- | ---: | --- |
| `TECM8_BIOS_SYS_GET` | `50h` | Return current `SYS_CTRL` shadow. |
| `TECM8_BIOS_SYS_SET` | `51h` | Update masked `SYS_CTRL` bits. |
| `TECM8_BIOS_BANK_SELECT` | `52h` | Select a physical expansion bank. |
| `TECM8_BIOS_BANK_CALL` | `53h` | Call into a bank and restore previous bank on `ret`. |
| `TECM8_BIOS_FAR_JUMP` | `54h` | Tail-jump into a bank without resuming after the helper. |

The bank-call return path preserves the callee's `AF`, so carry and `A` status
values survive the fixed-ROM bank restore. The previous `SYS_CTRL` value is
stored in the stack frame, so nested far calls restore the correct bank state.

## Bank 0: Service Registry

Bank 0 owns the first assembly-time service registry. Callers can use:

```asm
        callService TECM8_SERVICE_VDU_INIT
```

`callService` stores the requested service ID, enters bank 0 through the fixed
bank-call gateway, and bank 0 dispatches to the service's registered bank and
address. The service ID is carried in a per-call stack word, not a shared RAM
byte, so nested or interrupted calls do not overwrite each other's request. The
final banked service still receives the caller's original `AF`, `DE`, and `HL`.

| Constant | Value | Meaning |
| --- | ---: | --- |
| `TECM8_SERVICE_CALL` | `80A0h` | Bank 0 registry dispatcher. |
| `TECM8_SERVICE_VDU_INIT` | `01h` | VDU init service ID. |
| `TECM8_SERVICE_VDU_INIT_BANK` | `01h` | VDU init physical bank. |
| `TECM8_SERVICE_VDU_INIT_ADDR` | `8010h` | VDU init address. |
| `TECM8_SERVICE_TECFS_MOUNT` | `02h` | TEC-FS mount service ID. |
| `TECM8_SERVICE_TECFS_MOUNT_BANK` | `02h` | TEC-FS mount physical bank. |
| `TECM8_SERVICE_TECFS_MOUNT_ADDR` | `8010h` | TEC-FS mount address. |
| `TECM8_SERVICE_RTC_TOOL` | `03h` | RTC tool service ID. |
| `TECM8_SERVICE_RTC_TOOL_BANK` | `03h` | RTC tool physical bank. |
| `TECM8_SERVICE_RTC_TOOL_ADDR` | `8010h` | RTC tool address. |
| `TECM8_SERVICE_GLCD_ENTRY` | `04h` | GLCD boundary service ID. |
| `TECM8_SERVICE_GLCD_ENTRY_BANK` | `04h` | GLCD boundary physical bank. |
| `TECM8_SERVICE_GLCD_ENTRY_ADDR` | `8000h` | GLCD boundary address. |
| `TECM8_SERVICE_ERR_UNKNOWN` | `EEh` | Unknown service ID error. |

## Bank 1: VDU/TMS9918

Physical bank 1 currently owns the first TMS9918-facing services.

| Constant | Address | Status |
| --- | ---: | --- |
| `TECM8_VDU_ENTRY` | `8000h` | Bank entry marker. |
| `TECM8_VDU_INIT` | `8010h` | Calls TMS init and returns `A=81h`, carry clear. |
| `TECM8_VDU_CLEAR` | `8020h` | Writes zero to VRAM address `0000h`. |
| `TECM8_VDU_SET_CURSOR` | `8030h` | Reserved stub. |
| `TECM8_VDU_PUT_CHAR` | `8040h` | Writes parameter byte to VRAM address `0000h`. |
| `TECM8_TMS_INIT` | `8080h` | Sets TMS register 7 to `F1h`, returns `A=81h`. |
| `TECM8_TMS_SET_REGISTER` | `8090h` | Writes TMS register from the parameter block. |
| `TECM8_TMS_WRITE_VRAM` | `80A0h` | Writes one byte to TMS VRAM from the parameter block. |

TMS ports:

| Constant | Value |
| --- | ---: |
| `TECM8_TMS_DATA_PORT` | `BEh` |
| `TECM8_TMS_CONTROL_PORT` | `BFh` |

TMS parameter block:

| Constant | Address | Meaning |
| --- | ---: | --- |
| `TECM8_TMS_PARAM_BASE` | `3B00h` | Base of TMS parameter block. |
| `TECM8_TMS_PARAM_VALUE` | `3B00h` | Byte value for register or VRAM write. |
| `TECM8_TMS_PARAM_REGISTER` | `3B01h` | TMS register number. |
| `TECM8_TMS_PARAM_ADDR_LO` | `3B02h` | VRAM address low byte. |
| `TECM8_TMS_PARAM_ADDR_HI` | `3B03h` | VRAM address high byte. |

## Bank 2: TEC-FS

Physical bank 2 currently exposes TEC-FS geometry and volume selection.

| Constant | Address | Status |
| --- | ---: | --- |
| `TECM8_TECFS_ENTRY` | `8000h` | Bank entry marker. |
| `TECM8_TECFS_MOUNT` | `8010h` | Publishes geometry, returns `A=82h`, carry clear. |
| `TECM8_TECFS_SELECT_VOLUME` | `8020h` | Selects volume `0..30`, returns `A=82h`, carry clear. |
| `TECM8_TECFS_READ` | `8030h` | Explicit unsupported error. |
| `TECM8_TECFS_WRITE` | `8040h` | Explicit unsupported error. |
| `TECM8_TECFS_LOAD_RANGE` | `8050h` | Explicit unsupported error. |
| `TECM8_TECFS_SAVE_RANGE` | `8060h` | Explicit unsupported error. |
| `TECM8_TECFS_MAP_BLOCK` | `8070h` | Maps active volume/block index to a 32-bit sector number. |

Current TEC-FS geometry:

```text
volume size:      128 MiB
block size:       4 KiB
volume blocks:    32768
user volumes:     30
spare volume:     30
total selectable: 31
```

In prose: the current layout exposes 30 user volumes plus one spare/work
volume, for 31 selectable volumes total.

Because a 4K block is eight 512-byte sectors, `TECM8_TECFS_MAP_BLOCK` computes:

```text
sector = activeVolume * 40000h + blockIndex * 8
```

TEC-FS parameter block:

| Constant | Address | Meaning |
| --- | ---: | --- |
| `TECFS_PARAM_BASE` | `3B40h` | Base of TEC-FS parameter block. |
| `TECFS_PARAM_ACTIVE_VOLUME` | `3B40h` | Last valid selected volume. |
| `TECFS_PARAM_REQUEST_VOLUME` | `3B41h` | Requested volume for select. |
| `TECFS_PARAM_STATUS` | `3B42h` | Last status code. |
| `TECFS_PARAM_LAST_ERROR` | `3B43h` | Last error code. |
| `TECFS_PARAM_VOLUME_MIB` | `3B44h` | Volume size in MiB. |
| `TECFS_PARAM_BLOCK_BYTES_LO` | `3B45h` | Block byte count low byte. |
| `TECFS_PARAM_BLOCK_BYTES_HI` | `3B46h` | Block byte count high byte. |
| `TECFS_PARAM_VOLUME_BLOCKS_LO` | `3B47h` | Volume block count low byte. |
| `TECFS_PARAM_VOLUME_BLOCKS_HI` | `3B48h` | Volume block count high byte. |
| `TECFS_PARAM_USER_VOLUMES` | `3B49h` | User volume count. |
| `TECFS_PARAM_SPARE_VOLUME` | `3B4Ah` | Spare/work volume index. |
| `TECFS_PARAM_TOTAL_VOLUMES` | `3B4Bh` | Total selectable volumes. |
| `TECFS_PARAM_BLOCK_INDEX_LO` | `3B4Ch` | Requested 4K block index low byte. |
| `TECFS_PARAM_BLOCK_INDEX_HI` | `3B4Dh` | Requested 4K block index high byte. |
| `TECFS_PARAM_SECTOR_0` | `3B4Eh` | Mapped 512-byte sector number byte 0. |
| `TECFS_PARAM_SECTOR_1` | `3B4Fh` | Mapped 512-byte sector number byte 1. |
| `TECFS_PARAM_SECTOR_2` | `3B50h` | Mapped 512-byte sector number byte 2. |
| `TECFS_PARAM_SECTOR_3` | `3B51h` | Mapped 512-byte sector number byte 3. |

TEC-FS status codes:

| Constant | Value | Meaning |
| --- | ---: | --- |
| `TECFS_STATUS_OK` | `00h` | Success. |
| `TECFS_ERR_BAD_VOLUME` | `0Bh` | Requested volume is out of range. |
| `TECFS_ERR_BAD_BLOCK` | `0Ch` | Requested block index is out of range. |
| `TECFS_ERR_UNSUPPORTED` | `E0h` | Service slot exists but is not implemented yet. |

## Bank 3: RTC Boundary

Physical bank 3 currently exposes the RTC service/tool boundary. The hardware
RTC calls still need to be moved or wrapped; UI entries fail explicitly.

| Constant | Address | Status |
| --- | ---: | --- |
| `TECM8_RTC_ENTRY` | `8000h` | Publishes service descriptor, returns `A=83h`, carry clear. |
| `TECM8_RTC_TOOL_ENTRY` | `8010h` | Same descriptor path as entry. |
| `TECM8_RTC_SETUP_UI` | `8020h` | Explicit unsupported error. |
| `TECM8_RTC_PRAM_VIEWER` | `8030h` | Explicit unsupported error. |

RTC parameter block:

| Constant | Address | Meaning |
| --- | ---: | --- |
| `TECM8_RTC_PARAM_BASE` | `3B60h` | Base of RTC parameter block. |
| `TECM8_RTC_PARAM_STATUS` | `3B60h` | Last status code. |
| `TECM8_RTC_PARAM_LAST_ERROR` | `3B61h` | Last error code. |
| `TECM8_RTC_PARAM_BANK` | `3B62h` | Service bank marker. |
| `TECM8_RTC_PARAM_VERSION` | `3B63h` | Service ABI version. |
| `TECM8_RTC_PARAM_FEATURES` | `3B64h` | Feature flags. |

RTC status and feature values:

| Constant | Value | Meaning |
| --- | ---: | --- |
| `TECM8_RTC_STATUS_OK` | `00h` | Success. |
| `TECM8_RTC_FEATURE_SERVICE` | `01h` | Basic service boundary present. |
| `TECM8_RTC_ERR_UNSUPPORTED` | `E0h` | UI/tool slot exists but is not implemented yet. |

## Bank 4: GLCD Boundary

Physical bank 4 is the first GLCD relocation boundary. It does not yet contain
the real GLCD implementation; it exposes a descriptor and explicit unsupported
stubs so monitor callers can move to a banked GLCD ABI.

| Constant | Address | Status |
| --- | ---: | --- |
| `TECM8_GLCD_ENTRY` | `8000h` | Publishes service descriptor, returns `A=84h`, carry clear. |
| `TECM8_GLCD_INIT` | `8010h` | Explicit unsupported error. |
| `TECM8_GLCD_CLEAR` | `8020h` | Explicit unsupported error. |
| `TECM8_GLCD_PLOT` | `8030h` | Explicit unsupported error. |

GLCD parameter block:

| Constant | Address | Meaning |
| --- | ---: | --- |
| `TECM8_GLCD_PARAM_BASE` | `3B80h` | Base of GLCD parameter block. |
| `TECM8_GLCD_PARAM_STATUS` | `3B80h` | Last status code. |
| `TECM8_GLCD_PARAM_LAST_ERROR` | `3B81h` | Last error code. |
| `TECM8_GLCD_PARAM_BANK` | `3B82h` | Service bank marker. |
| `TECM8_GLCD_PARAM_VERSION` | `3B83h` | Service ABI version. |
| `TECM8_GLCD_PARAM_FEATURES` | `3B84h` | Feature flags. |

GLCD status and feature values:

| Constant | Value | Meaning |
| --- | ---: | --- |
| `TECM8_GLCD_STATUS_OK` | `00h` | Success. |
| `TECM8_GLCD_FEATURE_BOUNDARY` | `01h` | Basic service boundary present. |
| `TECM8_GLCD_ERR_UNSUPPORTED` | `E0h` | Service slot exists but is not implemented yet. |

## Proof Hooks

The current proof-only hooks are part of the development ABI and should not be
reused accidentally by service implementations.

| Constant | Address | Purpose |
| --- | ---: | --- |
| `TECM8_ABI_TRACE_BASE` | `3100h` | Base of bank ABI proof trace RAM. |
| `TECM8_ABI_TRACE_0` | `3100h` | Bank ABI proof trace byte 0. |
| `TECM8_ABI_TRACE_1` | `3101h` | Bank ABI proof trace byte 1. |
| `TECM8_ABI_TRACE_2` | `3102h` | Bank ABI proof trace byte 2. |
| `TECM8_ABI_TRACE_3` | `3103h` | Bank ABI proof trace byte 3. |
| `TECM8_ABI_TRACE_4` | `3104h` | Bank ABI proof trace byte 4. |
| `TECM8_ABI_TRACE_5` | `3105h` | Bank ABI proof trace byte 5. |
| `TECM8_ABI_TRACE_6` | `3106h` | Bank ABI proof trace byte 6. |
| `TECM8_ABI_TRACE_7` | `3107h` | Bank ABI proof trace byte 7. |
| `TECM8_ABI_TRACE_8` | `3108h` | Bank ABI proof trace byte 8. |
| `TECM8_ABI_TRACE_9` | `3109h` | Bank ABI proof trace byte 9. |
| `TECM8_ABI_FARJUMP_LANDED` | `4100h` | RAM landing routine for the far-jump proof. |
| `TECM8_ABI_BANK1_NESTED` | `80C0h` | Bank-call nested proof target in bank 1. |
| `TECM8_ABI_BANK2_NESTED` | `80D0h` | Bank-call nested proof target in bank 2. |
| `TECM8_ABI_BANK3_FARJUMP` | `80C0h` | Far-jump proof target in bank 3. |

The active proofs are:

```text
npm run proof:bank-abi
npm run proof:tms9918-bank
npm run proof:tecfs-bank
npm run proof:rtc-bank
```
