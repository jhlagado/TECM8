# Debug80 TecMate Demo Milestone

This milestone establishes the next visible target: boot a TEC-1G Debug80
session using the project-owned monitor and expansion ROMs, enter TecMate, and
demonstrate that the banked services are doing useful work together.

The point is not to finish the editor, assembler, TEC-FS, or game profile. The
point is to make the new ROM architecture observable as a small runnable system.

## ROM Demo Command

The current proof-backed ROM demo path is:

```text
npm run demo:tecmate-rom
```

That command builds the TECM8 fixed monitor ROM, builds the banked expansion
ROM image, runs the Debug80 monitor-launch proof, and prints the ROM size
summary. It is the first command to run before a manual Debug80 inspection.

For manual Debug80 inspection, use:

```text
npm run checkpoint:tecmate-rom
```

That command runs the same proof-backed build path and then prints the exact
generated ROM artifacts, monitor route, expected TMS9918 text, last-run trace
markers, compact command matrix, and current ROM footprint to use while
inspecting Debug80.

For a compact integrated milestone report, use:

```text
npm run rom:milestone:status
```

That command rebuilds the ROM size gate and reports the current fixed-monitor
and expansion-bank footprint, plus the latest proof status for monitor launch,
the shell command loop, VDU/TMS9918, TEC-FS, input snapshot, and bank ABI.

This is not the older GLCD editor demo path. Do not load `src/main.asm`, build
`debug80:editor-image`, or use MON3 `GO 4000h` when testing this milestone.
Those remain useful for the previous RAM editor prototype, but this milestone
is about the monitor-owned ROM launch path.

## Demo Shape

The demo should run through Debug80 with the normal TECM8 project ROM artifacts:

- fixed monitor ROM at `C000h-FFFFh`
- banked expansion image in the `8000h-BFFFh` window
- bank 0 service registry installed by the monitor discovery path
- TecMate shell entry reached from the monitor path

The visible flow should be:

```text
reset / launch
  -> MON3-compatible monitor startup path
  -> TecMate entry
  -> bank 0 shell/demo loop
  -> visible VDU/TMS output
  -> input snapshot read
  -> TEC-FS service boundary touched
  -> shell status/result shown
```

The first demo can be scripted rather than fully interactive. It can write fixed
status text, poll input once, call the TEC-FS mount/geometry boundary, and show
the resulting state through the VDU service. That is enough to prove that the
monitor, bank switching, registry, VDU, input, and TEC-FS boundaries are working
as one system.

## Acceptance Criteria

The milestone is complete when:

1. `npm run rom:check` builds the project-owned monitor and expansion ROMs.
2. Debug80 launches those ROM artifacts through the TECM8 profile.
3. The monitor discovery path installs the bank 0 menu/service vectors.
4. A TecMate entry path reaches bank 0 without direct fixed-address coupling.
5. The demo writes visible text through the VDU/TMS service boundary.
6. The demo reads the bank 6 input snapshot boundary and reports a neutral
   state when no input hardware state is present.
7. The demo calls the bank 2 TEC-FS boundary far enough to prove the current
   geometry/locator/mount state is available.
8. The final Debug80 trace or screen state proves success without requiring a
   human to inspect internal memory by hand.
9. `npm run checkpoint:tecmate-rom` is recorded with before/after footprint
   deltas, unless the increment is size-only.
10. `npm run rom:milestone:status` reports `ok` for the integrated ROM proof
    surfaces: monitor launch, shell command loop, VDU/TMS9918, TEC-FS, input
    snapshot, and bank ABI.

This should be an automated Debug80 proof first, with a short manual Debug80
script added once the proof exists. The manual script should be used for human
confidence, not as the only release gate.

## Manual Debug80 Script

1. From the TECM8 repo root, run `npm run checkpoint:tecmate-rom`.
2. Open Debug80 with the TECM8 profile after the command has generated the ROM
   artifacts. The current `main` target may still compile the older
   `src/main.asm` RAM program; for this milestone, use Debug80 only to inspect
   the generated ROM artifacts, reset the machine, and enter the monitor
   `Expansion` menu item.
3. Confirm the machine is using these generated artifacts:
   - monitor ROM: `build/roms/tec1g/tecm8/monitor/monitor.bin`
   - expansion ROM: `build/roms/tec1g/tecm8/expansion/expansion-144k.bin`
