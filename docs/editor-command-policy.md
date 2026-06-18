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

- `EditorModifiedCommandFromKey` maps Ctrl-letter commands before printable
  insertion.
- `EditorShouldIgnoreModifiedPrintable` suppresses unknown Ctrl-printable keys.

`src/editor-interaction.asm` still owns most command execution:

- prompt routing
- insert-mode routing
- physical-arrow movement dispatch
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
physical matrix arrow keys in `src/editor-interaction.asm`, not through
alphabetic command aliases.

### Action Dispatch

Status: rejected as a generic table, then replaced by a better simplification.
The action-number layer was removed instead: physical arrows now dispatch
directly to cursor/page handlers in `src/editor-interaction.asm`. A trial
generic pointer table for action and modified-command dispatch cost almost as
much as the compare/jump ladders it replaced, saving only one extra byte beyond
the normal/insert routing merge. The accepted result is direct physical-arrow
dispatch plus the existing modified-command table.

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

The small table pilots are complete and should not be repeated as isolated
byte-shaving work. They proved that the keymap can become more data-driven, but
they also proved that single tiny dispatch tables are not enough: the accepted
modified-command table saved only 16 bytes. The next Q5 work must be a larger
architecture slice with a credible route to hundreds of bytes, and possibly
more after render/navigation policy is simplified.

### Second-Pass Architecture Investigation

Baseline measured on 2026-06-18:

```text
npm run z80:size
bytes: 15639
remainingIn16KBank: 745
editor-interaction mappedBytes: 1181
editor-render mappedBytes: 589
editor-keymap mappedBytes: 141
editor-prompt mappedBytes: 147
```

The baseline command architecture had four separate layers:

1. `EditorActionFromKey` turned physical arrows plus modifiers into six movement
   actions.
2. `EditorModifiedCommandFromKey` turns Ctrl-letter chords into editor command
   bytes.
3. `EditorKeyLoop` repeats normal-mode and insert-mode routing with many direct
   comparisons.
4. Handler bodies perform the edit/navigation work and then locally choose one
   of several render/loop tails.

This is easy to grow, but it is not compact. The cost is no longer mainly the
letter-command lookup; it is the repeated control-flow shape in
`src/editor-interaction.asm`:

- prompt setup appears in restore, quit, and delete-block commands;
- ordinary movement repeatedly clears selection, updates cursor state, renders,
  and returns to the key loop;
- selection movement repeats begin/update/render-marker tails;
- mutation handlers repeatedly clear block state, call a mutation helper, test
  whether anything changed, render dirty state, and return;
- normal mode and insert mode duplicate printable/delete/backspace/newline
  routing;
- error handling has local branches for "ignore boundary" versus "show compact
  error".

The high-value redesign is therefore not "another jump table". It is a small
command-state interpreter that separates command decoding from command effects:

```text
key event -> command id -> command descriptor -> shared executor family
```

The descriptor does not need to be a large C-style structure. It can be a compact
byte stream or fixed byte table, for example:

```text
command id
executor family
operation id or helper address index
render policy
state policy flags
prompt action/text id when needed
```

The first version should keep handler addresses for complex operations rather
than forcing all commands into one generic interpreter. The space win comes from
centralizing the repetitive policy around the handlers:

- selection clearing before ordinary movement/editing,
- block-state clearing before destructive edits,
- "no change" handling after mutation helpers,
- dirty/full-row/cell/cursor/render-marker tail selection,
- prompt setup,
- ignored boundary errors,
- loop return.

### Proposed Command Families

| Family | Examples | Shared policy worth centralizing |
| --- | --- | --- |
| direct command | save, quit, restore, escape | clean command setup and loop return |
| prompt command | restore, dirty quit, delete selected block | store prompt action, choose prompt text, render modal status |
| cursor movement | left, right, up, down | optional selection clear, cursor previous state, cursor render policy |
| page movement | Ctrl-Up, Ctrl-Down | dirty/window errors, cursor reset, viewport render/invalidate |
| selection movement | Shift-Up/Down, Shift-Ctrl-Up/Down | anchor capture/restore, active range update, marker render |
| mutation | insert, delete char, backspace, split, join, delete line, paste | clear block state, call mutation helper, no-change test, dirty render policy |
| block command | copy, move, paste, delete selection | pending source mode, overlap/error policy, marker or dirty render |

