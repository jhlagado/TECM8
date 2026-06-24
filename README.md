# TECM8

TECM8 is a self-contained development environment for the TEC-1G: a small
Z80 machine with a matrix keyboard, GLCD, and FAT32-backed storage through MON3.

The target source language is Z80 Assembly. The first product target borrows the
useful parts of early Turbo Pascal: a project has a main source file, the
environment can open named source files directly, and common work uses short
commands like `edit`, `asm`, and `run` rather than long command lines.
`.Z80` source remains a compatibility path for imported ASM80-era projects, but
TECM8 examples and tools should prefer `.ASM`.
The intended assembly dialect is an AZM-like cleaned-up ASM80 baseline: the
useful core of ASM80 without every historical compatibility wildcard.

The advanced goal is a source-aware debugger with object loading, source maps,
breakpoints, stepping, register display, and source context. That is deliberately
separate from the first edit/assemble/run baseline.

Project storage is built around a portable `VOLUME.TM8` workspace file. Current
host tools create, inspect, import, export, copy, unpack, and pack files across
these volumes so projects can move cleanly between a laptop and the TEC-1G.
Separate `fs import-text` and `fs export-text` commands convert source text to
and from TECM8's fixed 32-byte editor records.
The root `/tecm8.prj` file stores the project main file as simple ASCII
`key=value` metadata for the future TEC-side shell.

Start with the documentation:

- [Live Roadmap](docs/roadmap.md)
- [Codebase Tour](docs/codebase.md)
- [Virtual Filesystem](docs/virtual-filesystem.md)
- [TEC-Side Shell Command Contract](docs/shell-command-contract.md)
- [TECM8 AZM Style Guide](docs/azm-style-guide.md)
- [Editor Design](docs/editor-design.md)
- [Memory and Code Quality Manifest](docs/memory-and-code-quality.md)
- [TECM8 BIOS API Draft](docs/tecm8-bios-api.md)

MON3 analysis and ROM-reduction notes live under [docs/mon3](docs/mon3/).

## Debug80 Development Modes

TECM8 currently has two Debug80 workflows.

The RAM-loaded workflow remains the fast proof and live-editor path. Debug80
assembles `src/main.asm` into `build/main.bin`, loads it at `0x4000`, and runs
it with MON-3 providing storage, keyboard, and display services.

The ROM-development workflow keeps MON-3 as the active fixed monitor ROM for now
and adds project-owned TECM8 ROM source under `roms/tec1g/tecm8/`. Build the
project ROM artifacts manually with:

```text
npm run rom:check
```

Debug80 also declares the expansion ROM as an active source-backed
`tec1g.romArtifacts` entry, so launch builds
`build/roms/tec1g/tecm8/expansion/expansion.bin` and loads it through
`tec1g.expansionRomHex`. The image is available through the TEC-1G banked
expansion window at `0x8000-0xBFFF`. The monitor source is present as an
inactive artifact for development, but `tec1g.romHex` continues to point at
MON-3 until the TECM8 monitor can boot.

Useful local checks:

```text
npm install
npm run check
```

Manual Debug80 diagnostics:

```text
npm run debug80:editor-image
npm run debug80:keyboard-tester
```

The keyboard tester assembles `src/keyboard-tester.main.asm` into
`build/keyboard-tester.bin`. Load it at `0x4000` from MON3 to inspect matrix
keyboard events independently of the editor.
