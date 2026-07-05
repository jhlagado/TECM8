# TecMate Profile TEC-FS Packaging

Profile projects should use TEC-FS as the machine-facing package format. A
profile can generate source, tables, resources, metadata, and runnable output,
but those products should still look like ordinary TEC-FS files to the shell,
assembler, runner, and debugger.

The rule is simple: profile tooling may add structure, but it must not create a
parallel storage system.

## Project Authority

The human-readable project authority remains:

```text
/tecm8.prj
```

Shell v1 only accepts `tm8project` and `main`. A later profile-aware project
format can add a profile source key, but it must do so with an explicit project
format/version bump rather than silently adding an unknown key to shell v1
config:

```text
tm8project=2
main=/src/main.asm
profile=/profile/game.tm8p
```

The profile source describes project structure. The generated TEC-FS metadata
records are compact machine-facing summaries derived from that source; they are
not a second source of truth.

## Suggested File Layout

The first profile-aware project layout should stay conventional:

```text
/tecm8.prj
/profile/game.tm8p
/src/main.asm
/src/player.asm
/assets/player.spr
/assets/room0.map
/generated/profile.generated.asm
/generated/profile.tables.asm
/generated/profile.resources.asm
/generated/profile.metadata.asm
/build/main.bin
/build/main.map
/build/main.pkg
```

The generated paths mirror the host-side profile contract but remain ordinary
TEC-FS paths. A tiny TEC-side workflow may choose to regenerate fewer files, but
the conceptual roles should remain the same.

## File Types

Profile packaging should reuse the existing TEC-FS metadata vocabulary before
inventing new file types.

| Product | Path example | TEC-FS role |
| --- | --- | --- |
| Project config | `/tecm8.prj` | `TFS_FILE_PROJECT` |
| Profile source | `/profile/game.tm8p` | `TFS_FILE_SOURCE` or later `TFS_FILE_PROFILE` |
| User assembly | `/src/player.asm` | `TFS_FILE_SOURCE` |
| Generated assembly | `/generated/profile.tables.asm` | `TFS_FILE_SOURCE` |
| Raw asset | `/assets/player.spr` | `TFS_FILE_ASSET` |
| Binary output | `/build/main.bin` | `TFS_FILE_BINARY` |
| Symbol/map output | `/build/main.map` | `TFS_FILE_ASSET` |
| Package manifest | `/build/main.pkg` | `TFS_FILE_GAME` |

New TEC-FS file types should be added only when the existing type plus metadata
is not enough. In particular, package manifests should use the existing
`TFS_FILE_GAME` game/application package role before inventing a new package
type.

## Runtime Package Record

`/build/main.pkg` is the profile runtime summary. It should be small enough for
the shell and runner to inspect without parsing the whole profile source.

It should record:

- package format version
- profile kind, such as game or card
- runnable binary path
- map/debug path
- exported entry point
- load address, end address, and run address
- target bank or RAM range
- required display profile
- required input profile
- required storage profile
- resource table path or offset
- profile source path

The package record is derived output. If it disagrees with `/tecm8.prj` or the
profile source, the source files win and the package should be rebuilt.

## Resource Packaging

Resources should be packaged in two layers:

1. Source resources under `/assets`, easy to replace or inspect.
2. Generated resource tables under `/generated` or packed runtime data under
   `/build`.

The first implementation should prefer simple fixed records:

```text
resource id
resource type
TEC-FS path or packed offset
byte length
load/use address where relevant
flags
```

Packed resources should retain enough metadata for the debugger or shell to
explain what they are. A packed sprite blob should still be traceable back to
`/assets/player.spr`.

## Runner Contract

The shell should not need to understand every profile. It should be able to:

1. Read `/tecm8.prj`.
2. Find the runnable output or package record.
3. Validate required hardware/profile flags.
4. Load the binary or select the target bank.
5. Jump to the exported entry point.

Profile-specific setup beyond that belongs to the profile runtime or generated
startup code, not to the core shell.

## Space Policy

Profile packaging must publish sizes:

- generated assembly bytes
- user behaviour code bytes where known
- resource bytes
- runtime/package overhead bytes
- final binary size

This keeps profile work aligned with the small-system rule: ambitious tooling is
allowed, but growth must be visible.
