# MON3-Light Platform Direction

This is the consolidated direction note for the TECM8/MON3 work. TECM8 is the
home for these planning documents. MON3 and Debug80 should stay close to their
own jobs: MON3 as monitor source and Debug80 as emulator/debugger support.

MON3 development should now be treated as part of the TECM8 platform direction,
not as a separate monitor exercise. The MON3 repository remains the source home
for the ROM, but the product decisions belong here because TECM8 defines how
the fixed ROM, banked ROM tools, display services, storage services, and editor
workflow fit together.

The goal is to use the TEC-1G 64K address space as an application-friendly
ROM-and-RAM platform:

```text
0000h-00FFh  restart vectors, interrupt entry, low system hooks
0100h-07FFh  application RAM, except any explicitly documented system use
0800h-0FFFh  current MON3 monitor RAM; target is a documented service-RAM map
1000h-7FFFh  application RAM
8000h-BFFFh  16K bank-switched application/tool ROM window
C000h-FFFFh  fixed 16K MON3/MON3-light ROM
```

The fixed ROM should be a small monitor plus BIOS-style services. Larger tools
should live in the `8000h-BFFFh` banked window and call fixed services at
`C000h-FFFFh`.

## Development Model

TECM8 should be the architecture owner for the whole application platform:

- fixed MON3/MON3-light ROM services
- banked ROM tool framework
- editor, assembler, interpreter, debugger, and shell direction
- display service contract and backend policy
- SD and TEC-FS storage policy
- RAM ownership and service-buffer contracts
- host-side tools that prepare ROM banks, SD images, and TEC-FS images

MON3 should remain buildable and testable on its own, but changes to MON3 should
be evaluated against the TECM8 platform contract. That means every sizeable ROM
decision should answer the same questions:

- is this essential fixed-ROM monitor or BIOS behaviour?
- is it a reusable service needed by banked tools?
- is it a higher-level application or UI feature that belongs in banked ROM?
- does it consume RAM that should be part of the public system map?
- does it make the editor, assembler, BASIC, debugger, display stack, or
  TEC-FS easier to build?

This gives us a practical rule: MON3-light is not just a smaller MON3. It is the
fixed-ROM layer of TECM8.

## Product Shape

The machine should be useful without depending on a hard disk or mass-storage
program loader. Programs should normally be resident in banked ROM:

- editor
- assembler
- Tiny BASIC or another small interpreter
- debugger
- display tools and graphics libraries
- game-development utilities
- optional file and storage tools

The SD card should mainly provide data storage: source files, projects, assets,
saves, exported binaries, and interchange with a host computer. SD should not be
the only practical way to launch core tools.

The user experience should be keyboard-driven and screen-oriented. The screen
target may be a GLCD, a TMS9918-style VDU, or another modest high-resolution
display. The fixed ROM should not bake in one rich display personality when a
small display service can dispatch to different backends.

## Non-Negotiables

These should remain in the fixed `C000h-FFFFh` ROM unless a later measured
design proves a better compatible path.

| Area | Direction |
| --- | --- |
| Monitor identity | Keep MON3 recognisable. |
| Monitor commands | Keep the existing monitor command surface as far as practical. |
| Reset/RST/API entry | Preserve stable monitor and service entry points. |
| Memory examine/edit/GO | Keep as core monitor functionality. |
| Disassembler | Keep. It is useful enough and central enough to monitor personality. |
| Keyboard input | Keep hex keypad and matrix keyboard service paths. |
| Basic displays | Keep character LCD and seven-segment fallback/status services. |
| Serial | Keep compact serial transfer/debug services. |
| System control | Keep shadow/protect/expand/caps/bank state services. |

## Fixed ROM Services

The fixed ROM should expose compact, documented services that banked tools can
call without duplicating hardware code:

- monitor reset and command entry
- keyboard scan, wait-key, and ASCII/key-code translation
- character LCD, seven-segment, and simple status output
- generic display service entry points
- SD init, sector read, sector write, and compact error reporting
- optional TEC-FS file helpers if they remain reliable and compact
- serial byte/string send and receive
- delay, beep, small sound primitives
- byte/word formatting and small utility routines
- bank select and long-call/long-return support

The ROM should not understand editor source records, project layouts, assembler
outputs, game asset formats, or application UI state. Those belong in banked
tools and higher-level libraries.

## Banked Application Framework

The `8000h-BFFFh` window is the normal home for tools and larger libraries.
The first implementation target should assume the default two 16K banks, while
leaving room for the later 16-bank ROM/RAM expansion option.

Required framework pieces:

- a stable bank-select service
- a long-call convention from fixed ROM to banked code
- a long-call convention between banked tools
- a long-return convention that restores the previous bank
- a small jump table or manifest per bank
- documented register preservation rules
- documented service RAM use
- a way for tools to discover fixed-ROM service versions

Banked tools should be allowed to share common service calls, but they should
not rely on private MON3 RAM or private GLCD buffer addresses unless those
addresses are explicitly part of a published compatibility contract.

## RAM Ownership

The current MON3 source treats `0800h` upward as monitor RAM and current GLCD
paths use sizeable low-RAM buffers. That cannot remain vague if the system is
to become application-friendly.

The target is a published RAM map:

- `0000h-00FFh`: vectors and restart hooks
- fixed ROM service RAM: small, explicit, and stable
- display backend RAM: explicit per backend
- SD/storage scratch: explicit and preferably caller-supplied where possible
- application RAM: everything else below `8000h`

