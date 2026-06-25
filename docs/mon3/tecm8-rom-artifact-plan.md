# TECM8 ROM Artifact Plan

This document captures the ROM layout and build/debug requirements for bringing
MON3Lite and the TECM8 expansion ROM into the TECM8 project. It is intended to
be concrete enough to discuss with the Debug80 team before the build workflow is
locked down.

The strategic direction is:

```text
C000h-FFFFh  fixed 16K MON3/MON3Lite ROM
8000h-BFFFh  16K bank-switched expansion ROM window
0000h-7FFFh  RAM, vectors, monitor RAM, and application workspace
```

MON3 is the baseline. MON3Lite is the transitional fixed ROM: it should preserve
the familiar MON3 turn-on and monitor experience while gradually replacing bulky
or optional subsystems with smaller TECM8-oriented services. TECM8 itself grows
in the expansion ROM window.

## Fixed ROM Direction

The fixed ROM should remain recognisably MON3 at first:

- same reset and turn-on path
- familiar monitor commands
- memory examine/edit and run support
- disassembler retained
- serial/debug utilities retained where practical
- LCD, seven-segment, and keyboard basics retained
- source-compatible service entry points retained where practical

The visible introduction can change once the local ROM build is under control.
The first product change should be small: add a MON3 menu item or command that
launches the TECM8 system in the expansion ROM.

The fixed ROM should gradually become the TECM8 kernel/BIOS layer:

- boot and monitor fallback
- bank selection and long-call services
- keyboard and matrix keyboard services
- compact display abstraction
- SD sector I/O
- TEC-FS minimal services
- stable service ABI for banked tools
- compact error/status reporting

The fixed ROM should avoid large workflows and UI personalities where possible.
Storage browsers, rich GLCD terminal behaviour, file managers, formatters,
repair tools, editor, assembler, BASIC, debugger, and display libraries are
better fits for the expansion ROM unless measurement proves otherwise.

## Expansion ROM Model

The expansion ROM window is `8000h-BFFFh`. It is a 16K address window onto a
larger physical ROM selected by hardware bank bits.

The first target is a 32K physical expansion ROM:

```text
physical ROM offset 0000h-3FFFh  bank 0, appears at 8000h-BFFFh
physical ROM offset 4000h-7FFFh  bank 1, appears at 8000h-BFFFh
```

Both banks are assembled with the same origin:

```asm
.org 8000h
```

The bank select hardware chooses which 16K half is visible at `8000h-BFFFh`.
The current discussion assumes a status bit controls the initial two-bank
selection. Later hardware may expose more bank bits, with a likely target of up
to seven banked ROMs in the same window.

The software model should therefore treat the bank number as a general value,
not as a boolean, even though the first implementation only needs banks 0 and 1.

## Bank Ownership Rule

Bank switching should be owned by the fixed ROM.

Banked code must not directly flip the hardware bank bit unless it is a very
low-level diagnostic. Normal banked tools should call fixed-ROM services:

```text
select bank
get current bank
long-call bank entry
long-return to previous bank
read bank manifest
```

This avoids the common failure mode where code switches away from the bank it is
currently executing from. The safe path is:

```text
fixed ROM saves current bank
fixed ROM selects target bank
fixed ROM calls target entry point in 8000h-BFFFh
banked tool returns to fixed ROM
fixed ROM restores previous bank
fixed ROM returns to caller
```

## Bank Manifest

Each bank should expose a small manifest at a fixed offset, probably at the
start of the bank:

```text
8000h  signature
8008h  manifest version
8009h  bank id
800Ah  bank type
800Bh  ABI requirement
800Ch  default entry point
800Eh  service table pointer
8010h  name pointer or inline name
```

The exact byte layout can change before implementation. The requirement is that
MON3Lite and Debug80 can identify the selected bank, discover its entry point,
and show a meaningful source/debug label for the code currently mapped at
`8000h-BFFFh`.

Likely early bank roles:

```text
bank 0  TECM8 front end, command/menu shell, launcher, common services
bank 1  editor and first tool payloads
```

This is only the first layout. The manifest should make it possible to rearrange
tool placement without changing fixed-ROM code.

## Source Layout

Debug80 already supports copying the bundled MON3 source into a project-local
ROM path:

```text
roms/tec1g/mon3/
roms/tec1g/mon3/mon3.rom.asm
```

