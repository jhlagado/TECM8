# TecMate OS Progress

This captures the current state of the TecMate-as-operating-system direction.
The purpose of the recent ROM work was not to build the whole OS at once. It was
to create the stable ROM and bank machinery that lets TecMate grow without
forcing every new system function into the already-full fixed monitor ROM.

## What Has Been Built

The expansion ROM now has a banked service structure.

Bank 0 owns the first service registry. Callers can ask for a service by ID, and
bank 0 dispatches to the correct physical bank and entry point. That gives
TecMate a BIOS-like service layer instead of making every caller hard-code every
target bank and address.

The current registered services are:

- VDU/TMS9918 init
- TEC-FS mount
- RTC tool boundary
- GLCD boundary
- TecMate shell entry
- TecMate shell one-command classifier
- input snapshot boundary
- phase-one self-hosted assembler
- validated artifact loader and runner

The far-call and far-jump ABI has also been tightened. Banked calls preserve the
caller register state that matters to the current convention, and the return
path restores the previous `SYS_CTRL` expansion-bank state. A routine in one
bank can call a routine in another bank and return with a normal `RET`; the
caller does not need to repair the bank selection manually.

That is the critical step that makes expansion ROMs act like callable system
modules rather than isolated code blobs.

## TEC-FS Foundation

Bank 2 now contains concrete TEC-FS geometry, block mapping, locator, metadata,
and sector-driver boundary services. It maps:

```text
active volume + 4K block index -> 32-bit 512-byte sector number
```

The current geometry is:

```text
128 MiB volumes
4 KiB blocks
32768 blocks per volume
30 user volumes
1 spare/work volume
31 selectable volumes total
```

It also formats and reads the card-level TEC-FS locator sector, formats a blank
`TFM1` metadata record, validates sector and buffer inputs, calls an installed
low-level sector driver through a bank/address hook, decodes one active 64-byte
TM8 catalogue entry already loaded in RAM, loads up to three source pages,
writes indexed source pages, and commits the updated catalogue size through a
separate metadata-sector write. This still does not implement the full
catalogue walker or general allocator, but the bounded editor persistence path
is executable end to end.

Bank 2 also saves and loads the assembler's binary and `TMAP` artifacts. Each
artifact is written as data plus a separate `TFM1` metadata record through the
installed sector driver. Executable metadata carries the load, exclusive-end,
and run addresses used by bank 8.

The metadata record now has explicit slots for file type, flags, load address,
end address, run address, required hardware, and a long-name reference. The
default formatter creates a blank project record; build tools patch it into
source, binary, game, BASIC, or asset records as needed.

## ROM Editor And GLCD Boundary

Bank 4 now owns the interactive ROM editor alongside the GLCD boundary. The
editor resolves the default main path, loads a three-page/48-record workspace,
consumes translated bank-6 key events, supports cursor and page movement,
printable insertion, character deletion, record split/join, explicit save, and
dirty-exit confirmation. Its TMS9918 cursor temporarily replaces the character
under the caret with a blinking solid block, giving the edit line an
eight-bit-machine feel while preserving the underlying source byte.

The same bank still does not contain the real GLCD implementation. That is
deliberate.

The boundary exposes:

```text
GLC_ENTRY_ADDR
GLC_INIT
GLC_CLEAR
GLC_PLOT
```

The entry reports that the GLCD boundary exists. The operation slots currently
return explicit unsupported errors. This creates a safe migration path: MON3 can
later stop owning GLCD implementation details, and TecMate can move GLCD
routines into expansion ROM without changing the call shape each time.

## TecMate Shell Entry

Bank 0 now exposes a resident TecMate shell entry contract:

```text
SHL_ENTRY = 80h
```

The current implementation is a descriptor and home-screen stub, not the full
interactive shell. That is the right level for this stage. It proves the launch
path, clears the TMS9918 text plane, writes a visible `TecMate ROM Shell`
screen, shows the current TEC-FS geometry as `TFS:30+1 128M 4K`, shows the
current input snapshot as `KEY:0000 JOY:00`, shows the prompt marker, writes
`POLL` through the VDU/TMS9918 status line after the first input/update/render
loop slice, and reserves a stable service number before the shell loop is moved
into ROM. The
actual shell label is private to bank 0 and is reached through the installed
expansion service vector, not by a fixed address.

Bank 0 also exposes `SHL_RUN_COMMAND`, the first one-command shell boundary. It
currently classifies exact `edit`, `asm`, `run`, and `dir` commands, measures
the command length, rejects unknown commands, and clears reserved target/result
slots. `edit` publishes the project-main descriptor, calls the bank-4 editor,
and returns its `OK` or file result. `dir` leaves the target pointer and flags clear, calls the bank-2 TEC-FS
catalogue summarizer, and publishes `SHL_RESULT_OK` with the one-slot summary
count as the result detail. For `asm` and `run`, it publishes the default target
descriptor, calls bank 7 or bank 8, and copies the tool result back into the
shell command result slots. Build errors carry a source record in the result
detail; the next editor launch uses bank 7's line and column diagnostic to
position the caret.

The intended boot path can now become:

```text
reset -> MON3-compatible monitor -> TecMate menu entry -> banked TecMate shell
```

The open product decision is whether reset should eventually enter TecMate
directly or whether TecMate should remain the first MON3/MON3Lite menu item.

## Current ROM Pressure

The fixed monitor ROM is still full:

```text
C000h-FFFFh
16384 bytes used
0 bytes free by current high-water span
```

The expansion ROM still has ample room:

```text
144K total expansion image
15217 occupied bytes currently
15703 bytes total high-water span across all banks
```

The self-hosted build-and-run milestone keeps the expansion footprint bounded:

```text
bank 0 span: unchanged at 1320 bytes
bank 2 span: 1531 -> 2025 bytes
bank 4 span: 2180 -> 2231 bytes
bank 5 span: 279 -> 425 bytes
bank 7 span: 45 -> 2173 bytes
bank 8 span: 45 -> 256 bytes
expansion total span: 6283 -> 9313 bytes
fixed monitor span: unchanged at 16384 bytes
```

The latest implementation loop completed the self-hosted build-and-run path:

- unknown shell commands are now proof-backed as `ERRCMD` / `NONE`, with target
  and result fields clear
- the shell checkpoint matrix is pinned as the current command surface
- TEC-FS saves write resident data pages first and commit catalogue metadata
  separately through bank 2
- the ROM editor uses a three-page source workspace on the VDU/TMS9918 path,
  with GLCD deferred unless needed
- bank 0 is guarded as an exact-word classifier and dispatcher, not a path or
  catalogue parser
- the size gate now prints per-bank soft-budget headroom
- the manual demo path is `edit` -> interactive editor -> bank-6 keys ->
  VDU/TMS9918 block cursor -> TEC-FS data/meta save -> shell return -> reopen
- TEC-FS services are classified as implemented proof services,
  stubbed/reserved services, and deferred filesystem work
- bank 7 assembles the resident source records in two passes, emits a bounded
  binary and fixed-record `TMAP`, and reports line/column diagnostics
- bank 7 accepts pass-one `.equ` constants, simple 16-bit expressions, forward
  labels, a broad eight-bit load/ALU subset, stack operations, and conditional
  control flow; its 48-record proof builds and executes a 59-byte program
- bank 4 reopens at the assembler diagnostic so a failed record can be fixed
- bank 2 writes separate binary/map data and metadata artifacts through the
  installed sector-driver ABI
- bank 8 validates a `4000h-4FFFh` executable, calls it through a RAM
  trampoline, and regains control when the program returns
- the integrated Debug80 proof performs edit, save, diagnose, fix, rebuild,
  execute, and safe shell return

Current size checkpoint:

```text
fixed monitor span: 16384/16384 bytes
bank 0 span: 1745 bytes, softFree=303
bank 1 span: 568 bytes, softFree=3528
bank 2 span: 3640 bytes, softFree=456
bank 3 span: 95 bytes, softFree=929
bank 4 span: 2332 bytes, softFree=1764
bank 5 span: 3673 bytes, softFree=423
bank 6 span: 220 bytes, softFree=804
bank 7 span: 3174 bytes, softFree=5018
bank 8 span: 256 bytes, softFree=3840
expansion total span: 15703 bytes, softFree=17065
```

Manual checkpoint:

```text
npm run checkpoint:tecmate-rom
```

That prints the proof-backed ROM route, the expected TMS9918 shell screen, the
installed monitor vectors, the shell command matrix, the loaded editor records,
the visible clean editor window, the aggregate two-slot `dir` count, the compact
`FILE` error result, the service inventory exercised by the proof, and the
current ROM footprint. It also prints the build diagnostic, emitted machine
code, `TMAP` marker, artifact-write counts, executed marker, and runner return.

That changes the strategy. We do not need to gut MON3 immediately just to make
progress. We can keep MON3 mostly intact while building serious TecMate
functionality in expansion banks.

The fixed ROM still matters, but its role should be small and stable:

- compatibility
- reset/startup
- RST 10h BIOS calls
- bank switching
- stable service entry points

The larger pieces should grow in expansion ROM:

- TecMate shell
- VDU/TMS9918 services, including a cursor-preserving status line
- input snapshot service for matrix keyboard and joystick state
- TEC-FS geometry, locator, metadata, and sector-driver boundaries
- phase-one assembler, diagnostics, binary output, and source map
- bounded executable loader and safe-return runner
- GLCD services
- RTC tools
- editor, assembler, BASIC, debugger, and game-development support

## Next Ambitious Milestone

The next work should turn the bounded single-file loop into a practical project
development environment:

1. Add `.equ`, simple expressions, includes, and a materially broader Z80
   instruction/operand subset capable of building a substantial TecMate tool.
2. Resolve a bounded multi-file project through TEC-FS using a real catalogue
   walk, while retaining the current resident-buffer fast path.
3. Add listing and symbol inspection plus debugger-facing breakpoints, stepping,
   and source lookup from the `TMAP` records.
4. Prove one coherent shell-visible edit, multi-file build, diagnose, inspect,
   debug, rerun, and return workflow in Debug80.
5. Keep bank 0 compact, GLCD optional, and existing editor/build/run contracts
   backward compatible.

## Why This Builds Forward

The system shape is now:

```text
MON3 / fixed ROM:
  compatibility
  reset/startup
  RST 10h BIOS calls
  bank switching
  stable service entry points

Expansion ROM:
  TecMate shell
  VDU/TMS9918 services
  input snapshot services
  TEC-FS
  GLCD services
  RTC tools
  editor / assembler / BASIC / debugger later
```

This turns MON3 into the stable low-level system layer and lets TecMate grow into
the actual operating environment.

The next strongest technical step is to connect the working build artifacts and
source map to multi-file project resolution and debugger operations. That
should happen before starting a full game engine, because games are a proving
profile for the general TecMate services rather than a separate platform.

## Quality Gate Position

New TecMate code should continue using strict AZM register contracts. The copied
MON3 monitor source does not yet pass strict contracts, so monitor register
contracts are currently treated as an audit surface rather than a release gate.

The current baseline is recorded in
[Monitor Register Contract Audit](monitor-register-contract-audit.md). The
rollout policy is captured in
[Register Contract Policy](register-contract-policy.md).
