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
- assembler service skeleton
- run service skeleton

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
`TFM1` metadata record, validates sector and buffer inputs, and can call an
installed low-level sector driver through a bank/address hook. This still does
not implement the full catalogue or allocator, but it turns the storage design
into executable ABI. Later catalogue, load, and save services can build on this
geometry and metadata record shape.

The metadata record now has explicit slots for file type, flags, load address,
end address, run address, required hardware, and a long-name reference. The
default formatter creates a blank project record; build tools patch it into
source, binary, game, BASIC, or asset records as needed.

## GLCD Boundary

Bank 4 now has a GLCD boundary. It does not contain the real GLCD
implementation yet. That is deliberate.

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
screen, shows the prompt marker, writes `POLL` through the VDU/TMS9918 status
line after the first input/update/render loop slice, and reserves a stable
service number before the shell loop is moved into ROM. The
actual shell label is private to bank 0 and is reached through the installed
expansion service vector, not by a fixed address.

Bank 0 also exposes `SHL_RUN_COMMAND`, the first one-command shell boundary. It
currently classifies exact `edit`, `asm`, and `run` commands, measures the
command length, rejects unknown commands, and clears reserved target/result
slots. For `asm` and `run`, it now publishes the default target descriptor,
calls the banked assembler or run skeleton, and copies the tool result back into
the shell command result slots. Those slots now have a documented result-code
convention for the future assembler path.

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
2577 occupied bytes currently
2577 bytes total high-water span across all banks
```

This shell home-screen milestone changed the footprint by 118 bytes:

```text
bank 0 span: 788 -> 906 bytes
expansion total span: 2459 -> 2577 bytes
fixed monitor span: unchanged at 16384 bytes
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
- VDU/TMS9918 services, including a cursor-preserving status line
- input snapshot service for matrix keyboard and joystick state
- TEC-FS geometry, locator, metadata, and sector-driver boundaries
- assembler boundary that currently reports unsupported until real assembly is linked
- run boundary that currently reports unsupported until a loader/debugger path is linked
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
  input snapshot services
  TEC-FS
  GLCD services
  RTC tools
  editor / assembler / BASIC / debugger later
```

This turns MON3 into the stable low-level system layer and lets TecMate grow into
the actual operating environment.

The next strongest technical step is to connect the shell result convention,
assembler artifact convention, TEC-FS metadata record, VDU status line, and
input snapshot into a small runnable shell/tool loop. That should happen before
starting a full game engine, because games are a proving profile for the general
TecMate services rather than a separate platform.

## Quality Gate Position

New TecMate code should continue using strict AZM register contracts. The copied
MON3 monitor source does not yet pass strict contracts, so monitor register
contracts are currently treated as an audit surface rather than a release gate.

The current baseline is recorded in
[Monitor Register Contract Audit](monitor-register-contract-audit.md). The
rollout policy is captured in
[Register Contract Policy](register-contract-policy.md).
