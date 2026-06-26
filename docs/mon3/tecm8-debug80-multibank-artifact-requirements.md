# TECM8 Debug80 Multibank Artifact Requirements

This note is the TECM8-side handoff for Debug80 support of source-backed
multibank TEC-1G expansion ROM artifacts. It builds on Debug80's current
TEC-1G expansion decode model in:

```text
/Users/johnhardy/projects/debug80/docs/tec1g-expansion-memory-handoff.md
```

The goal is not to assign final bank roles yet. The goal is to make it possible
to build, load, step, and debug multiple 16K expansion banks that all appear at
the same CPU address window.

## Hardware Model Assumed By TECM8

The visible expansion window is:

```text
8000h-BFFFh
```

`SYS_CTRL` bit 2 enables the expansion window. `SYS_CTRL` bits 3-6 hold the
memory expansion field. Debug80 decodes that field as:

```text
upper selector = bits 4-6
legacy page    = bit 3
```

If the upper selector is zero, bit 3 selects the legacy physical bank:

```text
bit 3 clear -> physical bank 0
bit 3 set   -> physical bank 1
```

If the upper selector is `1-7`, it selects physical banks `2-8`. In that
extended mode, bit 3 is still latched and visible in debug state, but it does
not select a different physical extended bank.

Debug80's current decode model gives TECM8:

```text
2 legacy 16K expand pages
+ 7 additional decoded 16K windows
= 9 physical 16K banks
= 144K maximum expansion image
```

TECM8 should treat those as physical banks `0-8`. It should not infer EPROM,
RAM, cartridge, shadow, or write-protection roles from raw bank number or binary
position. Those roles need explicit metadata later.

## Source Input Model

TECM8 wants to move from a single expansion source file to explicit per-bank
sources. This document uses the live repository path family
`roms/tec1g/tecm8/expansion/`; it supersedes older planning examples that used
`roms/tec1g/tecm8-expansion/` as a separate top-level expansion path.

```text
roms/tec1g/tecm8/expansion/bank0.asm
roms/tec1g/tecm8/expansion/bank1.asm
roms/tec1g/tecm8/expansion/bank2.asm
...
roms/tec1g/tecm8/expansion/bank8.asm
```

Each source file is assembled independently for the visible window:

```asm
        .org 8000h
```

Each bank must fit inside:

```text
8000h-BFFFh
```

Two different banks may legally define code and labels at the same CPU address.
For example, `bank0.asm` and `bank1.asm` may both emit an entry point at
`8000h`. They are different code because the active physical expansion bank is
different.

## Combined Binary Output

The combined expansion image is a physical backing image:

```text
size:      144K = 0x24000 = 147456 bytes
bank size: 16K  = 0x4000
bank count: 9
```

Packing rule:

```text
physical bank 0 -> image offset 00000h-03FFFh
physical bank 1 -> image offset 04000h-07FFFh
physical bank 2 -> image offset 08000h-0BFFFh
physical bank 3 -> image offset 0C000h-0FFFFh
physical bank 4 -> image offset 10000h-13FFFh
physical bank 5 -> image offset 14000h-17FFFh
physical bank 6 -> image offset 18000h-1BFFFh
physical bank 7 -> image offset 1C000h-1FFFFh
physical bank 8 -> image offset 20000h-23FFFh
```

If a bank source emits fewer than 16K bytes, its physical bank slot is padded.
The padding value can be a tool decision, but it should be deterministic.

## Artifact Expectations

At minimum, TECM8 can pack the 144K binary itself and hand Debug80 the final
image. That is enough to run code, but not enough for good source debugging.

The preferred Debug80 workflow is bank-aware source-backed artifacts:

```text
build/roms/tec1g/tecm8/expansion/bank0.bin
build/roms/tec1g/tecm8/expansion/bank0.d8.json
build/roms/tec1g/tecm8/expansion/bank1.bin
build/roms/tec1g/tecm8/expansion/bank1.d8.json
...
build/roms/tec1g/tecm8/expansion/bank8.bin
build/roms/tec1g/tecm8/expansion/bank8.d8.json

build/roms/tec1g/tecm8/expansion/expansion-144k.bin
build/roms/tec1g/tecm8/expansion/expansion-144k.debug.json
```

