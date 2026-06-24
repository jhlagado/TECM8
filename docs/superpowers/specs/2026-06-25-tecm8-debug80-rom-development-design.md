# TECM8 Debug80 ROM Development Design

## Goal

Refine TECM8 into a TEC-1G custom Debug80 project where project-owned ROM
sources live under `roms/`, with separate source areas for the fixed monitor ROM
and the banked expansion ROM.

## Current State

TECM8 currently uses the bundled Debug80 MON-3 profile. `debug80.json` points
`tec1g.romHex` at `roms/tec1g/mon3/mon3.bin`, while `src/main.asm` remains a
RAM-loaded development target at `0x4000`. That RAM-loaded workflow is still
valuable and should continue to work because TECM8 currently calls MON-3 service
addresses through `src/tecm8-bios.asm` and `src/mon3.asmi`.

The repository should track project-owned TECM8 ROM source and project ROM
images under `roms/tec1g/tecm8/`, while leaving bundled MON-3 materialized
copies local.

## Target Shape

TECM8 should use a local Debug80 profile named `tecm8`:

- active monitor ROM: MON-3 for now
- future monitor replacement source: `roms/tec1g/tecm8/monitor/`
- active TECM8 expansion ROM source: `roms/tec1g/tecm8/expansion/`
- RAM-loaded editor/debug targets: preserved

The first active Debug80 config should keep MON-3:

```json
"romHex": "roms/tec1g/mon3/mon3.bin"
```

and load the generated TECM8 expansion ROM:

```json
"expansionRomHex": "build/roms/tec1g/tecm8/expansion/expansion.bin"
```

The expansion source should be declared as an active source-backed
`tec1g.romArtifacts` entry so Debug80 builds it before launch. The monitor
source should exist immediately as an inactive artifact, but `debug80.json`
should not switch `romHex` to the TECM8 monitor image until that image can boot.

## ROM Source Layout

Use one folder per ROM image:

```text
roms/tec1g/tecm8/
  monitor/
    monitor.asm
    monitor.bin
  expansion/
    expansion.asm
    expansion.bin
```

The `monitor` folder is for the future MON-3 replacement at `0xC000-0xFFFF`.
The `expansion` folder is for the banked TECM8 expansion image exposed through
the `0x8000-0xBFFF` window.

Generated build copies and D8 maps should live under:

```text
build/roms/tec1g/tecm8/monitor/
build/roms/tec1g/tecm8/expansion/
```

`build/` remains ignored. The `roms/` source tree must be tracked.

## Build Flow

Add separate build scripts:

- `tools/build-monitor-rom.ts`
- `tools/build-expansion-rom.ts`

Both scripts should use AZM, emit a project-local `.bin` under `roms/`, and emit
generated copies plus D8 maps under `build/roms/`.

Add scripts:

```json
"rom:monitor": "node --experimental-strip-types tools/build-monitor-rom.ts",
"rom:expansion": "node --experimental-strip-types tools/build-expansion-rom.ts",
"rom:check": "npm run rom:monitor && npm run rom:expansion"
```

## Debug80 Configuration

Update `debug80.json` so both existing targets use profile `tecm8`, keep MON-3
as `romHex`, add `expansionRomHex`, and declare the TECM8 ROM sources through
`tec1g.romArtifacts`.

Each target should include these roots:

```json
[
  "src",
  "roms/tec1g/mon3",
  "roms/tec1g/tecm8/monitor",
  "roms/tec1g/tecm8/expansion"
]
```

## Verification

Run:

```bash
npm run rom:check
npm run typecheck
npm test
npm run z80:size
```

The existing RAM-loaded `src/main.asm` development path must still work.
