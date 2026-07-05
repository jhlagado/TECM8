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
| `MON_SYS_GET` | `50h` | Return current `SYS_CTRL` shadow. |
| `MON_SYS_SET` | `51h` | Update masked `SYS_CTRL` bits. |
| `MON_BANK_SELECT` | `52h` | Select a physical expansion bank. |
| `MON_BANK_CALL` | `53h` | Call into a bank and restore previous bank on `ret`. |
| `MON_FAR_JUMP` | `54h` | Tail-jump into a bank without resuming after the helper. |
| `SVC_BASE` | `60h` | First RST 10h selector routed to the installed expansion service vector. |

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

## Fixed-ROM Expansion Services

`SVC_BASE` is `RST 10h` selector `C=60h`. MON3 treats `C < SVC_BASE` as a
normal fixed API-table call and `C >= SVC_BASE` as an expansion service request.
The expansion service path calls the installed expansion service vector
registered by bank 0 during discovery. The contract is:

```asm
        ld c,VDU_INIT
        rst 10H
```

`C` carries the TecMate service ID directly. `A`, `B`, `DE`, and `HL` remain
available to the service-specific ABI until the installed dispatcher chooses how
to route the request. The fixed-ROM shim validates the installed service vector,
enters that bank/address through `BiosBankCall`, and lets the installed
dispatcher route through its private registry table.

Target services should take arguments through documented parameter blocks or
service-specific register conventions. Return values follow the banked service
contract: `A` and carry are returned from the target service after fixed ROM
restores the previous `SYS_CTRL` state. Unknown service IDs are returned by the
installed dispatcher as `SVC_ERR_UNKNOWN` with carry set. If no valid service
vector is installed, fixed ROM returns `A=FFh` with carry set.

## Bank 0: Service Registry

Bank 0 owns the first assembly-time service registry. Callers can use:

```asm
        callService VDU_INIT
```

`callService` loads the requested service ID into `C` and enters fixed ROM with
`rst 10H`. MON3 detects `C >= SVC_BASE` and calls the installed service
dispatcher. The service selector stays in `C`, not in a shared RAM byte, so
nested or interrupted calls do not overwrite each other's request. Services that
need more input may use `A`, `B`, `DE`, `HL`, documented parameter blocks, or
other service-specific register conventions. The dispatcher preserves the normal
fixed-ROM bank-call return behaviour: target `A` and carry are returned after
the previous `SYS_CTRL` state is restored.

The bank-0 dispatcher and registry labels are private implementation details
installed through the expansion service vector. They are intentionally not
published as fixed callable addresses.

| Constant | Value | Meaning |
| --- | ---: | --- |
| `SVC_REG_ENTRY_SIZE` | `05h` | Bytes per service registry entry: service ID, bank, address low, address high, target `A`. |
| `SVC_REG_END` | `00h` | Registry terminator service ID. |
| `VDU_INIT` | `60h` | VDU init service ID. |
| `VDU_BANK` | `01h` | VDU init physical bank. |
| `VDU_ADDR` | `8000h` | VDU init enters the bank-origin dispatcher. |
| `TFS_MOUNT` | `61h` | TEC-FS mount service ID. |
| `TFS_BANK` | `02h` | TEC-FS mount physical bank. |
| `TFS_ADDR` | `8000h` | TEC-FS mount enters the bank-origin dispatcher. |
| `RTC_TOOL` | `62h` | RTC tool service ID. |
| `RTC_BANK` | `03h` | RTC tool physical bank. |
| `RTC_ADDR` | `8000h` | RTC tool enters the bank-origin dispatcher. |
| `GLC_ENTRY` | `63h` | GLCD boundary service ID. |
| `GLC_BANK` | `04h` | GLCD boundary physical bank. |
| `GLC_ADDR` | `8000h` | GLCD boundary address. |
| `INP_READ` | `64h` | Input snapshot service ID. |
| `INP_BANK` | `06h` | Input service physical bank. |
| `INP_ADDR` | `8000h` | Input service bank-origin dispatcher. |
| `SHL_ENTRY` | `80h` | Resident shell entry service ID. |
| `SHL_RUN_COMMAND` | `81h` | Resident shell one-command boundary service ID. |
| `SHL_BANK` | `00h` | Resident shell physical bank. |
| `SVC_ERR_UNKNOWN` | `EEh` | Unknown service ID error. |

The registry table is laid out as repeated five-byte records:

```text
byte 0: public service ID carried in C
byte 1: physical expansion bank
byte 2: entry address low byte
byte 3: entry address high byte
byte 4: target-local service selector loaded into A
```

The dispatcher scans this private registry table at runtime. When it finds a
matching public service ID, it patches the saved caller `A` byte in the
`MON_BANK_CALL` frame with byte 4, loads byte 1 into `B`, loads bytes 2 and 3
into `HL`, and enters the fixed-ROM `MON_BANK_CALL` service. This keeps the
public service namespace decoupled from the bank-local service selector without
publishing fixed callable entry points.

## Bank 0: Shell Entry

Physical bank 0 owns the first resident TecMate shell and launcher boundary.
The current private `Tecm8ShellEntry` label publishes a descriptor, clears the
VDU text plane, writes a small shell home screen through the bank-1 VDU
dispatcher, writes a short status string through the VDU status-line service,
and runs one minimal polling-loop step. MON3 and user code do not call that
label directly; they request `SHL_ENTRY` through the installed service vector.

The first visible home screen is deliberately small:

```text
TecMate ROM Shell
TFS:30+1 128M 4K
KEY:0000 JOY:00

>
```

The strings live in bank 0 source, but the VDU renderer runs in bank 1. Bank 0
therefore copies each home-screen line into `SHL_LINE_BUFFER` in RAM before
calling the VDU bank. Banked services must not pass private bank-local string
addresses to another bank unless that bank is deliberately selected.

The `TFS:30+1 128M 4K` line is the current TEC-FS mount geometry: 30 user
volumes plus one spare/work volume, 128 MiB per volume, and 4K allocation
blocks.

The `KEY:0000 JOY:00` line is generated from the current bank-6 input snapshot
copied into the shell loop state. It is an echo/status aid, not a command-line
editor yet.

The private `Tecm8ShellRunCommand` label is the current command-loop boundary.
MON3 and user code also do not call that label directly; they request
`SHL_RUN_COMMAND` through the installed service vector.

Shell parameter block:

