# TecMate Self-Hosted Assembler Direction

TecMate should use AZM as the reference assembly language, but the self-hosted
assembler should begin with a small, reliable AZM-compatible subset. The aim is
source portability: code that fits the subset should assemble on the TEC-1G and
also assemble with host AZM.

This is not a plan to clone all of AZM inside the 16K monitor or the first
expansion ROM. The first assembler must assemble ordinary Z80 source correctly,
produce useful errors, and fit the TecMate shell/editor workflow. Advanced AZM
features can follow after the core is trustworthy.

## Reference Model

Host AZM remains the full-featured reference assembler:

- broad AZM syntax and diagnostics
- D8/D8M artifacts and source maps
- register-contract analysis
- advanced project tooling
- host-side build and proof automation

The TecMate assembler is the self-hosted subset:

- small enough for the banked TecMate environment
- compatible with host AZM for accepted source
- focused on code a user can edit, assemble, run, and debug on the machine
- biased toward register-first APIs and visible machine-code learning

The important rule is that TecMate source should not grow a new dialect unless
there is a measured reason. Any syntax accepted by the self-hosted assembler
should either be AZM-compatible or explicitly documented as a TecMate-only
extension.

## Phase 1: Core Subset

Phase 1 should assemble normal source files without clever language features.

Required:

- Z80 instruction mnemonics and operands
- global labels
- numeric literals in the forms already common in the project
- simple constant expressions
- `.equ`
- `.org`
- `.db`
- `.dw`
- comments
- binary output
- symbol table output sufficient for the shell/debugger
- clear source-line errors

Deliberately exclude from the first implementation:

- register-contract checking
- `op`
- `.import`
- layouts
- enums
- complex macro systems
- full expression language compatibility
- generated D8/D8M parity
- advanced include/module semantics

This gives TecMate a practical assembler before it tries to become AZM.

## Profile-Generated Source Compatibility

Profile preprocessors must generate source that the TecMate assembler can
eventually assemble. The preprocessor can be smarter than the assembler, but
its output should be boring.

The safe generated subset is:

- ordinary labels
- generated labels with stable prefixes
- `.equ`
- `.org` only where the target format requires it
- `.db`
- `.dw`
- simple numeric expressions already accepted by Phase 1
- simple include order that Phase 2 can reproduce
- comments that identify generated sections and source profile paths

Generated profile output should not require these features from the first
self-hosted assembler:

- `op`
- macros
- layouts
- enums
- complex expressions
- host-only path expansion
- register-contract checking as a build prerequisite
- D8/D8M generation as a build prerequisite

This keeps the relationship clean:

```text
profile source
  -> generated AZM-subset assembly
  -> TecMate assembler or host AZM
  -> binary, map, metadata
```

The generated entry file should include user behaviour files rather than
inlining them. That preserves the normal edit/assemble/debug loop: users edit
ordinary `.ASM` files, while the profile tool regenerates tables, resources,
and metadata around them.

If a profile feature cannot lower to the current assembler subset, it should be
taken as a profile-tool limitation, not as pressure to make the first
self-hosted assembler larger.

## Artifact Convention

The self-hosted assembler should use a small, predictable artifact set. It
should not create a general host-style build directory model inside MON3.

For a project with:

```text
main=/src/main.asm
```

the assembler-facing artifacts are:

| Artifact | Default path | TEC-FS type | Purpose |
| --- | --- | --- | --- |
| Source | `/src/main.asm` | `TFS_FILE_SOURCE` | Editable AZM-subset source text. |
| Binary | `/build/main.bin` | `TFS_FILE_BINARY` | Runnable memory image or loadable program output. |
| Symbols/map | `/build/main.map` | `TFS_FILE_ASSET` | Symbol names, addresses, and source references for the shell/debugger. |
| Project record | `/tecm8.prj` or project metadata record | `TFS_FILE_PROJECT` | Main source path and project defaults. |

The derived artifact paths follow the shell contract: take the source stem,
place outputs under `/build`, and use `.bin` and `.map`. A later game tool can
add game-specific products, but it should still start from the same source,
binary, map, and project metadata vocabulary.

The binary metadata should use the TEC-FS metadata record fields directly:

