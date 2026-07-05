# Debug80 TecMate Demo Milestone

This milestone establishes the next visible target: boot a TEC-1G Debug80
session using the project-owned monitor and expansion ROMs, enter TecMate, and
demonstrate that the banked services are doing useful work together.

The point is not to finish the editor, assembler, TEC-FS, or game profile. The
point is to make the new ROM architecture observable as a small runnable system.

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
9. `npm run rom:size:summary` is recorded with before/after footprint deltas.

This should be an automated Debug80 proof first, with a short manual Debug80
script added once the proof exists. The manual script should be used for human
confidence, not as the only release gate.

## Non-Goals

This milestone must stay small. It does not require:

- full TEC-FS catalogue, allocator, file load, or file save
- a real assembler
- a complete editor loop
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
