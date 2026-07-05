# TEC-Side Shell Command Contract

This contract defines how the future TECM8 shell reads project metadata and
turns short commands such as `edit`, `asm`, and `run` into concrete file
operations. The project file is deliberately small: it records only the state
that is not obvious from convention.

## Active Volume And Project Config

The shell operates on one active TM8 volume at a time. A project volume is
configured when it contains:

```text
/tecm8.prj
```

`/tecm8.prj` is an ordinary root file in the TM8 volume, similar in role to
`package.json`, `Makefile`, or `debug80.json` on a host system. Its content is
ASCII `key=value` text. Lines end with LF. A final LF is expected, but the
TEC-side reader should accept a final non-empty line without one. Blank lines
are only valid as the final LF terminator.

The default config created by the host tool is:

```text
tm8project=1
main=/src/main.asm
```

Required keys:

```text
tm8project
main
```

`tm8project` must be `1`. The shell should reject duplicate keys, missing
required keys, empty values for required keys, malformed lines without `=`, and
paths that fail the TM8 virtual filesystem path rules.

Unknown keys are rejected. A future format can add a new version marker rather
than making shell v1 carry preservation logic for fields it does not use.

## Project Metadata Import Path

`/tecm8.prj` remains the human-readable project authority in shell v1. The
TEC-FS metadata record is the machine-facing summary derived from it, not a
second source of truth.

The import path is:

1. Read and validate `/tecm8.prj`.
2. Resolve `main` as the project main source path.
3. Call `TFS_FORMAT_META_RECORD` to create a blank `TFM1` record.
4. Call `TFS_PATCH_META_RECORD` with `TFS_FILE_PROJECT`, zero flags, zero
   load/end/run addresses, zero required hardware, and a name/path reference
   for `/tecm8.prj` when the catalogue can supply one.

The shell may cache the resulting project metadata record in RAM, but cache
contents are disposable. On restart or remount, `/tecm8.prj` is read again and
the metadata record is rebuilt. This keeps the v1 rules simple: text config is
authoritative, `TFM1` records are the compact ABI used by shell tools.

## Derived Project Paths

The main source file is the durable project entry point. Output and map paths
are derived from the main source filename instead of being stored.

Derivation rules:

1. Take the local filename from `main`.
2. Remove the final extension, if present.
3. Use that stem under `/build`.
4. Append `.bin` for the runnable output and `.map` for the map/debug sidecar.

Examples:

```text
main=/src/main.asm       -> output=/build/main.bin, map=/build/main.map
main=/src/demo.asm       -> output=/build/demo.bin, map=/build/demo.map
main=/src/monitor.asm    -> output=/build/monitor.bin, map=/build/monitor.map
```

This is intentionally less flexible than a general build system. If a project
needs a different mainline name, it changes `main`; the rest follows by
convention.

## Path And Name Defaults

Stored paths are absolute TM8 paths. They use the same filename policy as the
volume catalog: lowercase letters, numbers, underscore, and hyphen in path
segments, with an extension separated by `.`.

When a user types a source filename without an extension, shell source commands
append `.asm`.

Relative command arguments are resolved against the shell current prefix, the
same state changed by `cd` and reported by `pwd`. They are not resolved against
the main file's prefix unless the shell current prefix happens to be there.

Examples when the shell current prefix is `/src`:

```text
edit main       -> /src/main.asm
edit draw       -> /src/draw.asm
edit /lib/draw  -> /lib/draw.asm
```

If the user supplies an extension, the shell preserves it. `.ASM` is the
preferred user-facing extension in prose, but stored TM8 paths are lowercase,
so the default physical path is `.asm`. `.z80` remains a compatibility path for
imported ASM80-era projects.

## Short Commands

The short command bindings are fixed in shell v1:

```text
edit -> main
asm  -> main
run  -> derived output
```

They are not stored in `/tecm8.prj`. This keeps the Z80 parser and project
state small. Future configuration screens can still change `main`, but the
command names themselves remain part of the shell.

## Reserved Tool Namespaces

The shell should reserve multi-word command namespaces for larger tool profiles
without adding them to the v1 short-command parser yet.

Reserved game-development commands:

```text
game build
game run
game debug
```

These commands are placeholders for the later game runtime/tool profile. They
should not replace the general `edit`, `asm`, and `run` commands. Instead, they
should layer on the same project, assembler, runner, VDU, input, TEC-FS, and
debugger services once those services exist.

