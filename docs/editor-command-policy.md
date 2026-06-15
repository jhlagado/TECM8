# Editor Command Policy And Compaction Inventory

This document is the Q5 command-policy inventory for the TECM8 editor. It
exists to stop editor command behavior from being inferred from scattered
branches in `src/editor-interaction.asm`.

The current design rule is simple:

- alphabetic keys are text or commands, never navigation aliases
- movement uses matrix arrow key bytes and modifier bits
- Control is the command modifier
- Shift extends line selections
- future top/end movement should use `Ctrl+Alt+Up` and `Ctrl+Alt+Down` if the
  matrix input path preserves that chord reliably

## Current Command Surface

| Input | Current state | Handler | Policy notes |
| --- | --- | --- | --- |
| Arrow Left | implemented | `EditorKeyCursorLeft` | Clears ordinary selection, moves cursor left, redraws cursor cell range. |
| Arrow Right | implemented | `EditorKeyCursorRight` | Clears ordinary selection, moves cursor right, redraws cursor cell range. |
| Arrow Up | implemented | `EditorKeyCursorUp` | Moves up inside resident window; crosses resident page boundary where available. |
| Arrow Down | implemented | `EditorKeyCursorDown` | Moves down inside resident window; crosses resident page boundary where available. |
| Ctrl+Up | implemented | `EditorKeyPageUp` | Page movement over the same document model, not a separate file/page mode. |
| Ctrl+Down | implemented | `EditorKeyPageDown` | Page movement over the same document model, not a separate file/page mode. |
| Shift+Up | implemented | `EditorKeySelectUp` | Extends whole-line selection upward. |
| Shift+Down | implemented | `EditorKeySelectDown` | Extends whole-line selection downward. |
| Shift+Ctrl+Up | implemented | `EditorKeySelectPageUp` | Extends selection by page. |
| Shift+Ctrl+Down | implemented | `EditorKeySelectPageDown` | Extends selection by page. |
| Ctrl+Alt+Up | planned | none | Proposed top-of-file command; low priority until command dispatch is cleaner. |
| Ctrl+Alt+Down | planned | none | Proposed end-of-file command; low priority until command dispatch is cleaner. |
| Ctrl-S | implemented | `EditorKeySave` | Saves dirty resident sectors; clean save shows status. |
| Ctrl-Q | implemented | `EditorKeyQuit` | Clean quit exits immediately; dirty quit asks status-line confirmation. |
| Ctrl-Z | implemented | `EditorKeyRestorePrompt` | Restore-from-backup confirmation. |
| Ctrl-C | implemented | `EditorKeyCopyBlock` | Arms selected block as copy source. |
| Ctrl-X | implemented | `EditorKeyMoveBlock` | Arms selected block as move source. |
| Ctrl-V | implemented | `EditorKeyPasteBlock` | Pastes pending source at cursor or over destination selection. |
| Ctrl-Y | implemented | `EditorKeyDeleteCurrentLine` | Deletes current line without requiring selection. |
| Ctrl-W | planned | none | Write selected block to named file; not a near-term priority. |
| Ctrl-R | planned | none | Read named block file at cursor or over destination selection. |
| Delete | implemented | `EditorKeyDelete` / `EditorKeyDeleteBlockPrompt` | Deletes char when no selection; selected block asks confirmation. |
| Backspace | implemented | `EditorKeyBackspace` | Deletes before cursor or joins previous line at column 0. |
| Enter | implemented | `EditorKeySplitLine` | Splits current line. |
| Escape | implemented | `EditorKeyEscape` | Clears selection/pending edit state. |
| Printable ASCII | implemented | `EditorKeyInsertPrintable` | Inserts text unless a known modified command consumed the key. |
| Unknown Ctrl+printable | implemented | `EditorKeyUnknownModifiedPrintable` | Suppressed so failed command chords do not insert text. |

## Current Dispatch Shape

`src/editor-keymap.asm` owns key normalization:

- `EditorActionFromKey` maps arrow keys and Ctrl-arrow page movement.
- `EditorModifiedCommandFromKey` maps Ctrl-letter commands before printable
  insertion.
- `EditorShouldIgnoreModifiedPrintable` suppresses unknown Ctrl-printable keys.