4. Reset the machine and let the monitor start normally. Do not start a RAM
   program at `4000h`.
5. Enter the monitor `Expansion` menu item. That path should discover bank 0,
   call the installed expansion menu vector, and return through the monitor
   bank-call path.
6. On the TMS9918 VDU, expect the bank-0 scaffold to write the visible
   `TecMate ROM Shell` title, `TFS:30+1 128M 4K` TEC-FS geometry line,
   `KEY:0000 JOY:00` input echo, `>` prompt, and `POLL` status text after the
   first input/update/render loop slice.
7. In the printed checkpoint output, expect the initial command matrix to show:
   `edit -> EDIT/OK`, `asm -> ASM/BUILD`, `run -> RUN/FILE`,
   `dir -> DIR/OK`, and `dir bad-buffer -> FILE`. The `BUILD` fixture predates
   the later source fix, and `FILE` proves that run rejects a missing artifact.
8. Inspect `installed.editorWindow` for `/src/main.asm`, `ORG 0`, `LD A,1`,
   `RET`, `Ln 01 Col 01 CLEAN Pg 1/1`, loaded line count 3, and cursor address
   `0020h`.
9. If the manual screen differs, compare it with the automated evidence in
   `proofs/tecmate-monitor-launch/tecmate-monitor-launch-last-run.json`.

## Completed Persistent Editor Workflow

The first editor-facing path is now visible and proof-backed:

```text
shell `edit`
  -> project-main target descriptor
  -> TEC-FS target/metadata lookup boundary
  -> interactive bank-4 editor and bank-6 key service
  -> VDU/TMS9918 shows a multi-page 32-byte-record source workspace
  -> bank-2 data-sector writes followed by a metadata-sector commit
  -> shell return and reopen
```

The monitor-launch proof now drives the complete workflow. It observes the
solid-block character cursor, printable insertion and live dirty status, moves
from page one to page two, exercises character delete and record split/join,
grows the persisted source from one sector-page to two, saves two data sectors
and one metadata sector, cancels and then confirms discard, returns to the
shell, and reopens to prove the saved `PAGEY` record persisted while the
discarded `!` suffix did not.

The ROM editor also has a real SD-backed acceptance path:

```text
npm run proof:tecfs-mon3-file
```

It builds a FAT32 Debug80 image containing a formatted `VOLUME.TM8`, resolves
the source through bank 2, edits and saves through the bank-4 TMS9918 editor,
reopens it through the ROM services, and checks the changed record directly in
the host-side image. Normal boot selects the real bank-5 driver; the RAM bridge
is retained when a fast proof explicitly selects `8000h`.

## Completed Self-Hosted Build-And-Run Workflow

The same monitor-launch proof now continues beyond editor persistence:

```text
edit and save invalid source
  -> asm reports BUILD at source record 4
  -> edit reopens at record 4, column 2
  -> fix REX to RET and save
  -> asm emits 3E 5A 32 F0 4F C9 and TMAP
  -> bank 2 records two artifact data writes and two metadata writes
  -> run loads at 4000h, executes the marker write, and returns to the shell
```

This proves the useful bank-7 two-pass subset, source-record diagnostics,
editor handoff, bank-2 artifact contracts, bounded bank-8 loader, program
execution, and safe far-call return as one Debug80 path.

## Non-Goals

This milestone must stay small. It does not require:

- full TEC-FS catalogue allocator beyond the bounded editor source workflow
- the complete Z80/AZM language beyond the documented phase-one subset
- unbounded files larger than the three-page ROM workspace
- a game runtime
- GLCD feature work
- direct boot into TecMate as the final product policy

Those can build on the milestone after the basic ROM-based system is visible.

## Likely Implementation Steps

1. Add a small bank 0 demo command or shell demo mode.
2. Route the demo through the existing expansion service registry rather than
   fixed bank addresses.
3. Reuse the current bank 1 VDU/TMS status/string routines.
4. Reuse the current bank 6 input snapshot service.
5. Reuse the current bank 2 TEC-FS mount/geometry service.
6. Add a Debug80 proof runner that launches the monitor path and asserts the
   trace/screen/status result.
7. Add a short manual Debug80 script after the proof is stable.

The demo should be removed, hidden behind a diagnostic command, or turned into
the first shell status command once the real shell loop starts to replace it.
