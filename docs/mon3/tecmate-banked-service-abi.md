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

The current proof also treats the far-call stack frame as part of the ABI. A
caller may pass arguments in `AF`, `DE`, and `HL`; the helper saves those before
loading `B`, `C`, and `HL` for the fixed-ROM gateway. The fixed-ROM bank-call
service then restores the original `AF`, `DE`, and `HL` before entering the
target routine. The target returns with a normal `ret`; fixed ROM receives that
return first, restores the saved `SYS_CTRL` value, preserves the callee's final
`AF`, and then returns to the original caller with `SP` back where it started.
There is no separate banked return instruction.

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
| `TECM8_SERVICE_REGISTRY` | `8170h` | Bank 0 assembly-time service registry table. |
| `TECM8_SERVICE_REGISTRY_ENTRY_SIZE` | `04h` | Bytes per service registry entry: service ID, bank, address low, address high. |
| `TECM8_SERVICE_REGISTRY_END` | `00h` | Registry terminator service ID. |
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
| `TECM8_SERVICE_SHELL_ENTRY` | `80h` | Resident shell entry service ID. |
| `TECM8_SERVICE_SHELL_ENTRY_BANK` | `00h` | Resident shell physical bank. |
| `TECM8_SERVICE_SHELL_ENTRY_ADDR` | `8120h` | Resident shell entry address. |
| `TECM8_SERVICE_ERR_UNKNOWN` | `EEh` | Unknown service ID error. |

The registry table is laid out as repeated four-byte records:

```text
byte 0: service ID
byte 1: physical expansion bank
byte 2: entry address low byte
byte 3: entry address high byte
```

The current dispatcher still uses explicit comparisons for minimum ROM risk, but
the table is now present in bank 0 as the stable published map for tools, docs,
and a later table-driven dispatcher.

## Bank 0: Shell Entry

Physical bank 0 owns the first resident TecMate shell and launcher boundary.
The current entry is a descriptor stub; it gives MON3/menu code a stable service
to call before the full shell loop is moved into the expansion ROM.

| Constant | Address | Status |
| --- | ---: | --- |
| `TECM8_SHELL_ENTRY` | `8120h` | Publishes service descriptor, returns `A=80h`, carry clear. |

Shell parameter block:

| Constant | Address | Meaning |
| --- | ---: | --- |
| `TECM8_SHELL_PARAM_BASE` | `3BA0h` | Base of shell parameter block. |
| `TECM8_SHELL_PARAM_STATUS` | `3BA0h` | Last status code. |
| `TECM8_SHELL_PARAM_LAST_ERROR` | `3BA1h` | Last error code. |
| `TECM8_SHELL_PARAM_BANK` | `3BA2h` | Service bank marker. |
| `TECM8_SHELL_PARAM_VERSION` | `3BA3h` | Service ABI version. |
| `TECM8_SHELL_PARAM_FEATURES` | `3BA4h` | Feature flags. |

Shell status and feature values:

| Constant | Value | Meaning |
| --- | ---: | --- |
| `TECM8_SHELL_STATUS_OK` | `00h` | Success. |
| `TECM8_SHELL_FEATURE_ENTRY` | `01h` | Basic resident shell entry boundary present. |

## Bank 1: VDU/TMS9918

Physical bank 1 currently owns the first TMS9918-facing services.

| Constant | Address | Status |
| --- | ---: | --- |
| `TECM8_VDU_ENTRY` | `8000h` | Bank entry marker. |
| `TECM8_VDU_INIT` | `8010h` | Calls TMS init and returns `A=81h`, carry clear. |
| `TECM8_VDU_CLEAR` | `8020h` | Writes zero to VRAM address `0000h`. |
| `TECM8_VDU_SET_CURSOR` | `8030h` | Copies the address parameters into the VDU cursor, returns `A=81h`. |
| `TECM8_VDU_PUT_CHAR` | `8040h` | Writes the parameter byte at the VDU cursor, advances cursor, returns `A=81h`. |
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
| `TECM8_TMS_PARAM_CURSOR_LO` | `3B04h` | VDU cursor low byte. |
| `TECM8_TMS_PARAM_CURSOR_HI` | `3B05h` | VDU cursor high byte. |