| Constant | Address | Meaning |
| --- | ---: | --- |
| `SHL_PARAM_BASE` | `3BA0h` | Base of shell parameter block. |
| `SHL_PARAM_STATUS` | `3BA0h` | Last status code. |
| `SHL_PARAM_LAST_ERROR` | `3BA1h` | Last error code. |
| `SHL_PARAM_BANK` | `3BA2h` | Service bank marker. |
| `SHL_PARAM_VERSION` | `3BA3h` | Service ABI version. |
| `SHL_PARAM_FEATURES` | `3BA4h` | Feature flags. |
| `SHL_PARAM_COMMAND_ACTION` | `3BA5h` | Last command action classification. |
| `SHL_PARAM_COMMAND_LENGTH` | `3BA6h` | Last zero-terminated command length. |
| `SHL_PARAM_COMMAND_TARGET_LO` | `3BA7h` | Low byte of the command target descriptor pointer. |
| `SHL_PARAM_COMMAND_TARGET_HI` | `3BA8h` | High byte of the command target descriptor pointer. |
| `SHL_PARAM_COMMAND_RESULT_LO` | `3BA9h` | Low byte of the latest shell/tool result value. |
| `SHL_PARAM_COMMAND_RESULT_HI` | `3BAAh` | High byte of the latest shell/tool result value. |
| `SHL_TARGET_DESC` | `3BABh` | Five-byte v1 command target descriptor. |
| `SHL_TARGET_ACTION` | `3BABh` | Descriptor action copied from `SHL_PARAM_COMMAND_ACTION`. |
| `SHL_TARGET_KIND` | `3BACh` | Descriptor target kind. |
| `SHL_TARGET_PATH_LO` | `3BADh` | Low byte of resolved path pointer, currently zero. |
| `SHL_TARGET_PATH_HI` | `3BAEh` | High byte of resolved path pointer, currently zero. |
| `SHL_TARGET_FLAGS` | `3BAFh` | Descriptor flags. |
| `SHL_STATUS_BUFFER` | `3B98h` | Short zero-terminated shell status-line buffer. |
| `SHL_STATUS_CAPACITY` | `08h` | Bytes reserved for the shell status-line buffer. |
| `SHL_LINE_BUFFER` | `3AA0h` | RAM transfer buffer for home-screen lines rendered by the VDU bank. |
| `SHL_LINE_CAPACITY` | `20h` | Bytes reserved for the home-screen line transfer buffer. |
| `SHL_SPLASH_BUFFER` | `3BB0h` | RAM copy of the current shell splash string. |
| `SHL_LOOP_TICK` | `3BB8h` | First polling-loop tick counter. |
| `SHL_LOOP_DIRTY` | `3BB9h` | Coarse dirty mask set by the shell loop step. |
| `SHL_LOOP_KEYS_LO` | `3BBAh` | Input snapshot key bitfield low byte copied by the loop step. |
| `SHL_LOOP_KEYS_HI` | `3BBBh` | Input snapshot key bitfield high byte copied by the loop step. |
| `SHL_LOOP_JOYSTICK` | `3BBCh` | Input snapshot joystick byte copied by the loop step. |
| `SHL_LOOP_MODIFIERS` | `3BBDh` | Input snapshot modifier byte copied by the loop step. |
| `SHL_COMMAND_BUFFER` | `3A80h` | Zero-terminated command line for `SHL_RUN_COMMAND`. |
| `SHL_COMMAND_CAPACITY` | `20h` | Maximum bytes scanned from `SHL_COMMAND_BUFFER`. |

Shell status and feature values:

| Constant | Value | Meaning |
| --- | ---: | --- |
| `SHL_STATUS_OK` | `00h` | Success. |
| `SHL_STATUS_UNKNOWN_COMMAND` | `01h` | Command did not match a known shell verb. |
| `SHL_FEATURE_ENTRY` | `01h` | Basic resident shell entry boundary present. |
| `SHL_FEATURE_SPLASH` | `02h` | Entry writes the splash string through the VDU service boundary. |
| `SHL_FEATURE_COMMAND_LOOP` | `04h` | One-command shell boundary present. |
| `SHL_DIRTY_INPUT` | `01h` | Polling loop input snapshot changed/recorded. |
| `SHL_DIRTY_STATUS` | `02h` | Polling loop status line changed. |
| `SHL_ACTION_NONE` | `00h` | No command action selected. |
| `SHL_ACTION_EDIT` | `01h` | Command classified as editor launch. |
| `SHL_ACTION_ASM` | `02h` | Command classified as assembler launch. |
| `SHL_ACTION_RUN` | `03h` | Command classified as program launch. |
| `SHL_TARGET_KIND_NONE` | `00h` | No target has been resolved. |
| `SHL_TARGET_KIND_PROJECT_MAIN` | `01h` | Target is the project main source. |
| `SHL_TARGET_KIND_PROJECT_OUTPUT` | `02h` | Target is the derived project output. |
| `SHL_TARGET_FLAG_DEFAULT` | `01h` | Target came from the command's project default. |
| `SHL_RESULT_NONE` | `00h` | No tool result has been published. |
| `SHL_RESULT_OK` | `01h` | Tool completed successfully. |
| `SHL_RESULT_BUILD_ERROR` | `02h` | Assembler/build tool found source errors. |
| `SHL_RESULT_FILE_ERROR` | `03h` | Tool could not read or write a required file. |
| `SHL_RESULT_UNSUPPORTED` | `04h` | Command is classified but the backing tool is not installed yet. |

If the VDU splash call fails, the shell service stores the returned error code
in `SHL_PARAM_STATUS` and `SHL_PARAM_LAST_ERROR`, then returns
with carry set.

After the splash, `SHL_ENTRY` currently runs one minimal polling-loop step. It
calls `INP_READ`, increments `SHL_LOOP_TICK`, copies the current input snapshot
into `SHL_LOOP_KEYS_LO..SHL_LOOP_MODIFIERS`, sets
`SHL_LOOP_DIRTY=SHL_DIRTY_INPUT+SHL_DIRTY_STATUS`, and renders `POLL` through
`VDU_SVC_STATUS_LINE`. This is deliberately small: it proves the intended
poll/update/render model without becoming a game runtime or full shell loop.

`SHL_RUN_COMMAND` reads a zero-terminated command line from
`SHL_COMMAND_BUFFER` and records the first command-loop result in the shell
parameter block. This is not the full interactive shell. It is the ROM-facing
boundary that lets the monitor or proofs enter the future shell command loop
through the expansion service registry. The current boundary classifies the
first shell verbs: `edit`, `asm`, and `run`. It stores the corresponding
`SHL_ACTION_*` value in `SHL_PARAM_COMMAND_ACTION`, stores the command length
in `SHL_PARAM_COMMAND_LENGTH`, writes `SHL_PARAM_COMMAND_TARGET_LO/HI` to point
at `SHL_TARGET_DESC`, and writes a default target kind. A blank command is a
successful no-op: it leaves `SHL_ACTION_NONE`, records length zero, keeps status
OK, returns `A=80h`, and clears carry. `asm` calls the bank-7 assembler
skeleton, `run` calls the bank-8 run skeleton, and both commands copy the
bank-local tool result bytes back into `SHL_PARAM_COMMAND_RESULT_LO/HI` before
returning `A=80h` with carry clear. Unknown non-empty commands store
`SHL_STATUS_UNKNOWN_COMMAND` in `SHL_PARAM_STATUS` and `SHL_PARAM_LAST_ERROR`,
leave the target/result slots clear, return `A=SVC_ERR_UNKNOWN`, and set carry.
The later editor, assembler, and launcher
services should hang from this boundary rather than being called directly from
MON3.

The command buffer capacity is `SHL_COMMAND_CAPACITY` bytes. The service scans
at most that many bytes, so a missing terminator cannot run into the expansion
menu/service vectors at `3BF0h..3BF7h`. Callers must treat `3A80h..3A9Fh` as
the v1 shell command input slot.

For the future assembler path, `SHL_PARAM_COMMAND_TARGET_LO/HI` is reserved for
a pointer to the resolved command target or artifact descriptor, and
`SHL_PARAM_COMMAND_RESULT_LO/HI` is reserved for tool result reporting. The low
result byte should use `SHL_RESULT_*`; the high result byte is command-specific
detail, such as an assembler diagnostic line or zero when no detail applies.
The current `SHL_RUN_COMMAND` classifier creates only a minimal target
descriptor: `edit` and `asm` use `SHL_TARGET_KIND_PROJECT_MAIN`; `run` uses
`SHL_TARGET_KIND_PROJECT_OUTPUT`; the path pointer remains zero until project
config parsing and path resolution are linked behind the shell. `edit` does not
yet call a banked editor service, so it leaves `SHL_RESULT_NONE` in the result
slots. The bank-7 assembler skeleton and bank-8 run skeleton currently publish
`SHL_RESULT_UNSUPPORTED`, so callers can distinguish recognized tool commands
from unknown shell commands while the real tools are still absent.

## Bank 1: VDU/TMS9918

Physical bank 1 currently owns the first TMS9918-facing services.

Bank 1 exposes one public dispatcher, not one fixed callable address per VDU
routine. Callers enter the dispatcher with `A` set to a bank-local service ID.
The dispatcher looks up that service ID in the bank-local jump table and jumps
to the private implementation. The implementation labels are not ABI; they may
move as the bank grows.

| Constant | Address | Status |
| --- | ---: | --- |
| `VDU_ENTRY` | `8000h` | Bank entry marker. |
| `VDU_CALL` | `8000h` | Bank-origin dispatcher. Input `A` = VDU/TMS service ID. |
| `VDU_TABLE` | private label | Bank-local service table records. |

Bank-local VDU/TMS service IDs:

