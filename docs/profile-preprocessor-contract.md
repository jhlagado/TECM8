# TecMate Profile Preprocessor Contract

TecMate profiles are optional project shapers. They sit above the assembler and
generate ordinary AZM-compatible source, tables, labels, includes, resource
data, and metadata. They do not replace the assembler and they do not define the
core programming model for every TecMate project.

The general assembler path must remain valid:

```text
hand-written AZM/Z80 source
  -> AZM or TecMate assembler
  -> binary, map, symbols, metadata
```

A profile adds structure before that same assembler path:

```text
profile source
  -> generated AZM/Z80 source and resources
  -> AZM or TecMate assembler
  -> binary, map, symbols, metadata
```

That means profile-generated programs, monitor code, ROM tools, diagnostics,
utilities, and hand-written applications all share the same final assembly
language boundary.

## Non-Negotiables

- A profile must emit inspectable assembly that can be traced back to the
  profile source.
- A profile must not require a hidden bytecode interpreter for ordinary
  behaviour.
- Behaviour routines should be real Z80 unless a later measured design proves a
  smaller interpreted form is worth the cost.
- Profile output must be callable through the same TecMate BIOS, shell, VDU,
  input, TEC-FS, and debugger contracts used by hand-written programs.
- Generated labels and tables must be stable enough for Debug80 maps and source
  debugging to remain useful.
- Profile metadata must say what was generated: profile type, entry point,
  required display/input profile, storage dependencies, and target bank or load
  address.

## First Profile Shape

The first useful profile is likely game-oriented because games stress the
display, input, timing, resource, and debugging surfaces. That does not make
TecMate a game-only system. The game profile is a proving case for the broader
interactive-program model.

The first profile should be able to describe:

- project name and output artifact
- required display and input profile
- resource files
- actors, rooms, sprites, maps, and other game-specific records
- state record sizes
- routine slots such as `Actor_Init`, `Actor_Update`, `Actor_Touch`, and
  `Room_Enter`
- exported entry point
- TEC-FS metadata for the produced program

The preprocessor should lower those declarations to constants, tables, labels,
resource blobs, and includes. User behaviour should remain in ordinary assembly
files.

## Out Of Scope For The First Version

- a general scripting language
- expression compilation
- automatic dependency graphs between all fields
- object inheritance
- dynamic event dispatch as the default model
- an opaque runtime that hides the generated assembly

Those ideas can be revisited only after the shell, editor, assembler, runner,
VDU/input services, and TEC-FS project storage are useful in their smaller form.