The combined debug metadata must preserve bank identity. Address alone is not
enough to resolve a symbol or source line.

The bank-to-map association should be explicit. The exact schema is a Debug80
choice, but it needs to carry this information for each physical bank:

```json
{
  "physicalBank": 0,
  "imageOffset": 0,
  "windowAddress": 32768,
  "windowSize": 16384,
  "sourceRoot": "<project-root>",
  "sourceFile": "roms/tec1g/tecm8/expansion/bank0.asm",
  "debugMap": "build/roms/tec1g/tecm8/expansion/bank0.d8.json"
}
```

The same structure repeats for banks `1-8`, with `imageOffset` equal to
`physicalBank * 0x4000`. An equivalent representation is fine, but Debug80
needs enough data to avoid flattening all bank maps into one address-only map.
Source paths should either be project-root-relative with an explicit
`sourceRoot`, or use another Debug80-supported convention that resolves
unambiguously from the project root.

## Debug Metadata Requirement

Debug80 should resolve expansion-window debug information by:

```text
(memory space, physical bank, CPU address)
```

not by:

```text
CPU address only
```

For `8000h-BFFFh`, `memory space` must distinguish at least:

```text
base memory visible, EXPAND clear
expansion memory visible, EXPAND set
```

When `EXPAND` is clear, Debug80 should not resolve `8000h-BFFFh` through an
expansion-bank source map or fire expansion-bank breakpoints. When `EXPAND` is
set, Debug80 should use `memoryExpansionPhysicalBank` plus the CPU address.

Required behavior:

- show the current physical expansion bank in debug state
- show whether the expansion window is active
- resolve source for `8000h-BFFFh` using the active physical bank
- allow symbols at the same CPU address in different banks
- allow breakpoints scoped by memory space, physical bank, and CPU address
- keep stepping coherent when `SYS_CTRL` changes the active bank

Minimum useful state already described by Debug80:

```text
memoryExpansionBankBits
memoryExpansionBankValue
memoryExpansionMode
memoryExpansionLegacyBank
memoryExpansionExtendedWindow
memoryExpansionPhysicalBank
```

TECM8 will use `memoryExpansionPhysicalBank` as the real debug identity for the
visible expansion window.

## Runtime ABI Implication

TECM8 fixed-ROM services should own expansion switching. Banked code should not
normally write `SYS_CTRL` directly.

For target selection, TECM8 can represent the expansion field as a compact
5-bit value:

```text
bit 0     EXPAND
bits 1-4  SYS_CTRL bits 3-6 before shifting into position
```

The fixed ROM applies that compact value by shifting it into `SYS_CTRL` bits
`2-6`, preserving the non-expansion bits:

```text
preserve: SHADOW, PROTECT, CAPSLOCK
modify:   EXPAND and bits 3-6
```

For far-call return, TECM8 should restore the full previous execution context:

```text
full SYS_CTRL snapshot + PC
```

This matters because a caller in fixed ROM, RAM, or a banked expansion page all
have the same true return state: the control register state and the program
counter. The caller does not need to be described as "banked" or "not banked".

## Minimum Debug80 Support Needed Next

Debug80 already accepts a 144K image and exposes the decoded physical bank in
the handoff model. The next useful Debug80/TECM8 integration target is:

1. Associate each physical bank with its own source map.
2. Resolve expansion source and symbols by `(memory space, physical bank, address)`.
3. Allow breakpoints to be scoped by `(memory space, physical bank, address)`.
4. Keep source display correct when `SYS_CTRL` changes while stepping.
5. Support a project configuration shape for per-bank source-backed artifacts, or
   document that TECM8 must pack banks and provide the bank-to-map association.

If Debug80 cannot yet build all banks itself, TECM8 can initially provide the
packed `expansion-144k.bin`. The important requirement is that Debug80 has a way
to associate each 16K slot with the correct debug map.

## Future Explicit Metadata

Do not infer these roles from the raw binary layout yet:

```text
EPROM programmer bank
cartridge bank
RAM bank
shadowed RAM/ROM overlay
read-only or writeable bank
```

Those need explicit bank metadata once the hardware and Debug80 behavior are
ready to model them.