Minimal VDU text-console contract:

- `TECM8_VDU_INIT` prepares the TMS backend and returns `A=81h`.
- `TECM8_VDU_CLEAR` currently clears the first VRAM byte only; full-screen clear
  is still future work.
- `TECM8_VDU_SET_CURSOR` takes `TECM8_TMS_PARAM_ADDR_LO/HI` as the cursor
  address and masks the high byte to the 16K VRAM range.
- `TECM8_VDU_PUT_CHAR` writes `TECM8_TMS_PARAM_VALUE` at the current cursor and
  advances the cursor by one byte.
- The low-level TMS calls remain available for backend work and diagnostics.

## Bank 2: TEC-FS

Physical bank 2 currently exposes TEC-FS geometry and volume selection.

| Constant | Address | Status |
| --- | ---: | --- |
| `TECM8_TECFS_ENTRY` | `8000h` | Bank entry marker. |
| `TECM8_TECFS_MOUNT` | `8010h` | Publishes geometry, returns `A=82h`, carry clear. |
| `TECM8_TECFS_SELECT_VOLUME` | `8020h` | Selects volume `0..30`, returns `A=82h`, carry clear. |
| `TECM8_TECFS_READ` | `8030h` | 512-byte sector I/O contract; validates request, then enters the sector driver hook. |
| `TECM8_TECFS_WRITE` | `8040h` | 512-byte sector I/O contract; validates request, then enters the sector driver hook. |
| `TECM8_TECFS_LOAD_RANGE` | `8050h` | Explicit unsupported error. |
| `TECM8_TECFS_SAVE_RANGE` | `8060h` | Explicit unsupported error. |
| `TECM8_TECFS_MAP_BLOCK` | `8070h` | Maps active volume/block index to a 32-bit sector number. |
| `TECM8_TECFS_TRANSLATE_SECTOR` | `8080h` | Adds the mounted image-base LBA to the logical sector in place. |

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

`TECM8_TECFS_SELECT_VOLUME` reads the request-volume parameter, accepts values
`0..30`, stores the accepted value as the active volume, clears status and last
error, and returns `A=82h` with carry clear. A request of `31` or above returns
the bad-volume error with carry set and leaves the previous active volume
unchanged.

Because a 4K block is eight 512-byte sectors, the current
`TECM8_TECFS_MAP_BLOCK` computes a logical TEC-FS volume-set sector:

```text
sector = activeVolume * 40000h + blockIndex * 8
```

This is not yet an absolute card LBA. `TECM8_TECFS_TRANSLATE_SECTOR` performs
the current logical-to-card translation by adding the mounted image-base LBA to
`TECFS_PARAM_SECTOR_0..3` in place. For now the image-base LBA is the fixed
contract value `00000002h`, immediately after the MBR at LBA 0 and the locator
at LBA 1. A later mount implementation should replace that fixed base with the
value read from the locator sector.

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
| `TECFS_PARAM_BUFFER_LO` | `3B52h` | 512-byte sector buffer address low byte. |
| `TECFS_PARAM_BUFFER_HI` | `3B53h` | 512-byte sector buffer address high byte. |
| `TECFS_PARAM_DRIVER_OP` | `3B54h` | Last sector driver operation requested. |
| `TECFS_PARAM_LOCATOR_SECTOR_0` | `3B55h` | TEC-FS locator sector byte 0. |
| `TECFS_PARAM_LOCATOR_SECTOR_1` | `3B56h` | TEC-FS locator sector byte 1. |
| `TECFS_PARAM_LOCATOR_SECTOR_2` | `3B57h` | TEC-FS locator sector byte 2. |
| `TECFS_PARAM_LOCATOR_SECTOR_3` | `3B58h` | TEC-FS locator sector byte 3. |
| `TECFS_PARAM_VOLUME_SECTORS_0` | `3B59h` | 128 MiB volume sector count byte 0. |
| `TECFS_PARAM_VOLUME_SECTORS_1` | `3B5Ah` | 128 MiB volume sector count byte 1. |
| `TECFS_PARAM_VOLUME_SECTORS_2` | `3B5Bh` | 128 MiB volume sector count byte 2. |
| `TECFS_PARAM_VOLUME_SECTORS_3` | `3B5Ch` | 128 MiB volume sector count byte 3. |