| Constant | Value | Status |
| --- | ---: | --- |
| `VDU_SVC_INIT` | `01h` | Calls TMS init and returns `A=81h`, carry clear. |
| `VDU_SVC_CLEAR` | `02h` | Fills the 32x24 text name table with the blank character. |
| `VDU_SVC_SET_CURSOR` | `03h` | Copies the address parameters into the VDU cursor, returns `A=81h`. |
| `VDU_SVC_PUT_CHAR` | `04h` | Writes the parameter byte at the VDU cursor, advances cursor, returns `A=81h`. |
| `VDU_SVC_PUT_STRING` | `05h` | Writes a zero-terminated RAM string at the current cursor, returns `A=81h`. |
| `VDU_SVC_NEWLINE` | `06h` | Advances the cursor to the next 32-byte text row, returns `A=81h`. |
| `VDU_SVC_SET_ROWCOL` | `07h` | Sets the cursor from text row/column parameters. |
| `VDU_SVC_SCROLL_UP` | `08h` | Scrolls the 32x24 text name table up one row. |
| `VDU_SVC_STATUS_LINE` | `09h` | Clears the final text row, writes `TMS_PARAM_STRING_LO/HI`, and restores the prior cursor. |
| `VDU_SVC_PUT_STRING_N` | `0Ah` | Writes a bounded RAM string at the current cursor, returns `A=81h`. |
| `TMS_SVC_INIT` | `20h` | Sets TMS register 7 to `F1h`, returns `A=81h`. |
| `TMS_SVC_SET_REGISTER` | `21h` | Writes TMS register from the parameter block. |
| `TMS_SVC_WRITE_VRAM` | `22h` | Writes one byte to TMS VRAM from the parameter block. |
| `TMS_SVC_FILL_VRAM` | `23h` | Fills a VRAM range from the parameter block. |
| `TMS_SVC_READ_VRAM` | `24h` | Reads one byte from TMS VRAM into the parameter block. |

TMS ports:

| Constant | Value |
| --- | ---: |
| `TMS_DATA_PORT` | `BEh` |
| `TMS_CONTROL_PORT` | `BFh` |

TMS parameter block:

| Constant | Address | Meaning |
| --- | ---: | --- |
| `TMS_PARAM_BASE` | `3B00h` | Base of TMS parameter block. |
| `TMS_PARAM_VALUE` | `3B00h` | Byte value for register or VRAM write. |
| `TMS_PARAM_REGISTER` | `3B01h` | TMS register number. |
| `TMS_PARAM_ADDR_LO` | `3B02h` | VRAM address low byte. |
| `TMS_PARAM_ADDR_HI` | `3B03h` | VRAM address high byte. |
| `TMS_PARAM_CURSOR_LO` | `3B04h` | VDU cursor low byte. |
| `TMS_PARAM_CURSOR_HI` | `3B05h` | VDU cursor high byte. |
| `TMS_PARAM_STRING_LO` | `3B06h` | RAM string pointer low byte. |
| `TMS_PARAM_STRING_HI` | `3B07h` | RAM string pointer high byte. |
| `TMS_PARAM_COUNT_LO` | `3B08h` | VRAM fill byte count or bounded string count low byte. |
| `TMS_PARAM_COUNT_HI` | `3B09h` | VRAM fill byte count or bounded string count high byte. |
| `TMS_PARAM_ROW` | `3B0Ah` | Text cursor row for `VDU_SVC_SET_ROWCOL`. |
| `TMS_PARAM_COL` | `3B0Bh` | Text cursor column for `VDU_SVC_SET_ROWCOL`. |
| `VDU_ROW_BYTES` | `20h` | Current text-console row width in bytes. |
| `VDU_SCREEN_BYTES` | `0300h` | Current 32x24 text-console name-table byte count. |
| `VDU_BLANK_CHAR` | `20h` | Character used by `VDU_SVC_CLEAR`. |
| `VDU_ROWS` | `18h` | Current text-console row count. |
| `VDU_SCROLL_BYTES` | `02E0h` | Bytes copied when scrolling rows 1-23 to rows 0-22. |
| `VDU_LAST_ROW_ADDR` | `02E0h` | Start address of the final text row. |

Minimal VDU text-console contract:

- `VDU_SVC_INIT` prepares the TMS backend and returns `A=81h`.
- `VDU_SVC_CLEAR` fills VRAM `0000h..02FFh` with `VDU_BLANK_CHAR`.
- `VDU_SVC_SET_CURSOR` takes `TMS_PARAM_ADDR_LO/HI` as the cursor
  address and masks the high byte to the 16K VRAM range.
- `VDU_SVC_PUT_CHAR` writes `TMS_PARAM_VALUE` at the current cursor and
  advances the cursor by one byte.
- `VDU_SVC_PUT_STRING` reads a zero-terminated RAM string from
  `TMS_PARAM_STRING_LO/HI`, writes each byte through `VDU_SVC_PUT_CHAR`,
  leaves the cursor after the last character written, and does not read
  `TMS_PARAM_COUNT_LO/HI`.
- `VDU_SVC_PUT_STRING_N` reads a RAM string from `TMS_PARAM_STRING_LO/HI`,
  writes at most `TMS_PARAM_COUNT_LO/HI` bytes, stops early at a zero byte, and
  leaves the cursor after the last character written.
- `VDU_SVC_NEWLINE` rounds the current cursor down to the current 32-byte row
  start, adds one row, masks the high byte to the 16K VRAM range, and returns
  `A=81h`.
- `VDU_SVC_SET_ROWCOL` computes `row * 32 + (col & 1Fh)` and stores it in the
  cursor.
- `VDU_SVC_SCROLL_UP` copies rows 1-23 to rows 0-22 through TMS VRAM reads and
  writes, blanks the final row, and leaves the cursor at `VDU_LAST_ROW_ADDR`.
- `VDU_SVC_STATUS_LINE` blanks the final row at `VDU_LAST_ROW_ADDR`, writes the
  zero-terminated RAM string from `TMS_PARAM_STRING_LO/HI`, and restores the
  cursor that was active before the call. Callers should keep status strings to
  the 32-character text row.
- `TMS_SVC_FILL_VRAM` writes `TMS_PARAM_VALUE` to `TMS_PARAM_COUNT_LO/HI`
  bytes starting at `TMS_PARAM_ADDR_LO/HI`.
- `TMS_SVC_READ_VRAM` reads one byte from `TMS_PARAM_ADDR_LO/HI` into
  `TMS_PARAM_VALUE`.
- The low-level TMS calls remain available for backend work and diagnostics.
- Unknown VDU/TMS selectors return `SVC_ERR_UNKNOWN` with carry set and leave
  the VDU cursor parameters unchanged.

## Bank 2: TEC-FS

Physical bank 2 currently exposes TEC-FS geometry and volume selection.

Compact service path:

```text
RST 10h C=TFS_MOUNT (61h)
  -> bank 0 service registry
  -> physical bank 2, HL=8000h, A=TFS_SVC_MOUNT
  -> bank 2 TEC-FS dispatcher
```

Bank 2 has one public entry address. The selected operation is always the
bank-local value in `A`, so the ABI does not depend on fixed addresses for each
TEC-FS routine.

