# Display Service Extraction Plan

This document turns the current GLCD display work into a concrete extraction
plan. The goal is to move reusable display code below the editor so the editor
can become an application layer on top of TECM8 OS services.

The current editor image is not just editor logic. It carries a display
backend, a display scheduler, viewport rendering policy, cursor overlay code,
and editor-specific row/selection drawing. Some of that belongs in a resident
TECM8 display service; some should stay in the editor because it knows source
records, selections, prompts, and project state.

## Current Size Picture

Fresh AZM build of `src/main.asm`:

```text
total binary: 15,463 bytes
```

Approximate display-related contribution:

| Area | Current editor image cost | Notes |
| --- | ---: | --- |
| Direct GLCD tile/backend layer | 1.2K-1.3K | `src/glcd-tile.asm`; writes 6x6 cells into MON3 `TGBUF`, tracks dirty rows/cells, drains cooperative GLCD transfers. |
| Structured display primitives | 0.8K-0.9K | `src/display-model.asm`; clears/draws rows, text runs, gutter markers, cursor byte overlays. |
| Editor viewport rendering | 1.2K-1.3K | `src/editor-viewport.asm`; renders source-record rows into the display model and tracks row text extents. |
| Editor render policy | 0.6K | `src/editor-render.asm`; cursor visibility, dirty row/cell render paths, viewport row movement. |
| Cursor overlay helpers | 0.25K | `src/editor-cursor.asm`; blink and rendered-cursor state. |

Combined current display-side burden:

```text
about 4.2K in the editor/session image
```

This is separate from MON3's existing GLCD package. MON3 already contains a
large reusable font/data asset that the editor does not emit:

```asm
TECM8_GLCD_TILE_FONT_DATA .equ 0xDD9B
```

MON3 GLCD package size from `docs/mon3/glcd-split.md`:

| MON3 GLCD part | Bytes | Current TECM8 reading |
| --- | ---: | --- |
| Font and text constants | 1,544 | Already resident; current editor uses this font by address. |
| Hardware init, clear, mode setup | 130 | Keep as BIOS/display reference or service. |
| Plot and text-mode helpers | 114 | Keep plot/update knowledge, but avoid MON3 terminal policy for editor text. |
| Glyph and cursor renderer | 169 | Useful reference, but current editor already has a more suitable tile path. |
| Drawing primitives | 526 | Useful for graphics mode, not required by source editing. |
| Terminal text core and cursor/scroll viewport | 466 | Mostly unsuitable for a source editor because it is terminal/scrollback policy. |
| Banner bitmap | 1,024 | Not resident service functionality; relocation/removal candidate. |

## Classification

### Resident Display Service

These routines are general enough to become a TECM8 display service. They should
not know about source records, editor selections, project files, or prompts.

| Capability | Current home | Target service shape |
| --- | --- | --- |
| GLCD bitmap mode initialization | `BiosDisplayInit`, MON3 GLCD calls | `DisplayInit`/profile init in fixed ROM or shared display bank. |
| Clear backing bitmap and visible screen | `BiosDisplayClear`, `GlcdTileFlushFull` | Clear/update service with backend-specific implementation. |
| Draw one 6x6 ROM-font cell | `GlcdTileDrawCell` | Cell draw service using resident font pointer. |
| Clear one cell or text row | `GlcdTileClearCell`, row helpers | Cell/row clear primitive. |
| Draw gutter marker glyphs | `DisplayRenderGutterMarker` plus GLCD tile writes | Small marker primitive independent of editor block state. |
| Queue dirty row/cell ranges | `GlcdTileMarkRowDirty`, `GlcdTileMarkCellDirty`, `GlcdTileMarkGutterDirty` | Display scheduler queue. |
| Cooperative flush stepping | `GlcdTileStep` and direct ST7920 row transfer | Backend `step` call that drains bounded work and returns busy/idle. |
| Cursor byte save/restore overlay | `DisplayRenderCursorCell`, `DisplayEraseCursorCell` | Overlay primitive that saves/restores affected bitmap bytes. |

Expected editor-bank saving if these move below the editor:

```text
about 2.0K-2.8K
```

The exact saving depends on whether the editor still links thin compatibility
wrappers or calls a resident service vector directly.

### Shared Helper Candidate

These pieces are reusable, but they may remain linked beside a tool until at
least two tools use them. Moving them too early risks freezing the wrong API.

| Capability | Current home | Why it is not first-wave BIOS code |
| --- | --- | --- |
| Structured row renderer | `DisplayRenderLine`, `DisplayRenderTextRun` | Useful for shell/editor/file picker, but its exact row model may change with TMS. |
| Status row overlay | editor prompt/status paths | General UI concept, but prompt modality belongs to shell/editor policy. |
| Row text extent tracking | `DisplayRowTextExtent`, viewport extent arrays | Useful optimization, but tied to current 20-column GLCD text surface. |
| Proof counters | `GlcdTileStepCount`, byte/clear counts | Test instrumentation, not resident runtime service. |

