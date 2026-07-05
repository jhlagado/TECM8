# TecMate ROM Size Budget

TecMate has to be designed like an 1980s system, not like a modern desktop
project. The aim is the smallest viable TecMate system first: enough shell,
editor, assembler, TEC-FS, VDU, and input support to program the machine from
the machine. Everything else has to earn its ROM space.

The current gate is:

```text
npm run rom:size:check
```

That command rebuilds the monitor and expansion ROMs, then checks the generated
D8 segment spans against explicit budgets. Soft budgets produce warnings. Hard
budgets fail the command.

## Current Budget Shape

The fixed monitor is already full:

```text
C000h-FFFFh: 16 KiB fixed monitor ROM
```

The expansion image is nine physical 16K banks, but that is not permission to
fill all 144K casually. The first total hard budget is 64K of high-water span
across the expansion image. That leaves space for growth while making size
growth visible before it becomes structural.

Initial per-bank hard budgets:

| Bank | Role | Hard budget |
| ---: | --- | ---: |
| 0 | Shell, launcher, registry | 4 KiB |
| 1 | VDU/TMS9918 boundary | 8 KiB |
| 2 | TEC-FS boundary and block mapper | 8 KiB |
| 3 | RTC boundary | 2 KiB |
| 4 | GLCD boundary | 2 KiB |
| 5 | TEC-FS monitor-sector bridge | 2 KiB |
| 6 | Input snapshot boundary | 2 KiB |
| 7 | Assembler skeleton | 12 KiB |
| 8 | Run skeleton | 8 KiB |

These budgets are deliberately not final product promises. They are tripwires.
Raising one is allowed, but it should be a conscious design decision with a
commit explaining what capability bought the bytes.

## Feature Tiers

Tier 0 is the fixed service substrate:

- MON3-compatible reset and recovery path
- RST 10h service ABI
- bank switching and far call/far jump support
- expansion discovery and installed service vectors

Tier 1 is the smallest viable self-hosted TecMate system:

- shell entry and short command path
- VDU/TMS9918 text services
- matrix keyboard/input snapshot
- TEC-FS volume, metadata, load/save path
- editor path sufficient to edit source
- assembler subset sufficient to build simple Z80 programs
- runner path sufficient to launch built output

Tier 2 is useful once Tier 1 is real:

- richer editor affordances
- assembler diagnostics and symbol/map output
- debugger integration
- game-oriented helper libraries built on the same VDU/input/TEC-FS services

Tier 3 is deferred unless it becomes essential:

- BASIC
- full debugger UI
- GLCD feature work beyond a compatibility boundary
- high-level game framework features
- optional hardware-specific tooling

## Policies

Bank 0 must not become a junk drawer. It owns discovery, registry, shell
handoff, and supervision. Tool bodies belong in their own banks.

Do not duplicate shared logic across banks. Banked tools should use the VDU,
input, TEC-FS, and monitor ABI instead of carrying private copies.

Large features should land behind a small ABI first. A stub that proves the call
shape is good; a large body of unproven code is not.

Any feature that grows a bank by roughly 512 bytes or more should include a size
note in the commit message, documentation, or review summary.

If a bank crosses its soft budget, review whether the feature is Tier 1. If it
is not Tier 1, move it later or move it out.

If a bank crosses its hard budget, either reduce the implementation or update
this document and the checker with a clear reason.
