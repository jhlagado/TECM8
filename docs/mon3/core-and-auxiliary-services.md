# MON3 Core And Auxiliary Services

This note is derived from the MON3 decomposition and split reports. It focuses
only on what MON3 currently contains, what should remain resident in the fixed
ROM, and what could become an auxiliary service, extension ROM component, disk
tool, or optional library.

The central question is simple: the fixed ROM should contain the monitor
identity and useful BIOS-style services. It should not carry large bundled
features merely because they were historically convenient to place there.

## Current MON3 Shape

The Debug80 TEC-1G MON3 bundle models MON3 BC25/v1.6 as a 16 KiB ROM image.
The current rough ROM layout is:

```text
C000-D7FF  main MON3 monitor code/data       about 6.0K
D800-E79A  GLCD library/font/banner          about 3.9K
E79B-EF6A  disassembler                      about 2.0K
EF6B-F021  sound                             about 0.2K
F022-FA77  PATA/FAT32/SD storage             about 2.6K
FA78-FFEB  RTC                               about 1.4K
FFEC-FFFF  release metadata                  tiny
```

These are approximate ranges, but they explain why the ROM feels full. The
space is mainly consumed by the monitor core, GLCD support, disassembler,
storage, and RTC code. The current ROM does not include Tiny BASIC, a general
video service layer, or a large character ROM beyond the GLCD/font and display
data already present.

## Proposed ROM Rule

The fixed MON3 ROM should contain:

- enough monitor functionality to remain recognisably MON3
- stable entry points for hardware and utility services
- small services that are repeatedly useful to higher-level programs
- recovery paths that still work when no extension ROM or disk tool is present

The fixed MON3 ROM should not contain:

- large one-off UI workflows
- bundled demos, novelty assets, and large help text
- storage user interfaces that sit above the block or file service layer
- display terminal personalities that could live as selectable drivers
- board-specific legacy paths that are not part of the target system

This does not mean deleting useful capability. It means moving non-essential
capability behind a service boundary where it can live in an extension ROM,
library ROM, or disk-loaded program.

## Essential Resident Services

These are the services that look most suitable for the fixed ROM.

| Area | Resident role |
| --- | --- |
| Reset, RST stubs, NMI/INT entry | Compatibility and recovery anchor. |
| Monitor identity | Software/version ID, reset flow, basic state display. |
| Memory monitor | Examine/edit memory, GO, simple range operations, error display. |
| System latch state | Shadow, protect, expand, caps, and related state calls. |
| Keyboard/input | Hex keypad scan, matrix scan, ASCII/key-code parse, wait-key helpers. |
| Character LCD and seven-segment | Boot diagnostics, fallback display, simple status output. |
| Serial | Enable/disable, transmit byte/string, receive byte/range. |
| Timing and sound | Delay, beep, note/tune primitives if kept compact. |
| Formatting utilities | Byte/word to ASCII, segment conversion, string compare, small random. |
| Storage base layer | SD init, card status, sector read, sector write, compact errors. |
| File access layer | Open/read/write file sectors if it remains compact and reliable. |
| Display service vector | Generic text/video calls that can target VDU, GLCD, or fallback LCD. |

The key principle is that these services should be callable by higher-level
applications without requiring those applications to duplicate hardware code.

## Storage And SD

The current storage module spans about 2646 bytes. The split report classifies
it roughly as:

| Category | Bytes | Disposition |
| --- | ---: | --- |
| PATA-specific hardware path | 167 | Remove from the standard ROM. |
| Shared block-device/error glue | 169 | Keep, but simplify around SD. |
| FAT32/file-sector core | 867 | Move to compatibility/banked tooling; replace the fixed-ROM candidate with TEC-FS if measured smaller and reliable. |
| Storage UI/load-save workflows | 853 | Move out of fixed ROM. |
| SD/SPI hardware path | 367 | Keep and harden. |
| Storage messages | 223 | Replace with compact error codes or move text out. |

The important finding is that the PATA-only code is not the whole storage cost.
PATA should still go from the standard ROM because it is the wrong default
target, and the FAT32-compatible path should not be treated as the fixed-ROM
default. FAT32 can remain useful as compatibility tooling, but the resident
storage candidate is compact SD sector I/O plus, if measured worthwhile, a
small TEC-FS layer. The larger saving comes from removing storage UI, RAM
backup/restore, Intel HEX storage workflows, and long human-facing messages.

The fixed ROM should expose a clean SD service boundary:

- initialise SD
- report card/media state
- read a 512-byte sector
- write a 512-byte sector
- return compact error codes
- optionally mount/open TEC-FS files and read/write file-relative sectors