### Editor-Specific Policy

These must stay above the display service. A future TMS backend should be able
to consume the same editor state without pretending to be the GLCD.

| Policy | Current home | Reason |
| --- | --- | --- |
| Source-record to visible-row mapping | `editor-viewport.asm`, `editor-render.asm` | Knows 32-byte source records, row offsets, and horizontal panning. |
| Selection and pending block markers | `editor-block*.asm`, viewport marker paths | Knows copy/move/delete source and destination state. |
| Prompt strings and modal answers | `editor-prompt.asm`, `editor-interaction.asm` | Editor command policy, not display hardware policy. |
| Dirty source/document state | `editor-navigation.asm`, `editor-render.asm` | File model state, not screen transport state. |
| Cursor logical row/column | `editor-render.asm`, `editor-cursor.asm` | The display service can draw a cursor; the editor owns where it belongs. |

Expected residual editor display cost after a clean service boundary:

```text
about 1.2K-1.8K
```

## Proposed Service Contract

The first service does not need to be abstract enough for every possible VDU.
It should be a narrow TECM8 display contract that the GLCD backend implements
first:

```text
DisplayInit
DisplayClear
DisplayDrawCell(row, col, char)
DisplayClearCell(row, col)
DisplayDrawMarker(row, marker)
DisplayMarkCellDirty(row, col)
DisplayMarkRowDirty(row)
DisplayMarkGutterDirty(row)
DisplayRenderCursor(row, col)
DisplayHideCursor
DisplayStep -> A=busy/idle, carry=error
```

The editor should not call GLCD port code or know `TGBUF` layout directly once
this service exists. GLCD-specific constants can stay inside the backend:

```text
TGBUF address
VPORT address
ST7920 command/data ports
6x6 cell geometry
MON3 font pointer
dirty row/cell transfer masks
```

The editor may still know logical display limits through profile constants:

```text
visible rows
visible columns
status row availability
gutter availability
```

## First Implementation Slice

Do not attempt to move all display code at once. The first safe slice should be
a facade/service boundary that changes ownership without changing behavior.

### DS1: Extract A GLCD Display Service Facade

Goal: make editor/display callers use a service-named facade while keeping the
same implementation and proofs.

Concrete work:

1. Add a small `src/tecm8-display-service.asm` facade with service-level entry
   names that tail-call the current GLCD tile/display routines.
2. Move no low-level code yet. Keep `src/glcd-tile.asm` and
   `src/display-model.asm` behavior unchanged.
3. Update only a few high-level call sites first, preferably cursor overlay and
   dirty-step calls, because their behavior is already well covered.
4. Prove no size regression larger than a small wrapper cost. If wrappers add
   too much, switch to symbol aliases or direct renaming instead of call-through
   wrappers.
5. Record before/after `npm run z80:size` and display proofs.

Definition of done for DS1:

- Existing display/editor proofs pass.
- The live editor still renders the same GLCD output in Debug80.
- The service surface exists without pulling editor state into the backend.
- The size delta is measured and accepted only if it clearly enables later
  extraction.

### DS2: Move Backend-Owned State Together

Once the facade is stable, move backend-owned dirty masks, transfer state,
cursor byte-save scratch, and proof counters into the service module or a
backend state block. This should make the editor-facing files stop looking like
they own GLCD transport.

### DS3: Split Editor Viewport Policy From Display Transport

After DS1/DS2, keep source-record rendering in the editor, but make it emit
display service calls rather than GLCD tile calls. This is the point where a TMS
backend becomes plausible without rewriting editor selection/navigation logic.

## Risks

- A wrapper layer may increase size if implemented as real calls. Use aliases,
  `JP` tails, or direct renames where possible.
- The GLCD backend currently relies on MON3 `TGBUF` RAM and font data. That is
  acceptable for the first service, but the service contract should not promise
  those addresses to callers.
- The display service must not call the matrix keyboard scanner directly from
  random drawing routines. Keyboard/display interleaving should remain at the
  scheduler boundary: poll input, handle key, then drain one display step.
- Moving too much into resident ROM too early could freeze GLCD-specific row
  counts and gutter assumptions before the TMS profile is understood.

## Practical Conclusion

The editor is not unusually large because the display code is wasteful in
isolation. It is large because the first editor has been forced to carry a
display backend that should eventually be shared by the shell, file picker,
keyboard tester, terminal, and later tools.

Promoting the reusable display layer should recover roughly 2-3K from the
editor/tool bank while keeping the existing MON3 1.5K font asset in ROM. The
total system may not shrink by the same amount, but the architecture improves:
the editor becomes an application, and display hardware becomes an OS/profile
service.