For TECM8, this path should become tracked source rather than a disposable local
asset. Generated outputs should remain untracked.

Proposed source layout:

```text
roms/tec1g/mon3/
  mon3.rom.asm
  monitor.asm
  ...

roms/tec1g/tecm8-expansion/
  bank0.rom.asm
  bank1.rom.asm
  bank-manifest.asmi
  bank-services.asmi
  ...
```

The fixed ROM may later be renamed once it diverges enough from MON3. Until
then, keeping the source under `roms/tec1g/mon3/` makes the lineage clear and
keeps Debug80's existing materialised-ROM workflow useful.

## Expected Build Artifacts

The fixed ROM build should produce the normal 16K monitor artifacts:

```text
build/roms/tec1g/mon3/mon3.hex
build/roms/tec1g/mon3/mon3.bin
build/roms/tec1g/mon3/mon3.d8.json
```

The expansion ROM build should produce per-bank artifacts and a combined
physical ROM image:

```text
build/roms/tec1g/tecm8-expansion/bank0.hex
build/roms/tec1g/tecm8-expansion/bank0.bin
build/roms/tec1g/tecm8-expansion/bank0.d8.json

build/roms/tec1g/tecm8-expansion/bank1.hex
build/roms/tec1g/tecm8-expansion/bank1.bin
build/roms/tec1g/tecm8-expansion/bank1.d8.json

build/roms/tec1g/tecm8-expansion/tecm8-expansion-32k.bin
build/roms/tec1g/tecm8-expansion/tecm8-expansion-32k.hex
build/roms/tec1g/tecm8-expansion/tecm8-expansion-32k.d8.json
```

The combined `32K` artifact is the physical ROM image. It contains two 16K
banks, both assembled for the visible address range `8000h-BFFFh`.

The debug metadata needs to preserve bank identity. Two different source lines
may both assemble to address `8000h`, but they are not the same code unless the
same bank is selected.

## Debug80 Support Requirements

The Debug80 workflow should support:

- project-local fixed ROM source under `roms/tec1g/mon3/`
- generated monitor artifacts under `build/roms/tec1g/mon3/`
- project-local expansion ROM source under `roms/tec1g/tecm8-expansion/`
- multiple bank entry files with the same `.org 8000h`
- combined physical expansion ROM output
- bank-aware source maps
- bank-aware breakpoints
- correct source display for the currently selected bank
- emulation of the TEC-1G bank-select status bit or port state
- reset-time default bank selection
- launch/restart using the local fixed ROM and local expansion ROM together

The important debugging case is two banks with overlapping addresses:

```text
bank 0, address 8000h  TECM8 front-end code
bank 1, address 8000h  editor code
```

Debug80 needs to know which bank is mapped when stepping, resolving symbols,
showing source, and applying breakpoints.

## Questions For Debug80

These are the main points to confirm with the Debug80 team:

- Can a project define a fixed monitor ROM at `C000h-FFFFh` and a separate
  banked expansion ROM window at `8000h-BFFFh`?
- Can Debug80 build two or more ROM entry files that all assemble with
  `.org 8000h` and combine them into one physical image?
- Can `.d8.json` represent bank identity for symbols and source lines?
- Can breakpoints be scoped by bank as well as address?
- Can the emulator expose and track the bank-select status bit used by TEC-1G
  expansion hardware?
- Can launch configuration choose the local monitor ROM and local banked
  expansion ROM together?
- Can Debug80 show the active bank in its UI or debug state?
- Can the existing `Debug80: Copy Monitor ROM into Project` command coexist
  with tracked `roms/tec1g/mon3/` source?

## First Milestones

The incremental path should be deliberately conservative:

1. Materialise MON3 into `roms/tec1g/mon3/`.
2. Adjust `.gitignore` so MON3 source and expansion ROM source are tracked, but
   generated build artifacts remain ignored.
3. Build the local MON3 source with no behavioural change.
4. Launch Debug80 using the local MON3 build.
5. Add a tiny expansion ROM bank 0 with a manifest and return stub.
6. Add bank 1 with a different manifest and return stub.
7. Produce a combined 32K expansion ROM artifact.
8. Add a MON3Lite menu item or command that launches bank 0.
9. Prove bank 0 can long-call bank 1 through fixed-ROM bank services.
10. Only then begin moving real TECM8 shell/editor code into banked ROM.

This keeps MON3 usable while the TECM8 operating environment grows around it.