| Public selector | Bank | Entry | Local selector | Current status |
| --- | ---: | ---: | ---: | --- |
| `TFS_MOUNT` (`61h`) | `02h` | `8000h` | `TFS_SVC_MOUNT` (`01h`) | Implemented geometry publish. |
| direct bank call | `02h` | `8000h` | `TFS_SVC_SELECT_VOLUME` (`02h`) | Implemented volume selection. |
| direct bank call | `02h` | `8000h` | `TFS_SVC_READ` (`03h`) | Implemented validation plus sector-driver handoff. |
| direct bank call | `02h` | `8000h` | `TFS_SVC_WRITE` (`04h`) | Implemented validation plus sector-driver handoff. |
| direct bank call | `02h` | `8000h` | `TFS_SVC_LOAD_RANGE` (`05h`) | Reserved; returns unsupported. |
| direct bank call | `02h` | `8000h` | `TFS_SVC_SAVE_RANGE` (`06h`) | Reserved; returns unsupported. |
| direct bank call | `02h` | `8000h` | `TFS_SVC_MAP_BLOCK` (`07h`) | Implemented volume/block to logical sector. |
| direct bank call | `02h` | `8000h` | `TFS_SVC_TRANSLATE_SECTOR` (`08h`) | Implemented logical sector to card LBA. |
| direct bank call | `02h` | `8000h` | `TFS_SVC_FORMAT_LOCATOR` (`09h`) | Implemented locator header formatter. |
| direct bank call | `02h` | `8000h` | `TFS_SVC_READ_LOCATOR` (`0Ah`) | Implemented locator header parser. |
| direct bank call | `02h` | `8000h` | `TFS_SVC_FORMAT_META_RECORD` (`0Bh`) | Implemented `TFM1` metadata formatter. |
| direct bank call | `02h` | `8000h` | `TFS_SVC_PATCH_META_RECORD` (`0Ch`) | Implemented `TFM1` metadata patcher. |
| direct bank call | `02h` | `8000h` | `TFS_SVC_DECODE_CATALOG` (`0Dh`) | Implemented single-entry catalogue decoder. |

| Constant | Address | Status |
| --- | ---: | --- |
| `TFS_ENTRY` | `8000h` | Bank entry marker. |
| `TFS_ENTRY_MOUNT` | `8000h` | Bank-origin dispatcher; use `A=TFS_SVC_MOUNT`. |
| `TFS_SELECT_VOLUME` | `8000h` | Bank-origin dispatcher; use `A=TFS_SVC_SELECT_VOLUME`. |
| `TFS_READ` | `8000h` | Bank-origin dispatcher; use `A=TFS_SVC_READ`. |
| `TFS_WRITE` | `8000h` | Bank-origin dispatcher; use `A=TFS_SVC_WRITE`. |
| `TFS_LOAD_RANGE` | `8000h` | Bank-origin dispatcher; use `A=TFS_SVC_LOAD_RANGE`. |
| `TFS_SAVE_RANGE` | `8000h` | Bank-origin dispatcher; use `A=TFS_SVC_SAVE_RANGE`. |
| `TFS_MAP_BLOCK` | `8000h` | Bank-origin dispatcher; use `A=TFS_SVC_MAP_BLOCK`. |
| `TFS_TRANSLATE_SECTOR` | `8000h` | Bank-origin dispatcher; use `A=TFS_SVC_TRANSLATE_SECTOR`. |
| `TFS_FORMAT_LOCATOR` | `8000h` | Bank-origin dispatcher; use `A=TFS_SVC_FORMAT_LOCATOR`. |
| `TFS_READ_LOCATOR` | `8000h` | Bank-origin dispatcher; use `A=TFS_SVC_READ_LOCATOR`. |
| `TFS_FORMAT_META_RECORD` | `8000h` | Bank-origin dispatcher; use `A=TFS_SVC_FORMAT_META_RECORD`. |
| `TFS_PATCH_META_RECORD` | `8000h` | Bank-origin dispatcher; use `A=TFS_SVC_PATCH_META_RECORD`. |
| `TFS_SVC_MOUNT` | `01h` | Publishes geometry, returns `A=82h`, carry clear. |
| `TFS_SVC_SELECT_VOLUME` | `02h` | Selects volume `0..30`, returns `A=82h`, carry clear. |
| `TFS_SVC_READ` | `03h` | 512-byte sector read contract. |
| `TFS_SVC_WRITE` | `04h` | 512-byte sector write contract. |
| `TFS_SVC_LOAD_RANGE` | `05h` | Explicit unsupported error. |
| `TFS_SVC_SAVE_RANGE` | `06h` | Explicit unsupported error. |
| `TFS_SVC_MAP_BLOCK` | `07h` | Maps active volume/block index to a 32-bit sector number. |
| `TFS_SVC_TRANSLATE_SECTOR` | `08h` | Adds the mounted image-base LBA to the logical sector in place. |
| `TFS_SVC_FORMAT_LOCATOR` | `09h` | Formats a TEC-FS locator header into the caller buffer. |
| `TFS_SVC_READ_LOCATOR` | `0Ah` | Validates a caller-buffer locator header and publishes its geometry. |
| `TFS_SVC_FORMAT_META_RECORD` | `0Bh` | Formats a blank TEC-FS v1 metadata record into the caller buffer. |
| `TFS_SVC_PATCH_META_RECORD` | `0Ch` | Patches mutable fields in a caller-buffer metadata record. |
| `TFS_SVC_DECODE_CATALOG` | `0Dh` | Decodes one active 64-byte TM8 catalogue entry from the caller buffer. |

`TFS_SVC_LOAD_RANGE` and `TFS_SVC_SAVE_RANGE` are reserved TEC-FS calls that
return the unsupported error until the catalogue/range loader exists. The
unknown-selector path returns `SVC_ERR_UNKNOWN` with carry set and does not
modify the TEC-FS status fields.

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

`TFS_SELECT_VOLUME` reads the request-volume parameter, accepts values
`0..30`, stores the accepted value as the active volume, clears status and last
error, and returns `A=82h` with carry clear. A request of `31` or above returns
the bad-volume error with carry set and leaves the previous active volume
unchanged.

Because a 4K block is eight 512-byte sectors, the current
`TFS_MAP_BLOCK` computes a logical TEC-FS volume-set sector:

```text
sector = activeVolume * 40000h + blockIndex * 8
```

This is not yet an absolute card LBA. `TFS_TRANSLATE_SECTOR` performs
the current logical-to-card translation by adding the mounted image-base LBA to
`TFS_PARAM_SECTOR_0..3` in place. For now the image-base LBA is the fixed
contract value `00000002h`, immediately after the MBR at LBA 0 and the locator
at LBA 1. A later mount implementation should replace that fixed base with the
value read from the locator sector.

TEC-FS parameter block:

| Constant | Address | Meaning |
| --- | ---: | --- |
| `TFS_PARAM_BASE` | `3B40h` | Base of TEC-FS parameter block. |
| `TFS_PARAM_ACTIVE_VOLUME` | `3B40h` | Last valid selected volume. |
| `TFS_PARAM_REQUEST_VOLUME` | `3B41h` | Requested volume for select. |
| `TFS_PARAM_STATUS` | `3B42h` | Last status code. |
| `TFS_PARAM_LAST_ERROR` | `3B43h` | Last error code. |
| `TFS_PARAM_VOLUME_MIB` | `3B44h` | Volume size in MiB. |
| `TFS_PARAM_BLOCK_BYTES_LO` | `3B45h` | Block byte count low byte. |
| `TFS_PARAM_BLOCK_BYTES_HI` | `3B46h` | Block byte count high byte. |
| `TFS_PARAM_VOLUME_BLOCKS_LO` | `3B47h` | Volume block count low byte. |
| `TFS_PARAM_VOLUME_BLOCKS_HI` | `3B48h` | Volume block count high byte. |
| `TFS_PARAM_USER_VOLUMES` | `3B49h` | User volume count. |
| `TFS_PARAM_SPARE_VOLUME` | `3B4Ah` | Spare/work volume index. |
| `TFS_PARAM_TOTAL_VOLUMES` | `3B4Bh` | Total selectable volumes. |
| `TFS_PARAM_BLOCK_INDEX_LO` | `3B4Ch` | Requested 4K block index low byte. |
| `TFS_PARAM_BLOCK_INDEX_HI` | `3B4Dh` | Requested 4K block index high byte. |
| `TFS_PARAM_SECTOR_0` | `3B4Eh` | Mapped 512-byte sector number byte 0. |
| `TFS_PARAM_SECTOR_1` | `3B4Fh` | Mapped 512-byte sector number byte 1. |
| `TFS_PARAM_SECTOR_2` | `3B50h` | Mapped 512-byte sector number byte 2. |
| `TFS_PARAM_SECTOR_3` | `3B51h` | Mapped 512-byte sector number byte 3. |
| `TFS_PARAM_BUFFER_LO` | `3B52h` | 512-byte sector buffer address low byte. |
| `TFS_PARAM_BUFFER_HI` | `3B53h` | 512-byte sector buffer address high byte. |
| `TFS_PARAM_DRIVER_OP` | `3B54h` | Last sector driver operation requested. |
| `TFS_PARAM_LOCATOR_SECTOR_0` | `3B55h` | TEC-FS locator sector byte 0. |
| `TFS_PARAM_LOCATOR_SECTOR_1` | `3B56h` | TEC-FS locator sector byte 1. |
| `TFS_PARAM_LOCATOR_SECTOR_2` | `3B57h` | TEC-FS locator sector byte 2. |
| `TFS_PARAM_LOCATOR_SECTOR_3` | `3B58h` | TEC-FS locator sector byte 3. |
| `TFS_PARAM_VOLUME_SECTORS_0` | `3B59h` | 128 MiB volume sector count byte 0. |
| `TFS_PARAM_VOLUME_SECTORS_1` | `3B5Ah` | 128 MiB volume sector count byte 1. |
| `TFS_PARAM_VOLUME_SECTORS_2` | `3B5Bh` | 128 MiB volume sector count byte 2. |
| `TFS_PARAM_VOLUME_SECTORS_3` | `3B5Ch` | 128 MiB volume sector count byte 3. |
| `TFS_PARAM_DRIVER_BANK` | `3B5Dh` | Installed sector driver physical bank, used only when the driver address is nonzero. |
| `TFS_PARAM_DRIVER_ADDR_LO` | `3B5Eh` | Installed sector driver entry address low byte. |
| `TFS_PARAM_DRIVER_ADDR_HI` | `3B5Fh` | Installed sector driver entry address high byte. |