The current bank-0 `SHL_RUN_COMMAND` boundary still classifies only exact
single-word `edit`, `asm`, and `run`. It should reject `game` until a real
multi-word shell parser and game tool dispatcher are implemented.

## Command Resolution

Shell commands are resolved in this order:

1. Parse `/tecm8.prj`.
2. Resolve any user argument to an absolute TM8 path.
3. If no argument is present, use the command's project default.
4. Execute the tool against that resolved path.

For the default config, no-argument commands resolve to:

```text
edit -> main   -> /src/main.asm
asm  -> main   -> /src/main.asm
run  -> output -> /build/main.bin
```

The map path is not directly targeted by a short command in shell v1. `asm`
uses the derived map path as the default map/debug sidecar output when the
assembler reaches that phase.

## `edit`

`edit` opens one source file and returns to the shell when the editor exits.

No argument:

```text
edit
```

The shell opens the file named by `main`.

With a file argument:

```text
edit draw
edit /src/draw.asm
```

The shell resolves the argument to a TM8 path, appending `.asm` when no
extension is present, and opens that file. If the file does not exist, the
editor may create it after an explicit save; the shell should not need a
separate `new` command for ordinary source editing. Editing a named file does
not change `main`.

## `asm`

`asm` assembles the project mainline by default.

No argument:

```text
asm
```

The shell assembles the file named by `main`.

With a file argument:

```text
asm test
asm /src/test.asm
```

The shell assembles that one-off target and does not change `main`. One-off
assembly derives output and map names from the argument stem, not from the
project main stem, so `asm test` writes `/build/test.bin` and `/build/test.map`.
The preferred everyday workflow remains no-argument `asm`, because the project
main file is the durable build entry point.

Assembler defaults:

```text
source -> resolved command target
output -> derived /build/<source-stem>.bin
map    -> derived /build/<source-stem>.map
```

If assembly succeeds, `run` continues to use the derived project output.

Assembler result reporting uses the shell command parameter block:

```text
SHL_PARAM_COMMAND_ACTION    = SHL_ACTION_ASM
SHL_PARAM_COMMAND_TARGET_*  = pointer to source/artifact target descriptor
SHL_PARAM_COMMAND_RESULT_LO = SHL_RESULT_*
SHL_PARAM_COMMAND_RESULT_HI = command-specific detail
```

The expected v1 result meanings are:

```text
SHL_RESULT_OK          assembly completed and wrote .bin/.map outputs
SHL_RESULT_BUILD_ERROR source parsed but did not assemble; detail may be line
SHL_RESULT_FILE_ERROR  source, output, map, or project file could not be used
SHL_RESULT_UNSUPPORTED asm was classified but the assembler tool is not linked
```

Until project parsing and the assembler are linked behind the shell,
`SHL_RUN_COMMAND` classifies `asm`, points the target slot at the minimal
`SHL_TARGET_DESC`, marks that descriptor as the project-main default, calls the
bank-7 assembler skeleton, and publishes the skeleton's
`SHL_RESULT_UNSUPPORTED` result.

## `run`

`run` executes the derived project output by default.

No argument:

```text
run
```

The shell runs `/build/<main-stem>.bin`, derived from `main`.

With a file argument:

```text
run /build/test.bin
```

The shell runs that one-off target and does not change project config. The
no-argument form remains the primary workflow.

Until project parsing and a real launcher/debugger are linked behind the shell,
`SHL_RUN_COMMAND` classifies `run`, points the target slot at the minimal
`SHL_TARGET_DESC`, marks that descriptor as the derived project output default,
calls the bank-8 run skeleton, and publishes the skeleton's
`SHL_RESULT_UNSUPPORTED` result.

## Errors

The shell should report short, actionable errors and return to the prompt:

```text
no project config
bad project config
missing main
bad path
file not found
assemble failed
run failed
```

Config parse errors should not launch tools. A malformed `/tecm8.prj`
means the shell cannot know which file is authoritative.

## Persistence Rules

Shell v1 writes `/tecm8.prj` only when project state changes:

- A future project configuration screen may update `main`.
- `edit`, `asm`, and `run` do not change config merely because they ran.

When rewriting the config, the shell should keep the file ASCII, keep required
keys present, reject unknown keys, and write a final LF.

## Host Tool Relationship

The host `fs project-*` commands are the current reference writer and validator
for this file:

```text
fs project-init VOLUME.TM8 [/src/main.asm]
fs project-info VOLUME.TM8
fs project-set-main VOLUME.TM8 /path/file
```

The TEC-side shell should match the same stored format rather than inventing a
separate runtime-only project state.