- `TFS_META_OFFSET_FILE_TYPE`: `TFS_FILE_BINARY`
- `TFS_META_OFFSET_LOAD_ADDR`: first byte loaded into RAM or expansion RAM
- `TFS_META_OFFSET_END_ADDR`: exclusive end address
- `TFS_META_OFFSET_RUN_ADDR`: optional run address
- `TFS_META_OFFSET_FLAGS`: `TFS_META_FLAG_EXECUTABLE` when runnable
- `TFS_META_OFFSET_REQUIRED_HW`: TMS9918, GLCD, joystick, or other required hardware bits

The assembler should not parse `/tecm8.prj` independently. The shell owns the
project config import path: read `/tecm8.prj`, resolve `main`, format a blank
`TFM1` record with `TFS_FORMAT_META_RECORD`, then apply project or artifact
fields with `TFS_PATCH_META_RECORD`. The assembler receives the resolved target
descriptor and writes source, binary, and map records through the same metadata
vocabulary.

The map artifact is deliberately simpler than host D8/D8M at first. Phase 1
only needs enough information for `run`, simple debugger lookup, and editor
jump-to-error:

```text
symbol address source-line
```

That can later grow toward AZM/D8M compatibility, but the first requirement is
that TecMate can assemble a source file, write a binary, write enough symbol
information to inspect it, and preserve the TEC-specific load/run metadata.

## Phase 2: Project Usability

Phase 2 should make the assembler useful from the shell:

- include files
- listing output
- source location reporting suitable for editor jump-to-error
- shell command integration
- build products written through TEC-FS
- symbols readable by a debugger or monitor tool
- a stable command contract for `asm`

At this point TecMate should be able to support the ordinary loop:

```text
edit source -> asm -> run -> inspect/debug -> edit source
```

This phase is still about ordinary assembly. It should not depend on a game
runtime, but it should be good enough for game routines.

## Phase 3: Contract-Aware Assembly

Register contracts are an advanced feature, but they fit TecMate well because
the system is moving toward register-first BIOS, shell, VDU, TEC-FS, game, and
debugger APIs.

The contract-aware phase should support AZM-style routine comments for:

- input registers
- output registers
- clobbered registers
- preserved registers
- carry and flag meanings
- service or hook boundary rules

The first self-hosted implementation does not need to prove everything host AZM
can prove. A useful staged target would be:

1. parse and preserve contract comments in listings
2. warn when a documented routine is missing a contract
3. check simple direct calls within one source file
4. check known BIOS/service calls through local interface records
5. report contract failures in a form the editor can navigate

Contract analysis should be conservative. If the checker cannot prove a path,
it should say so clearly rather than silently accepting unsafe code.

## Register-First Convention

TecMate APIs should prefer register arguments over stack arguments unless a
specific routine has a strong reason to do otherwise.

Register-first calls are:

- smaller
- faster
- easier to inspect in Debug80
- easier to teach
- closer to common Z80 practice
- better suited to frame-rate-sensitive game code

The stack remains important for return addresses, saved registers, local
temporary preservation, and special gateway frames such as bank calls. It should
not become the normal argument-passing mechanism for hot TecMate APIs.

## Game Development Implication

Game development should not redefine TecMate, but it is a useful proving case
for the assembler.

Beginner-facing game routines should be written in the self-hosted assembler
subset where possible:

```asm
@Player_Update:
        call API_GetInput
        ret
```

Game hook contracts should eventually be expressible in the same register
contract style as the rest of TecMate:

```asm
;! in IX
;! out
;! clobbers A,B,C,D,E,H,L,zero,sign,parity,halfCarry
@Player_Update:
        ret
```

That keeps game code real Z80 while giving users a structured environment:
editor, assembler, shell, debugger, VDU services, input services, TEC-FS
projects, and optional game runtime APIs.

## Near-Term Consequence

The next TecMate implementation work should continue to build general services,
but prefer decisions that help the self-hosted assembler path:

- stable shell command boundaries
- VDU text output for diagnostics and assembler errors
- TEC-FS project/file records
- register-contract discipline for new banked services
- source/symbol formats that can be consumed by later debugger work
- input services that work for both editor commands and game controls

This keeps TecMate general-purpose while giving it a concrete creative target.