The first directory/list primitive is deliberately small. `TFS_SVC_DECODE_CATALOG`
expects `TFS_PARAM_BUFFER_LO/HI` to point at one 64-byte TM8 v1 file catalogue
entry already loaded in RAM. It rejects inactive entries and bad filename
lengths with `TFS_ERR_BAD_CATALOG`. On success it returns `A=82h`, clears carry,
and publishes the fields needed by a future `ls` display in the small catalogue
decode result block at `TFS_ENTRY_RESULT_BASE`:

| Output alias | Address | Meaning |
| --- | ---: | --- |
| `TFS_ENTRY_RESULT_BASE` | `3BC8h` | Base of the catalogue decode result block. |
| `TFS_PARAM_ENTRY_FILE_ID` | `3BC8h` | File id. |
| `TFS_PARAM_ENTRY_PREFIX_ID` | `3BC9h` | Prefix-table id. |
| `TFS_PARAM_ENTRY_NAME_LEN` | `3BCAh` | Local filename length. |
| `TFS_PARAM_ENTRY_FIRST_BLOCK_LO` | `3BCBh` | First 4K block low byte. |
| `TFS_PARAM_ENTRY_FIRST_BLOCK_HI` | `3BCCh` | First 4K block high byte. |
| `TFS_PARAM_ENTRY_SIZE_0` | `3BCDh` | File size byte 0. |
| `TFS_PARAM_ENTRY_SIZE_1` | `3BCEh` | File size byte 1. |
| `TFS_PARAM_ENTRY_SIZE_2` | `3BCFh` | File size byte 2. |
| `TFS_PARAM_ENTRY_SIZE_3` | `3BD0h` | File size byte 3. |
| `TFS_PARAM_ENTRY_FILE_TYPE` | `3BD1h` | TM8 file type byte. |

This is not yet a full directory walker. Sector reads, prefix resolution,
hidden-file filtering, and multi-entry iteration are expected to layer on this
decoder once the sector-driver path is stable.

Catalog entry constants mirror the host TM8 format:

| Constant | Value | Meaning |
| --- | ---: | --- |
| `TFS_ENTRY_STATUS_ACTIVE` | `01h` | Active file-catalog entry status. |
| `TFS_CATALOG_ENTRY_BYTES` | `40h` | Bytes per TM8 v1 file-catalog entry. |
| `TFS_CATALOG_NAME_BYTES` | `28h` | Maximum local filename bytes. |
| `TFS_CATALOG_OFFSET_STATUS` | `00h` | Entry status offset. |
| `TFS_CATALOG_OFFSET_FILE_ID` | `01h` | File id offset. |
| `TFS_CATALOG_OFFSET_PREFIX_ID` | `02h` | Prefix id offset. |
| `TFS_CATALOG_OFFSET_NAME_LEN` | `03h` | Local filename length offset. |
| `TFS_CATALOG_OFFSET_NAME` | `04h` | Local filename text offset. |
| `TFS_CATALOG_OFFSET_FIRST_BLOCK` | `2Ch` | First 4K block offset. |
| `TFS_CATALOG_OFFSET_FILE_SIZE` | `2Eh` | 32-bit file size offset. |
| `TFS_CATALOG_OFFSET_FILE_TYPE` | `32h` | TM8 file type offset. |
| `TFS_ERR_BAD_CATALOG` | `10h` | Invalid or inactive catalogue entry. |
| `TFS_META_PATCH_BASE` | `3BD8h` | Base of metadata patch parameter block. |
| `TFS_META_PATCH_FILE_TYPE` | `3BD8h` | Metadata file type to write. |
| `TFS_META_PATCH_FLAGS` | `3BD9h` | Metadata flags to write. |
| `TFS_META_PATCH_LOAD_LO` | `3BDAh` | Load address low byte. |
| `TFS_META_PATCH_LOAD_HI` | `3BDBh` | Load address high byte. |
| `TFS_META_PATCH_END_LO` | `3BDCh` | End address low byte. |
| `TFS_META_PATCH_END_HI` | `3BDDh` | End address high byte. |
| `TFS_META_PATCH_RUN_LO` | `3BDEh` | Run address low byte. |
| `TFS_META_PATCH_RUN_HI` | `3BDFh` | Run address high byte. |
| `TFS_META_PATCH_HW_LO` | `3BE0h` | Required hardware bitfield low byte. |
| `TFS_META_PATCH_HW_HI` | `3BE1h` | Required hardware bitfield high byte. |
| `TFS_META_PATCH_NAME_REF_LO` | `3BE2h` | Long-name reference low byte. |
| `TFS_META_PATCH_NAME_REF_HI` | `3BE3h` | Long-name reference high byte. |

TEC-FS sector driver operation values:

| Constant | Value | Meaning |
| --- | ---: | --- |
| `TFS_DRIVER_OP_READ` | `01h` | Sector driver hook read operation. |
| `TFS_DRIVER_OP_WRITE` | `02h` | Sector driver hook write operation. |

TEC-FS card locator constants:

| Constant | Value | Meaning |
| --- | ---: | --- |
| `TFS_LOC_LBA_0` | `01h` | Locator absolute LBA byte 0. |
| `TFS_LOC_LBA_1` | `00h` | Locator absolute LBA byte 1. |
| `TFS_LOC_LBA_2` | `00h` | Locator absolute LBA byte 2. |
| `TFS_LOC_LBA_3` | `00h` | Locator absolute LBA byte 3. |
| `TFS_VOLUME_SECTORS_0` | `00h` | 128 MiB volume sector count byte 0. |
| `TFS_VOLUME_SECTORS_1` | `00h` | 128 MiB volume sector count byte 1. |
| `TFS_VOLUME_SECTORS_2` | `04h` | 128 MiB volume sector count byte 2. |
| `TFS_VOLUME_SECTORS_3` | `00h` | 128 MiB volume sector count byte 3. |
| `TFS_IMAGE_BASE_LBA_0` | `02h` | Current image-base LBA byte 0. |
| `TFS_IMAGE_BASE_LBA_1` | `00h` | Current image-base LBA byte 1. |
| `TFS_IMAGE_BASE_LBA_2` | `00h` | Current image-base LBA byte 2. |
| `TFS_IMAGE_BASE_LBA_3` | `00h` | Current image-base LBA byte 3. |
| `TFS_LOC_MAGIC_0` | `54h` | Locator magic byte 0, `T`. |
| `TFS_LOC_MAGIC_1` | `46h` | Locator magic byte 1, `F`. |
| `TFS_LOC_MAGIC_2` | `53h` | Locator magic byte 2, `S`. |
| `TFS_LOC_MAGIC_3` | `31h` | Locator magic byte 3, `1`. |
| `TFS_LOC_VERSION` | `01h` | Locator sector format version. |
| `TFS_LOC_HEADER_BYTES` | `20h` | Locator sector header size. |
| `TFS_LOC_ENTRY_BYTES` | `10h` | Bytes per fixed volume record. |
| `TFS_LOC_OFFSET_MAGIC` | `00h` | Header magic offset. |
| `TFS_LOC_OFFSET_VERSION` | `04h` | Header version offset. |
| `TFS_LOC_OFFSET_ENTRY_SIZE` | `05h` | Header entry-size offset. |
| `TFS_LOC_OFFSET_TOTAL_VOLUMES` | `06h` | Header total-volume count offset. |
| `TFS_LOC_OFFSET_USER_VOLUMES` | `07h` | Header user-volume count offset. |
| `TFS_LOC_OFFSET_SPARE_VOLUME` | `08h` | Header reserved work-volume index offset. |
| `TFS_LOC_OFFSET_VOLUME_SECTORS` | `09h` | Header sectors-per-volume field offset. |
| `TFS_LOC_OFFSET_GENERATION` | `0Dh` | Header generation field offset. |
| `TFS_LOC_OFFSET_CHECKSUM` | `11h` | Header checksum offset. |
| `TFS_LOC_OFFSET_ENTRIES` | `20h` | First volume record offset. |
| `TFS_LOC_ENTRY_VOLUME` | `00h` | Volume record volume-number offset. |
| `TFS_LOC_ENTRY_ROLE` | `01h` | Volume record role offset. |
| `TFS_LOC_ENTRY_FLAGS` | `02h` | Volume record flags offset. |
| `TFS_LOC_ENTRY_START_LBA` | `03h` | Volume record absolute-start-LBA offset. |
| `TFS_LOC_ENTRY_SECTORS` | `07h` | Volume record sector-count offset. |
| `TFS_LOC_ENTRY_GENERATION` | `0Bh` | Volume record generation offset. |
| `TFS_LOC_ENTRY_CHECKSUM` | `0Fh` | Volume record checksum offset. |
| `TFS_LOC_ROLE_USER` | `01h` | Ordinary user volume role. |
| `TFS_LOC_ROLE_WORK` | `02h` | Reserved work/safety volume role. |
| `TFS_LOC_FLAG_ACTIVE` | `01h` | Volume record is active/valid. |
| `TFS_META_MAGIC_0` | `54h` | Metadata record magic byte 0, `T`. |
| `TFS_META_MAGIC_1` | `46h` | Metadata record magic byte 1, `F`. |
| `TFS_META_MAGIC_2` | `4Dh` | Metadata record magic byte 2, `M`. |
| `TFS_META_MAGIC_3` | `31h` | Metadata record magic byte 3, `1`. |
| `TFS_META_VERSION` | `01h` | Metadata record format version. |
| `TFS_META_RECORD_BYTES` | `20h` | Bytes in the v1 metadata record header. |
| `TFS_META_OFFSET_MAGIC` | `00h` | Metadata record magic offset. |
| `TFS_META_OFFSET_VERSION` | `04h` | Metadata record version offset. |
| `TFS_META_OFFSET_RECORD_BYTES` | `05h` | Metadata record byte-count offset. |
| `TFS_META_OFFSET_FILE_TYPE` | `06h` | Metadata file-type offset. |
| `TFS_META_OFFSET_FLAGS` | `07h` | Metadata flags offset. |
| `TFS_META_OFFSET_LOAD_ADDR` | `08h` | Metadata load-address offset. |
| `TFS_META_OFFSET_END_ADDR` | `0Ah` | Metadata end-address offset. |
| `TFS_META_OFFSET_RUN_ADDR` | `0Ch` | Metadata run-address offset. |
| `TFS_META_OFFSET_REQUIRED_HW` | `0Eh` | Metadata required-hardware bitfield offset. |
| `TFS_META_OFFSET_NAME_REF` | `10h` | Metadata long-name reference/prefix offset. |
| `TFS_FILE_PROJECT` | `01h` | TecMate project metadata file type. |
| `TFS_FILE_SOURCE` | `02h` | Source text file type. |
| `TFS_FILE_BINARY` | `03h` | Binary memory-range file type. |
| `TFS_FILE_GAME` | `04h` | Game/application package file type. |
| `TFS_FILE_BASIC` | `05h` | BASIC program file type. |
| `TFS_FILE_ASSET` | `06h` | Game/editor asset file type. |
| `TFS_META_FLAG_EXECUTABLE` | `01h` | Metadata record describes an executable object. |
| `TFS_META_FLAG_EXP_RAM` | `02h` | Metadata record expects expansion RAM. |
| `TFS_META_HW_TMS9918` | `01h` | Required hardware bit for TMS9918-compatible video. |
| `TFS_META_HW_GLCD` | `02h` | Required hardware bit for GLCD. |
| `TFS_META_HW_JOYSTICK` | `04h` | Required hardware bit for joystick input. |

The TEC-FS locator sector is a card-level sector, not part of any single
volume. The current contract places it at absolute LBA 1 on a TEC-formatted
MBR/FAT32 card. LBA 0 remains the MBR. The locator starts with a 32-byte header
whose magic is `TFS1`, then stores 16-byte volume records. Each record contains
the volume number, role, flags, absolute start LBA, sector count, generation, and
checksum. Each 128 MiB TEC-FS volume occupies 262,144 512-byte sectors. Future
mount code should read this sector, validate its magic and checksum, then use its
volume-start table instead of parsing FAT32 directories on the TEC.

`TFS_FORMAT_LOCATOR` writes the current locator header fields into the buffer at
`TFS_PARAM_BUFFER_LO..HI`. `TFS_READ_LOCATOR` validates the magic/version in
that buffer and copies the locator geometry fields back into the TEC-FS
parameter block. It is a format/parse boundary only; actual SD sector read/write
still goes through `TFS_READ`, `TFS_WRITE`, and the installed sector driver.

`TFS_FORMAT_META_RECORD` writes a blank 32-byte `TFM1` metadata record at
`TFS_PARAM_BUFFER_LO..HI`. The v1 record reserves explicit slots for file type,
flags, load/end/run addresses, required hardware, and a long-name reference. The
default formatted record is `TFS_FILE_PROJECT` with zero flags and addresses, so
the shell/editor/assembler path has a concrete project record shape before the
full catalogue allocator exists.

`TFS_PATCH_META_RECORD` copies the metadata patch parameter block into an
existing `TFM1` record at `TFS_PARAM_BUFFER_LO..HI`. It writes file type, flags,
load/end/run addresses, required hardware, and name reference while preserving
the record magic, version, and byte-count header. This gives the shell,
assembler, and runner a small service for turning a blank metadata record into a
source, binary, game, or asset record without duplicating field offsets.

The sector I/O contract uses `TFS_PARAM_SECTOR_0..3` for the absolute card
sector and `TFS_PARAM_BUFFER_LO..HI` for the RAM buffer. Callers that start with
a volume/block pair should call `TFS_MAP_BLOCK`, then `TFS_TRANSLATE_SECTOR`,
then read or write. `TFS_READ` and `TFS_WRITE` validate the sector and buffer,
record `TFS_PARAM_DRIVER_OP`, and then call the installed sector-driver vector
from `TFS_PARAM_DRIVER_BANK` and `TFS_PARAM_DRIVER_ADDR_LO..HI`. If the driver
address is zero, the service reports the no-driver status with carry set. A
driver receives `A=TFS_DRIVER_OP_READ` or `A=TFS_DRIVER_OP_WRITE` and uses the
TEC-FS parameter block for sector and buffer arguments.

TEC-FS status codes:

| Constant | Value | Meaning |
| --- | ---: | --- |
| `TFS_STATUS_OK` | `00h` | Success. |
| `TFS_ERR_BAD_VOLUME` | `0Bh` | Requested volume is out of range. |
| `TFS_ERR_BAD_BLOCK` | `0Ch` | Requested block index is out of range. |
| `TFS_ERR_BAD_SECTOR` | `0Dh` | Requested sector is outside the standard 31-volume span. |
| `TFS_ERR_BAD_BUFFER` | `0Eh` | Requested sector buffer pointer is zero. |
| `TFS_ERR_BAD_LOCATOR` | `0Fh` | Locator buffer has invalid magic or unsupported version. |
| `TFS_ERR_NO_DRIVER` | `E1h` | Request is valid but no low-level SD sector driver is linked yet. |
| `TFS_ERR_UNSUPPORTED` | `E0h` | Service slot exists but is not implemented yet. |

## Bank 3: RTC Boundary

Physical bank 3 currently exposes the RTC service/tool boundary. The hardware
RTC calls still need to be moved or wrapped; UI entries fail explicitly.

| Constant | Address | Status |
| --- | ---: | --- |
| `RTC_ENTRY` | `8000h` | Publishes service descriptor, returns `A=83h`, carry clear. |
| `RTC_TOOL_ADDR` | `8000h` | Bank-origin dispatcher; use `A=RTC_SVC_TOOL_ENTRY`. |
| `RTC_SETUP_UI` | `8000h` | Bank-origin dispatcher; use `A=RTC_SVC_SETUP_UI`. |
| `RTC_PRAM_VIEWER` | `8000h` | Bank-origin dispatcher; use `A=RTC_SVC_PRAM_VIEWER`. |
| `RTC_SVC_TOOL_ENTRY` | `01h` | Same descriptor path as entry. |
| `RTC_SVC_SETUP_UI` | `02h` | Explicit unsupported error. |
| `RTC_SVC_PRAM_VIEWER` | `03h` | Explicit unsupported error. |

RTC parameter block:

| Constant | Address | Meaning |
| --- | ---: | --- |
| `RTC_PARAM_BASE` | `3B60h` | Base of RTC parameter block. |
| `RTC_PARAM_STATUS` | `3B60h` | Last status code. |
| `RTC_PARAM_LAST_ERROR` | `3B61h` | Last error code. |
| `RTC_PARAM_BANK` | `3B62h` | Service bank marker. |
| `RTC_PARAM_VERSION` | `3B63h` | Service ABI version. |
| `RTC_PARAM_FEATURES` | `3B64h` | Feature flags. |

RTC status and feature values:

| Constant | Value | Meaning |
| --- | ---: | --- |
| `RTC_STATUS_OK` | `00h` | Success. |
| `RTC_FEATURE_SERVICE` | `01h` | Basic service boundary present. |
| `RTC_ERR_UNKNOWN` | `EEh` | Unknown bank-local RTC service. |
| `RTC_ERR_UNSUPPORTED` | `E0h` | UI/tool slot exists but is not implemented yet. |

The bare entry call with `A=00h` and the explicit `RTC_SVC_TOOL_ENTRY` selector
both publish the descriptor. Unknown RTC selectors return `RTC_ERR_UNKNOWN` with
carry set and do not modify the RTC status fields.

## Bank 4: GLCD Boundary

Physical bank 4 is the first GLCD relocation boundary. It does not yet contain
the real GLCD implementation; it exposes a descriptor and explicit unsupported
stubs so monitor callers can move to a banked GLCD ABI.

| Constant | Address | Status |
| --- | ---: | --- |
| `GLC_ENTRY_ADDR` | `8000h` | Publishes service descriptor, returns `A=84h`, carry clear. |
| `GLC_INIT` | `8000h` | Bank-origin dispatcher; use `A=GLC_SVC_INIT`. |
| `GLC_CLEAR` | `8000h` | Bank-origin dispatcher; use `A=GLC_SVC_CLEAR`. |
| `GLC_PLOT` | `8000h` | Bank-origin dispatcher; use `A=GLC_SVC_PLOT`. |
| `GLC_SVC_INIT` | `01h` | Explicit unsupported error. |
| `GLC_SVC_CLEAR` | `02h` | Explicit unsupported error. |
| `GLC_SVC_PLOT` | `03h` | Explicit unsupported error. |

GLCD parameter block:

| Constant | Address | Meaning |
| --- | ---: | --- |
| `GLC_PARAM_BASE` | `3B80h` | Base of GLCD parameter block. |
| `GLC_PARAM_STATUS` | `3B80h` | Last status code. |
| `GLC_PARAM_LAST_ERROR` | `3B81h` | Last error code. |
| `GLC_PARAM_BANK` | `3B82h` | Service bank marker. |
| `GLC_PARAM_VERSION` | `3B83h` | Service ABI version. |
| `GLC_PARAM_FEATURES` | `3B84h` | Feature flags. |

GLCD status and feature values:

| Constant | Value | Meaning |
| --- | ---: | --- |
| `GLC_STATUS_OK` | `00h` | Success. |
| `GLC_FEATURE_BOUNDARY` | `01h` | Basic service boundary present. |
| `GLC_ERR_UNSUPPORTED` | `E0h` | Service slot exists but is not implemented yet. |

## Bank 5: TEC-FS Monitor-Sector Bridge

Physical bank 5 is the TEC-FS sector-driver bridge boundary. TEC-FS calls it
through `TFS_PARAM_DRIVER_BANK` and `TFS_PARAM_DRIVER_ADDR_LO..HI` after
validating the sector and buffer. The long-term role of this bank is to bridge
`TFS_DRIVER_OP_READ` and `TFS_DRIVER_OP_WRITE` to the selected low-level SD
sector routines, without making bank 2 know where those routines live.

The current implementation is a simulated bridge used by `proof:tecfs-bank`: it
returns `A=85h` with carry clear, writes `TFS_BRIDGE_READ_MARKER` into the
caller buffer for read requests, and accepts write requests without touching
media. Replacing this simulation with the real SD bridge should not change the
bank-2 sector I/O ABI.

Unknown bridge operation selectors return `SVC_ERR_UNKNOWN` with carry set and
do not modify the TEC-FS status fields.

## Bank 6: Input Snapshot Boundary

Physical bank 6 owns the first matrix-keyboard and joystick-facing service
boundary. The current implementation is deliberately neutral: it publishes a
valid service boundary and returns a no-input snapshot until real keyboard and
joystick scanning code is attached.

| Constant | Address | Status |
| --- | ---: | --- |
| `INP_ENTRY` | `8000h` | Bank-origin dispatcher; use `A=INP_SVC_READ`. |
| `INP_SVC_READ` | `01h` | Reads the current input snapshot, returns `A=86h`, carry clear. |

Input parameter block:

| Constant | Address | Meaning |
| --- | ---: | --- |
| `INP_PARAM_BASE` | `3BC0h` | Base of input parameter block. |
| `INP_PARAM_STATUS` | `3BC0h` | Last status code. |
| `INP_PARAM_LAST_ERROR` | `3BC1h` | Last error code. |
| `INP_PARAM_BANK` | `3BC2h` | Service bank marker. |
| `INP_PARAM_VERSION` | `3BC3h` | Service ABI version. |
| `INP_PARAM_KEYS_LO` | `3BC4h` | Low byte of the future matrix-key snapshot. |
| `INP_PARAM_KEYS_HI` | `3BC5h` | High byte of the future matrix-key snapshot. |
| `INP_PARAM_JOYSTICK` | `3BC6h` | Joystick bitfield. |
| `INP_PARAM_MODIFIERS` | `3BC7h` | Future modifier/input-mode flags. |

Input status and joystick values:

| Constant | Value | Meaning |
| --- | ---: | --- |
| `INP_STATUS_OK` | `00h` | Success. |
| `INP_ERR_UNKNOWN` | `EEh` | Unknown bank-local input service. |
| `INP_JOY_UP` | `01h` | Joystick up bit. |
| `INP_JOY_DOWN` | `02h` | Joystick down bit. |
| `INP_JOY_LEFT` | `04h` | Joystick left bit. |
| `INP_JOY_RIGHT` | `08h` | Joystick right bit. |
| `INP_JOY_FIRE_1` | `10h` | Primary fire bit. |
| `INP_JOY_FIRE_2` | `20h` | Secondary fire bit. |

