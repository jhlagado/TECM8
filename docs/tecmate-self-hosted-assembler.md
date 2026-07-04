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
Player_Update:
        call API_GetInput
        ret
```

Game hook contracts should eventually be expressible in the same register
contract style as the rest of TecMate:

```asm
;! in IX
;! out
;! clobbers AF,BC,DE,HL
Player_Update:
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