Any service that temporarily uses application RAM should document its scratch
range or accept a caller-supplied buffer.

## Display Direction

The fixed ROM should provide display services, not a single hard-wired terminal
personality.

Likely fixed service shape:

- display initialise
- clear display
- set text mode or profile
- set cursor
- write character
- write string
- write hex byte/word
- scroll or newline
- optional bitmap plot/update
- optional draw pixel
- optional draw glyph/sprite

GLCD pixel graphics should remain possible, but the whole MON3 GLCD terminal,
scrollback, banner, and font policy should not automatically be fixed-ROM
requirements. A GLCD backend can live as a compact resident backend, a banked
display library, or both. A TMS9918-style backend should be able to implement
the same higher-level display contract without pretending to be the MON3 GLCD
terminal.

The existing measurements show the current MON3 GLCD package is about 3995
bytes, including a 1024-byte banner and 1544 bytes of font/text constants. That
makes GLCD the largest obvious service-splitting target after the main monitor
core.

## Storage Direction

PATA should not be part of the standard MON3-light ROM.

The current storage code combines PATA, SD, FAT32, load/save workflows, backup
and restore, LCD progress UI, and text messages. The useful fixed-ROM target is
smaller:

- initialise SD
- identify/report card state
- read a 512-byte sector
- write a 512-byte sector
- return compact error codes
- optionally provide TEC-FS file access

TEC-FS is the planned replacement for the current FAT32-compatible MON3 storage
library and the PATA path. It is a TEC-specific filesystem intended to keep SD
card code small and practical. The current direction is a FAT32-formatted SD
card containing multiple contiguous 128 MiB `TECFSxx.IMG` image volumes. Each
image is treated as a TEC-FS drive using 4 KiB allocation blocks. A 4 GiB-class
layout should expose 30 user volumes and reserve one additional image as a
work/safety volume for compaction, repair, upgrades, and copy-then-swap
maintenance. TEC-FS is deliberately not FAT or CP/M compatible internally.

The detailed storage direction is captured in
[TEC-FS Storage Direction](tec-fs-direction.md). In short, TEC-FS should grow
around TEC concepts: long native names, file records with load/run/type/metadata
fields, prefix-based virtual folders over a flat catalogue, TEC-side formatting,
and optional PC tools for transfer and maintenance.

The fixed ROM should still expose the lowest practical SD block services first.
TEC-FS can then sit above those services as the standard MON3-light filesystem.
File browser UI, formatting UI, import/export helpers, and backup/restore tools
can live in banked ROM unless measurement proves they are small enough and
important enough to keep resident.

Craig's SD work and the later `sd_api`/TEC-FS work should be reviewed as the
replacement storage base. The evaluation question is practical: does the code
give a cleaner, smaller, and more reliable sector and file model than the
current PATA/FAT32/SD bundle?

## What Moves Out

The following are candidates for banked ROM, optional modules, or disk-loaded
tools:

| Area | Reason |
| --- | --- |
| PATA | Board-specific legacy storage path. |
| GLCD banner | Asset, not a service. |
| GLCD terminal scrollback | Display personality, not universal BIOS. |
| Rich GLCD drawing library | Useful, but not always fixed-ROM essential. |
| VDU/TMS drivers | Better as display backends behind a common service. |
| File browser and storage UI | Application workflow above SD/TEC-FS services. |
| RAM backup/restore | Useful utility, not fixed-ROM core. |
| RTC setup UI and PRAM viewer | Application workflow above RTC services. |
| Help text, credits, demos | Better as docs, assets, or optional tools. |
| Editor/assembler/BASIC/debugger | Core product tools, but best in banked ROM unless measured otherwise. |

## Work Sequence

1. Keep the current MON3 behaviour stable as the baseline.
2. Publish the current MON3 service inventory and ROM-size evidence from TECM8.
3. Define the fixed-ROM service contract and RAM ownership map.
4. Define bank select, long-call, long-return, and bank manifest conventions.
5. Build an SD-only storage profile: remove PATA, keep reliable sector I/O.
6. Decide whether TEC-FS file helpers stay resident or move to a banked
   storage tool.
7. Remove or relocate the GLCD banner and terminal scrollback.
8. Define the generic display service and first GLCD backend.
9. Add a TMS9918-style or alternate VDU backend behind the same display service.
10. Move editor, assembler, interpreter, debugger, and graphics tools into
    banked ROM images that call fixed services.

## Supporting Documents

- [MON3 Decomposition Plan](decomposition.md): current 16K ROM shape and broad
  reduction strategy.
- [MON3 Core And Auxiliary Services](core-and-auxiliary-services.md): fixed ROM
  versus auxiliary-service classification.
- [TEC-FS Storage Direction](tec-fs-direction.md): native TEC filesystem
  direction, metadata model, virtual folders, and PC utility split.
- [MON3 Service Inventory](service-inventory.md): API call inventory.
- [MON3 Storage Split Report](storage-split.md): PATA/FAT32/SD measurements.
- [MON3 GLCD Split Report](glcd-split.md): GLCD package and RAM measurements.
- [Display Service Extraction Plan](../display-service-extraction.md): current
  GLCD/display service extraction path from the tool side.
- TEC-FS notes currently live in the TEC-1 development material under
  `GPIO/SD_Card/Software/TEC-FS.md`, `SD_Card_API.md`, and
  `SD_Filesystem.md`.