The file-system choice can then be made above that boundary. TEC-FS is the
planned replacement for the current FAT32-compatible MON3 storage code and the
PATA path. It trades host FAT compatibility for a much simpler TEC-specific
layout: fixed file slots, compact FCBs, memory-block save/load semantics, and
small code paths suitable for the machine.

Craig's original SD code and the later `sd_api`/TEC-FS work are worth reviewing
as the replacement storage base. The target should be reliable random sector
read/write first, then TEC-FS file operations above that. User-facing file
tools can sit above the fixed-ROM service boundary.

## PATA

PATA should be removed from the standard MON3 ROM profile.

The current PATA-specific range is relatively small, but it still brings the
wrong hardware assumption into the fixed ROM. If PATA support is still wanted,
it is a good fit for:

- a PATA board ROM
- an extension ROM driver
- an optional storage module selected at build time

The standard ROM should keep the storage API stable enough that a PATA driver
could exist elsewhere without making SD carry the PATA design.

## GLCD And Display

The GLCD package spans about 3995 bytes. The split report classifies it roughly
as:

| Category | Bytes | Disposition |
| --- | ---: | --- |
| Hardware init, clear, and mode setup | 130 | Keep as hardware reference or compact service. |
| Drawing primitives | 526 | Useful, but should be selectable. |
| Plot and native text-mode helpers | 114 | Useful low-level service. |
| Timing and buffer policy | 22 | Keep timing, move policy out. |
| Terminal text core | 279 | Move or rewrite as a display driver. |
| Cursor and scrollback viewport | 187 | Move out of fixed ROM. |
| Glyph and cursor renderer | 169 | Useful as a library component. |
| Font and text constants | 1544 | Useful, but expensive in fixed ROM. |
| MON3 GLCD banner bitmap | 1024 | Move out of fixed ROM. |

The clearest immediate cut is the 1024-byte GLCD banner. It is an asset, not a
BIOS service.

The deeper question is whether the GLCD terminal belongs in the fixed ROM at
all. A useful display layer should not be only a baked-in GLCD terminal. It
should expose a small set of generic calls that could drive a VDU, GLCD, or
fallback LCD:

- initialise display
- clear display
- set text mode
- set cursor
- write character
- write string
- write hex byte/word
- scroll or newline
- optional plot/update for bitmap displays
- optional glyph/sprite draw for GLCD-style displays

The fixed ROM can keep a minimal fallback implementation. Rich GLCD terminal
handling, scrollback, banners, fonts, and VDU-specific drivers can live in
extension ROMs or selectable display libraries.

This would make room for a more useful display service model without making the
fixed ROM carry every possible display personality.

## Tiny BASIC And Language Support

Tiny BASIC is not currently part of the measured MON3 image. If Tiny BASIC is a
goal, the ROM needs to stop spending space on features that are less generally
useful.

Tiny BASIC would benefit from resident services such as:

- character input
- character and string output
- cursor and clear-screen services
- numeric formatting/parsing helpers
- simple serial I/O
- SD sector or TEC-FS file access
- compact error reporting
- optional sound/timing calls

Those are good BIOS services because they are useful to Tiny BASIC and also to
other higher-level programs. A large GLCD terminal, PATA path, RTC UI, and
storage menu are less useful as resident BIOS foundations.

Tiny BASIC itself could be:

- resident, if enough ROM is recovered
- an extension ROM application
- a disk-loaded application that calls resident services

The choice depends on measured ROM space after PATA, GLCD terminal assets, RTC
UI, and storage UI are split out.

## Disassembler

The disassembler is about 2K. It is a real space target, but it is also part of
the classic MON3 personality and is broadly useful for recovery, inspection, and
debugging.

Recommended position:

- keep it during the first slimming pass
- treat it as a reserve cut only if stronger tools replace it elsewhere
- consider moving the UI around it before removing the core decode routines

Removing the disassembler may save space, but it also makes MON3 feel less like
a monitor.

## RTC

The RTC block is about 1.4K. The useful resident part is the hardware service
layer: detect, get/set time, get/set date, get/set day, mode, and raw PRAM
access if needed.

The parts that look better as auxiliary tools are:

- interactive clock setup UI
- RTC PRAM viewer
- long formatting strings
- LCD/keypad workflows

Recommended position:

- keep compact RTC read/write services if hardware support is important
- move interactive RTC tools out of fixed ROM
- use compact error/status results instead of large text where possible

## Menus, Help, And User Workflows

Menu and parameter drivers are useful, but they should be treated carefully.
Small reusable menu helpers may belong in ROM. Large monitor menus, prompts,
help text, and feature-specific workflows should not dominate the fixed image.