`src/editor-interaction.asm` still owns most command execution:

- prompt routing
- insert-mode routing
- movement dispatch
- modified-command dispatch
- command handler tails
- loop return policy

The long-term Q5 target is to keep `editor-interaction.asm` as orchestration
glue, with command policy centralized in keymap/dispatch tables or small helper
families where they save bytes or make command growth safer.

## First Accepted Compaction Pilot

Pilot: normalize Ctrl-modified printable letters in
`EditorModifiedCommandFromKey`.

Before:

```text
npm run z80:size
bytes: 16327
remainingIn16KBank: 57
editor-keymap mappedBytes: 188
```

After:

```text
npm run z80:size
bytes: 16317
remainingIn16KBank: 67
editor-keymap mappedBytes: 178
```

Result: accepted. The pilot saved 10 bytes, removed uppercase/lowercase command
comparison duplication, and made printable Ctrl-Y behave like the documented
Ctrl-Y command path. The special Ctrl-C versus ArrowUp ambiguity remains
guarded by the raw primary matrix key check.

## Dispatch Compaction Candidates

### Modified Command Dispatch

Status: accepted table-driven pilot. The modified-command family now uses a
sentinel-terminated byte-pair table after normalizing printable Ctrl-letter
input. The Ctrl-C versus ArrowUp ambiguity remains outside the table because it
must inspect the raw primary matrix key before treating byte `0x03` as copy.

Before:

```text
npm run z80:size
bytes: 16317
remainingIn16KBank: 67
editor-keymap mappedBytes: 178
```

After:

```text
npm run z80:size
bytes: 16301
remainingIn16KBank: 83
editor-keymap mappedBytes: 141
```

Result: accepted. The table saved 16 more bytes, reduced keymap mapped coverage
by 37 bytes, and centralized the current implemented modified-command policy as
data:

```text
s -> save
q -> quit
z -> restore
c -> copy
x -> move
v -> paste
y -> delete current line
```

The planned named block file commands remain outside the table until they are
implemented:

```text
w -> write block later
r -> read block later
```

Future command additions should extend this table only when they are genuine
Ctrl-modified editor commands. Navigation must continue to enter through
`EditorActionFromKey`, not through alphabetic command aliases.

### Action Dispatch

`EditorDispatchAction` is a dense action range from page movement through
cursor movement. It is a possible jump-table candidate, but only if the handler
pointer table plus indexing code is smaller than the current compare/jump chain.
This is less urgent than modified commands because there are only six actions
today.

### Prompt Dispatch

`EditorPromptDispatch` handles restore, quit, and delete-block confirmation.
This is probably too small for a jump table now, but it should be revisited if
more prompt actions are added.

## Shared Tail Candidates

Shared tails are useful only when the replaced ending is large enough to beat
the branch cost. Prefer local private tails and measure each change.

High-confidence candidates:

- prompt setup tail: store `EditorPromptAction`, load prompt text, call
  `EditorPromptAskYesNo`, return to the loop
- dirty-render tail: call `EditorKeyRenderDirty`, return to the loop
- cell-render tail: call `EditorKeyRenderCurrentLineCellsDirty`, return to the
  loop
- marker-render tail: call `EditorBlockSelectionRenderMarkers`, return to the
  loop
- cursor-column-render tail: call `EditorKeyRenderCursorColumnMove`, return to
  the loop
- cursor-move-render tail: call `EditorKeyRenderCursorMove`, return to the loop

Caution:

- Do not share tiny `JP EditorKeyLoop` endings by themselves.
- Do not force unrelated handlers through a shared tail if each handler needs
  extra register setup that cancels the saving.
- Use `JR` when layout permits; use `JP` only when the saving still survives the
  3-byte branch cost.
- Keep public routine contracts clean. Compact private tails can use registers
  opportunistically, but public `@` entry contracts should remain readable and
  AZM-verifiable.

## Next Q5 Slice

The next compaction slice should choose one of:

1. one shared-tail pilot for two or more command handlers with identical
   render/loop endings.
2. a small action-dispatch experiment only if it can keep movement semantics
   obvious and reduce bytes.

Each slice should record before/after `npm run z80:size`, run targeted editor
proofs, and reject the idea if the byte count or readability does not improve.
