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

The far-call and far-jump ABI has also been tightened. Banked calls preserve the
caller register state that matters to the current convention, and the return
path restores the previous `SYS_CTRL` expansion-bank state. A routine in one
bank can call a routine in another bank and return with a normal `RET`; the
caller does not need to repair the bank selection manually.

That is the critical step that makes expansion ROMs act like callable system
modules rather than isolated code blobs.

## TEC-FS Foundation

Bank 2 now contains a concrete TEC-FS block mapping service. It maps:

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

This does not implement the full filesystem yet, but it turns the storage design
into executable ABI. Later read, write, catalogue, load, and save services can
build on this geometry.

## GLCD Boundary

Bank 4 now has a GLCD boundary. It does not contain the real GLCD
implementation yet. That is deliberate.

The boundary exposes:

```text
TECM8_GLCD_ENTRY
TECM8_GLCD_INIT
TECM8_GLCD_CLEAR
TECM8_GLCD_PLOT
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

The current implementation is a descriptor stub, not the full interactive shell.
That is the right level for this stage. It proves the launch path and reserves a
stable service number before the shell loop is moved into ROM. The actual shell
label is private to bank 0 and is reached through the installed expansion
service vector, not by a fixed address.

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

The expansion ROM is almost empty:

```text
144K total expansion image
672 occupied bytes currently
1681 bytes total high-water span across all banks
```

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
- VDU/TMS9918 services
- TEC-FS
- GLCD services
- RTC tools
- editor, assembler, BASIC, debugger, and game-development support

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
  TEC-FS
  GLCD services
  RTC tools
  editor / assembler / BASIC / debugger later
```

This turns MON3 into the stable low-level system layer and lets TecMate grow into
the actual operating environment.

The next strongest technical step is TEC-FS read/write sector services, because
storage underpins the shell, editor, assembler, project workflow, and later
self-hosted development tools.

## Quality Gate Position

New TecMate code should continue using strict AZM register contracts. The copied
MON3 monitor source does not yet pass strict contracts, so monitor register
contracts are currently treated as an audit surface rather than a release gate.

The current baseline is recorded in
[Monitor Register Contract Audit](monitor-register-contract-audit.md).