### Estimated Savings

The realistic near-term target is not multiple kilobytes from key dispatch
alone. `editor-interaction.asm` maps to about 1.2K, so even a strong rewrite of
that module cannot save more than that module's live footprint. A credible Q5
target is:

- 150-250 bytes from shared prompt setup, render tails, and mutation tails.
- 100-200 bytes from merging normal/insert routing around one command decoder.
- 100-250 bytes from cursor/page/selection movement executor families.
- 50-150 bytes from removing or replacing any remaining command-action
  indirection only when the indexing code stays smaller than the branches.

That gives a conservative near-term target of 400-800 bytes. Multi-K savings
probably require a broader redesign that includes editor-navigation,
editor-block, and display/render policy, not just command dispatch.

### Implementation Slices

Each slice must be measured independently. Reject a slice if it adds complexity
without saving meaningful bytes or making the later interpreter slice clearly
easier.

1. one shared-tail pilot for two or more command handlers with identical
   render/loop endings. Minimum useful saving: 40 bytes.
   - Done 2026-06-18: added private `EditorKeyTail*` shared tails for prompt
     setup, dirty render, current-line cell render, cursor column render, cursor
     movement render, selection marker render, status-row restore, page-move
     cleanup, and selection-page cleanup. This reduced the live source build
     from 15,639 to 15,563 bytes, saving 76 bytes and raising free 16K bank space
     from 745 to 821 bytes. `editor-interaction.asm` mapped coverage fell from
     1,181 to 1,105 bytes.
2. extract prompt command setup into one helper taking prompt action and text
   pointer. Minimum useful saving: 30 bytes, or keep only if it makes prompt
   additions safer.
3. merge normal-mode and insert-mode printable/delete/backspace/newline routing
   so insert mode becomes a policy flag instead of a duplicate branch tree.
   Minimum useful saving: 80 bytes.
   - Done 2026-06-18: merged the normal/insert edit-key routing into
     `EditorKeyEditDispatch`, then removed the redundant movement action enum
     layer so physical arrows dispatch directly in `src/editor-interaction.asm`.
     A generic action/command pointer table was tested and rejected because it
     did not materially reduce size. The accepted source build fell from 15,563
     to 15,463 bytes, saving 100 bytes and raising free 16K bank space from 821
     to 921 bytes. `src/editor-keymap.asm` mapped coverage fell from 141 to 87
     bytes.
4. create a command-result convention for mutation helpers: A=0 for no change,
   A!=0 for dirty, carry for error. Move dirty/cell/full-render decision into a
   shared tail or tiny result table. Minimum useful saving: 100 bytes.
   - Rejected 2026-06-18: a trial added dirty-result and current-line-cells
     result tails for insert, split, join-backspace, delete-char, and paste,
     and removed one duplicated dirty mark from current-line delete. The source
     build fell only from 15,463 to 15,451 bytes, saving 12 bytes. The remaining
     safe duplicate dirty marks in block paste/delete paths would add only low
     tens of bytes, still far below the 100-byte threshold, while making dirty
     ownership less local. The mutation helpers already follow the practical
     return convention; do not add result-tail indirection unless it is part of
     a larger command executor/descriptor rewrite.
5. revisit modified-command execution dispatch only after the handler tails
   above are shared. A jump table by itself is not enough.
6. only after the above, consider a compact descriptor table that encodes command
   family, state flags, and render policy. This is the first slice that could
   justify a larger rewrite.

Each slice should record before/after `npm run z80:size`, run targeted editor
proofs, and reject the idea if the byte count or readability does not improve.

### Guardrails

- Do not reintroduce alphabetic navigation aliases. Movement remains arrow-key
  based.
- Keep Control as the command modifier. Alt parity has been retired.
- Preserve the raw-key guard for Ctrl-C versus physical ArrowUp.
- Keep public `@` labels stable unless a proof or caller is deliberately moved.
- Keep AZM register contracts on public entries and use contract failures as a
  design signal, not as noise to work around.
- Treat the command descriptor format as ROM data. It must be readable in Z80
  assembly and not require large general-purpose decoding machinery.
