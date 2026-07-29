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

## Implemented ROM Subset

Bank 7 now contains the first useful two-pass implementation. It reads the
resident bank-4 editor workspace as 32-byte source records and accepts:

- global labels up to eight characters, with forward and backward references
- constants declared as either `NAME .EQU expression` or
  `NAME: .EQU expression`; a constant must resolve in pass one
- 16-bit decimal and `0x` hexadecimal integers
- simple left-to-right `+` and `-` expressions, unary `+` and `-`,
  parentheses, symbols, constants, and `$` for the current program counter
- comments, `.org`, `.db`, and `.dw`
- `.include "path"` with an absolute TEC-FS path or a path relative to the
  main source directory
- `NOP`, `HALT`, `DI`, `EI`, `SCF`, `CCF`, and `CPL`
- unconditional and conditional `RET`, `JP`, and `CALL`
- unconditional `JR`, `JR NZ/Z/NC/C`, and `DJNZ`
- `LD r,r`, `LD r,n`, `LD r,(HL)`, `LD (HL),r`, `LD (HL),n`,
  `LD A,(nn)`, `LD (nn),A`, and 16-bit immediate loads into `HL`, `DE`,
  `BC`, or `SP`
- register, `(HL)`, and eight-bit immediate forms of `XOR`, `AND`, `OR`,
  `SUB`, and `CP`
- `ADD A`, `ADC A`, and `SBC A` with a register, `(HL)`, or eight-bit
  immediate operand
- `INC` and `DEC` for every eight-bit register and `(HL)`
- `PUSH` and `POP` for `BC`, `DE`, `HL`, or `AF`
- `OUT (n),A` and `IN A,(n)`

The implementation is case-insensitive, supports at most 16 symbols, and emits
at most 512 bytes. The origin and every emitted byte must remain in the runner's
`4000h-4FFFh` window. A build may process at most four one-level includes per
pass; each included source is bounded to the editor's 48-record/1536-byte
workspace, and an included file may not include another file. Multiplication,
division, bitwise expression operators, forward references between constants,
macros, indexed instructions, the complete Z80 instruction set, recursive
module graphs, and contract analysis remain later work. Those omissions
distinguish the implemented ROM subset from the broader direction below.

On an error, bank 7 publishes a zero-based source record, column, diagnostic
code, and source-file ordinal (`0` for the main file, `1..4` for includes).
Reopening `edit` after a failed main-file build positions the editor on that
record and column. On success, bank 7 derives `/build/<stem>.bin` and
`/build/<stem>.map` from the main source path and writes both through bank 2's
installed TEC-FS sector-driver boundary.

The binary is accompanied by a fixed-record `TMAP` artifact. Its eight-byte
header is `TMAP`, version `1`, record size `12`, symbol count, and one reserved
byte. Each symbol record contains an eight-byte zero-padded name, a little-endian
value, a zero-based source line, and a kind/source byte. Its low nibble is `1`
for an address label or `2` for a constant; its high nibble is the source-file
ordinal. This preserves the original main-file values `01h` and `02h` while
making included symbols source-aware.

Bank 8 loads and validates the executable metadata and binary through bank 2.
It rejects ranges outside `4000h-4FFFh` or an entry point outside the artifact,
then calls the entry through a RAM trampoline. A phase-one program must finish
with `RET`; control then returns through bank 8 and the bank-call gateway to the
shell. This is a bounded loader, not a sandbox, timeout mechanism, or relocating
linker.

## Phase 1: Core Subset

The complete Phase 1 direction should assemble normal source files without
clever language features.

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

## MVP Readiness Gates

The readiness path is now implemented:

```text
editor opens 32-byte-record source buffer
  -> assembler reads that buffer or a TEC-FS source stream
  -> assembler emits binary and map records through TEC-FS
  -> shell `asm` reports `OK`, `BUILD`, or `FILE`
```

The first useful assembler was gated by the editor file-buffer ABI and TEC-FS
source/binary/map writes. Those dependencies now exist and the monitor-launch
proof exercises them as one edit, diagnose, fix, rebuild, run, and return loop.

The next readiness layer is also implemented: the resident main buffer can name
bounded TEC-FS includes, and the resulting binary and map are real catalogue
files. The SD-backed proof loads `/project/build.asm`, resolves
`/project/lib.asm`, creates `/build/build.bin` and `/build/build.map`, reloads
the binary, executes it, and returns. The `/build` prefix must already exist;
new-prefix allocation remains outside the bounded create service.

Source input remains intentionally bounded rather than a general project graph:
one resident main buffer plus up to four non-recursive include streams. Listings,
register-contract checking, recursive modules, and profile-generated source are
still later layers.

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

The self-hosted assembler uses a small, predictable artifact set rather than a
general host-style build model inside MON3.

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

On the real MON3 file driver, the catalogue file contains the raw exported
payload starting at sector zero of its 4K allocation block. A private `TFM1`
sidecar occupies sector seven. Save order is payload, sidecar, then catalogue
size/type publication, so host export of `.bin` and `.map` stays byte-exact
without exposing an incomplete catalogue entry.

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

The map artifact is deliberately simpler than host D8/D8M. The current ROM
implementation uses the fixed `TMAP` header and records described above. Phase 1
only needs enough information for `run`, simple debugger lookup, and editor
jump-to-error:

```text
symbol address source-line
```

That can later grow toward AZM/D8M compatibility, but the first requirement is
that TecMate can assemble a source file, write a binary, write enough symbol
information to inspect it, and preserve the TEC-specific load/run metadata.

## Phase 2: Project Usability

Phase 2 is now partly implemented. Include files, stable shell integration,
catalogue build products, cross-file source ordinals, and debugger-readable
symbols exist. The remaining user-facing work is:

- listing output
- included-file editor jump-to-error
- shell-visible symbol inspection
- source-aware breakpoint, step, and continue controls

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
.routine in IX clobbers A,B,C,D,E,H,L,zero,sign,parity,halfCarry
Player_Update:
        ret
```

That keeps game code real Z80 while giving users a structured environment:
editor, assembler, shell, debugger, VDU services, input services, TEC-FS
projects, and optional game runtime APIs.

## Near-Term Consequence

Further TecMate work should continue to build general services, while extending
the self-hosted toolchain deliberately:

- stable shell command boundaries
- VDU text output for diagnostics and assembler errors
- TEC-FS project/file records
- register-contract discipline for new banked services
- source/symbol formats that can be consumed by later debugger work
- input services that work for both editor commands and game controls

This keeps TecMate general-purpose while giving it a concrete creative target.