Good resident candidates:

- compact menu selection helper
- compact parameter entry helper
- address/range parser
- confirm/cancel helper if small

Good auxiliary candidates:

- large menu trees
- help screens
- file browser UI
- storage import/export UI
- demos and novelty strings
- hardware-specific setup screens

## Candidate Core ROM Profile

A focused MON3 ROM could look like this:

1. Classic reset and monitor entry.
2. Memory examine/edit, GO, range display, compact error display.
3. Keyboard, LCD, seven-segment, serial, timing, sound, and formatting services.
4. System latch and bank state services.
5. SD sector read/write and compact storage errors.
6. Optional compact TEC-FS file-sector service if it can be made reliable.
7. Generic display service calls for text/video output.
8. Minimal fallback display driver.
9. Disassembler retained unless measured pressure forces a second pass.

Everything else should justify its place against Tiny BASIC, storage fixes, and
general-purpose BIOS services.

## Candidate Auxiliary Set

The following should be considered for extension ROM, disk-loaded tools, or
optional build modules:

| Area | Why auxiliary |
| --- | --- |
| PATA driver | Board-specific and not the standard storage target. |
| GLCD banner | Asset, not a BIOS service. |
| GLCD terminal scrollback | Display personality, not a universal monitor requirement. |
| Full GLCD drawing library | Useful, but not always needed resident. |
| VDU driver | Hardware-specific display driver behind generic display calls. |
| Rich font libraries | Useful to applications, expensive in fixed ROM. |
| Storage file browser/load UI | User workflow above the SD/TEC-FS service layer. |
| Intel HEX load workflow | Legacy transfer path; useful as a tool, not necessarily resident. |
| RTC setup and PRAM viewer | Interactive application, not core time service. |
| Help text and demos | Better as documentation, disk files, or extension tools. |
| Tiny BASIC | Desirable application; resident only if space permits. |

## Measurement Questions

Before changing the ROM, these should be measured from a buildable source tree:

- exact ROM bytes saved by removing PATA from the standard profile
- exact ROM bytes saved by removing the GLCD banner
- exact ROM bytes saved by moving GLCD terminal scrollback out
- exact ROM bytes needed for minimal text/video service vectors
- exact ROM bytes needed for a compact SD sector read/write API
- exact ROM bytes needed for TEC-FS file-sector access
- exact ROM bytes saved by moving RTC UI out
- exact ROM bytes saved by replacing storage text with compact error codes
- exact ROM budget required by Tiny BASIC and its required service calls

The first practical build target should be an SD-only MON3 profile with PATA
removed and storage UI separated from storage services. GLCD banner removal is a
measured optional cut if it blocks that work, not a near-term goal by itself.
That gives a measured base before deciding whether GLCD terminal code, RTC UI,
or the disassembler must also move.

## Near-Term Shrink Checklist

The immediate MON3-light work should not try to shrink everything at once. The
expansion ROM now has enough space to carry TecMate services, so fixed-ROM
pressure should be relieved in the order that best supports the operating-system
direction:

1. Keep the current monitor command set, reset/restart behaviour, disassembler,
   keyboard/LCD/seven-segment basics, timing, sound, and bank-switching services.
2. Replace the old PATA/FAT32 default with the TEC-FS direction: fixed ROM should
   keep or rebuild compact SD sector primitives, while TEC-FS mount, volume,
   locator, block, and file services grow behind the banked ABI.
3. Remove PATA from the standard ROM profile. PATA is board-specific and should
   live in an auxiliary compatibility bank if it remains supported.
4. Move storage UI, RAM backup/restore flows, Intel HEX storage workflows, and
   long storage messages out of fixed ROM. Keep compact error codes and service
   calls instead.
5. Treat FAT32 compatibility as tooling or compatibility code, not the normal
   runtime filesystem. The TEC-formatted FAT32 card plus TEC-FS locator model
   lets the TEC use absolute sectors without parsing FAT32 directories during
   normal operation.
6. Leave RTC hardware services alone for now if they remain resident and useful.
   RTC setup UI and PRAM viewer can move later, but they are lower priority than
   storage replacement.
7. Treat GLCD as low priority unless it blocks another change. The current aim is
   to use TMS9918/VDU text services for TecMate, keep GLCD behind a banked
   boundary, and avoid spending near-term effort moving or rewriting GLCD code
   unless fixed-ROM space, service layout, or compatibility testing requires it.
8. Re-measure after each cut. Do not remove the disassembler or classic monitor
   commands until storage replacement has been measured and the remaining
   pressure is known.