The unknown-selector path returns `INP_ERR_UNKNOWN` with carry set and does not
modify the input status fields.

`INP_READ` is intended to become the common low-level input snapshot used by
the shell, editor, assembler, debugger, and game support code. It stays generic:
game-specific controls should interpret this snapshot rather than adding a
separate monitor-facing game input API.

## Bank 7: Assembler Skeleton

Physical bank 7 owns the first assembler service skeleton. It is not the
self-hosted assembler yet; it is the reserved banked boundary that the shell can
target once the assembler grows out of the current command classifier.

| Constant | Address/Value | Meaning |
| --- | ---: | --- |
| `ASM_ENTRY` | `8000h` | Bank-origin dispatcher for assembler-local service IDs. |
| `ASM_BANK` | `07h` | Physical bank holding the assembler skeleton. |
| `ASM_SVC_ASSEMBLE` | `01h` | Assemble/build request selector. |
| `ASM_PARAM_BASE` | `3BE4h` | Base of assembler parameter block. |
| `ASM_PARAM_STATUS` | `3BE4h` | Last assembler status code. |
| `ASM_PARAM_LAST_ERROR` | `3BE5h` | Last assembler error code. |
| `ASM_PARAM_BANK` | `3BE6h` | Service bank marker. |
| `ASM_PARAM_VERSION` | `3BE7h` | Service ABI version. |
| `ASM_PARAM_TARGET_LO` | `3BE8h` | Target descriptor pointer low byte. |
| `ASM_PARAM_TARGET_HI` | `3BE9h` | Target descriptor pointer high byte. |
| `ASM_PARAM_RESULT_LO` | `3BEAh` | Shell/tool result low byte. |
| `ASM_PARAM_RESULT_HI` | `3BEBh` | Shell/tool result high byte or diagnostic detail. |
| `ASM_STATUS_OK` | `00h` | Success. |
| `ASM_ERR_UNKNOWN` | `EEh` | Unknown assembler-local service. |
| `ASM_ERR_UNSUPPORTED` | `E0h` | Assembler service exists but is not implemented yet. |

`ASM_SVC_ASSEMBLE` is intentionally unsupported at this stage. The skeleton
records bank/version, sets `ASM_PARAM_STATUS` and `ASM_PARAM_LAST_ERROR` to
`ASM_ERR_UNSUPPORTED`, writes `SHL_RESULT_UNSUPPORTED` to
`ASM_PARAM_RESULT_LO`, clears `ASM_PARAM_RESULT_HI`, preserves target
descriptor pointer, and returns `A=ASM_ERR_UNSUPPORTED` with carry set. This
lets the shell and later project metadata path point at an assembler boundary
without inventing the assembler implementation early.

Unknown assembler-local selectors return `A=ASM_ERR_UNKNOWN` with carry set,
preserve the assembler status fields, and do not dispatch through the
unsupported assemble path.

## Bank 8: Run Skeleton

Physical bank 8 owns the first run-command service skeleton. It is not the
program loader or debugger yet; it is the reserved banked boundary that will
eventually launch the build artifact described by the shell target descriptor.

| Constant | Address/Value | Meaning |
| --- | ---: | --- |
| `RUN_ENTRY` | `8000h` | Bank-origin dispatcher for run-local service IDs. |
| `RUN_BANK` | `08h` | Physical bank holding the run skeleton. |
| `RUN_SVC_RUN` | `01h` | Run request selector. |
| `RUN_PARAM_BASE` | `3BF8h` | Base of run parameter block. |
| `RUN_PARAM_STATUS` | `3BF8h` | Last run status code. |
| `RUN_PARAM_LAST_ERROR` | `3BF9h` | Last run error code. |
| `RUN_PARAM_BANK` | `3BFAh` | Service bank marker. |
| `RUN_PARAM_VERSION` | `3BFBh` | Service ABI version. |
| `RUN_PARAM_TARGET_LO` | `3BFCh` | Target descriptor pointer low byte. |
| `RUN_PARAM_TARGET_HI` | `3BFDh` | Target descriptor pointer high byte. |
| `RUN_PARAM_RESULT_LO` | `3BFEh` | Shell/tool result low byte. |
| `RUN_PARAM_RESULT_HI` | `3BFFh` | Shell/tool result high byte or diagnostic detail. |
| `RUN_STATUS_OK` | `00h` | Success. |
| `RUN_ERR_UNKNOWN` | `EEh` | Unknown run-local service. |
| `RUN_ERR_UNSUPPORTED` | `E0h` | Run service exists but is not implemented yet. |

`RUN_SVC_RUN` is intentionally unsupported at this stage. The skeleton records
bank/version, sets `RUN_PARAM_STATUS` and `RUN_PARAM_LAST_ERROR` to
`RUN_ERR_UNSUPPORTED`, writes `SHL_RESULT_UNSUPPORTED` to
`RUN_PARAM_RESULT_LO`, clears `RUN_PARAM_RESULT_HI`, preserves target
descriptor pointer, and returns `A=RUN_ERR_UNSUPPORTED` with carry set.

Unknown run-local selectors return `A=RUN_ERR_UNKNOWN` with carry set, preserve
the run status fields, and do not dispatch through the unsupported run path.

`SHL_RUN_COMMAND` now performs the first shell-to-tool handoff for `asm` and
`run`. It publishes the shell `SHL_TARGET_DESC`, copies that pointer into the
relevant bank-local parameter block, calls bank 7 or bank 8, and copies the
bank-local result bytes back into `SHL_PARAM_COMMAND_RESULT_LO/HI`. The
assembler/run skeleton proof verifies that behaviour through the shell boundary
rather than manually calling the tool banks.

## Proof Hooks

The current proof-only hooks are part of the development ABI and should not be
reused accidentally by service implementations.

| Constant | Address | Purpose |
| --- | ---: | --- |
| `ABI_TRACE_BASE` | `3100h` | Base of bank ABI proof trace RAM. |
| `ABI_TRACE_0` | `3100h` | Bank ABI proof trace byte 0. |
| `ABI_TRACE_1` | `3101h` | Bank ABI proof trace byte 1. |
| `ABI_TRACE_2` | `3102h` | Bank ABI proof trace byte 2. |
| `ABI_TRACE_3` | `3103h` | Bank ABI proof trace byte 3. |
| `ABI_TRACE_4` | `3104h` | Bank ABI proof trace byte 4. |
| `ABI_TRACE_5` | `3105h` | Bank ABI proof trace byte 5. |
| `ABI_TRACE_6` | `3106h` | Bank ABI proof trace byte 6. |
| `ABI_TRACE_7` | `3107h` | Bank ABI proof trace byte 7. |
| `ABI_TRACE_8` | `3108h` | Bank ABI proof trace byte 8. |
| `ABI_TRACE_9` | `3109h` | Bank ABI proof trace byte 9. |
| `ABI_FARJUMP_LANDED` | `4300h` | RAM landing routine for the far-jump proof. |
| `ABI_PROBE_REQUEST` | `311Ch` | RAM selector used when a proof must preserve caller `A`. |
| `ABI_PROBE_NESTED` | `90h` | Proof selector for nested bank-call dispatch. |
| `ABI_PROBE_PRESERVE` | `91h` | Proof selector for register-preservation dispatch. |
| `ABI_PROBE_FARJUMP` | `92h` | Proof selector for non-returning far-jump dispatch. |
| `ABI_PROBE_RETURNING_FARJUMP` | `93h` | Proof selector for far-jump return-suppression dispatch. |

The bank ABI proof deliberately does not publish fixed expansion-ROM target
addresses. It enters banks through their bank origin or the installed service
bridge and lets each bank dispatch to private labels.

The active proofs are:

```text
npm run proof:bank-abi
npm run proof:tms9918-bank
npm run proof:tecfs-bank
npm run proof:input-bank
npm run proof:assembler-bank
npm run proof:rtc-bank
```