TEC-FS sector driver operation values:

| Constant | Value | Meaning |
| --- | ---: | --- |
| `TECFS_DRIVER_OP_READ` | `01h` | Sector driver hook read operation. |
| `TECFS_DRIVER_OP_WRITE` | `02h` | Sector driver hook write operation. |

TEC-FS card locator constants:

| Constant | Value | Meaning |
| --- | ---: | --- |
| `TECFS_LOCATOR_LBA_0` | `01h` | Locator absolute LBA byte 0. |
| `TECFS_LOCATOR_LBA_1` | `00h` | Locator absolute LBA byte 1. |
| `TECFS_LOCATOR_LBA_2` | `00h` | Locator absolute LBA byte 2. |
| `TECFS_LOCATOR_LBA_3` | `00h` | Locator absolute LBA byte 3. |
| `TECFS_VOLUME_SECTORS_0` | `00h` | 128 MiB volume sector count byte 0. |
| `TECFS_VOLUME_SECTORS_1` | `00h` | 128 MiB volume sector count byte 1. |
| `TECFS_VOLUME_SECTORS_2` | `04h` | 128 MiB volume sector count byte 2. |
| `TECFS_VOLUME_SECTORS_3` | `00h` | 128 MiB volume sector count byte 3. |
| `TECFS_IMAGE_BASE_LBA_0` | `02h` | Current image-base LBA byte 0. |
| `TECFS_IMAGE_BASE_LBA_1` | `00h` | Current image-base LBA byte 1. |
| `TECFS_IMAGE_BASE_LBA_2` | `00h` | Current image-base LBA byte 2. |
| `TECFS_IMAGE_BASE_LBA_3` | `00h` | Current image-base LBA byte 3. |

The TEC-FS locator sector is a card-level sector, not part of any single
volume. The current contract places it at absolute LBA 1 on a TEC-formatted
MBR/FAT32 card. LBA 0 remains the MBR. The locator records the volume table used
by the TEC-side mount path; each 128 MiB TEC-FS volume occupies 262,144
512-byte sectors. Future mount code should read this sector, validate its magic
and checksum, then use its volume-start table instead of parsing FAT32
directories on the TEC.

The sector I/O contract uses `TECFS_PARAM_SECTOR_0..3` for the sector to pass
to the driver hook and `TECFS_PARAM_BUFFER_LO..HI` for the RAM buffer. Callers
that start with a volume/block pair should call `TECM8_TECFS_MAP_BLOCK`, then
`TECM8_TECFS_TRANSLATE_SECTOR`, then read or write. The current implementation
records the requested sector driver hook operation, validates the request, and
then calls a replaceable hook. The default hook reports that no low-level SD
sector driver is linked behind the boundary yet.

TEC-FS status codes:

| Constant | Value | Meaning |
| --- | ---: | --- |
| `TECFS_STATUS_OK` | `00h` | Success. |
| `TECFS_ERR_BAD_VOLUME` | `0Bh` | Requested volume is out of range. |
| `TECFS_ERR_BAD_BLOCK` | `0Ch` | Requested block index is out of range. |
| `TECFS_ERR_BAD_SECTOR` | `0Dh` | Requested sector is outside the standard 31-volume span. |
| `TECFS_ERR_BAD_BUFFER` | `0Eh` | Requested sector buffer pointer is zero. |
| `TECFS_ERR_NO_DRIVER` | `E1h` | Request is valid but no low-level SD sector driver is linked yet. |
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
| `TECM8_ABI_FARJUMP_LANDED` | `4200h` | RAM landing routine for the far-jump proof. |
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
