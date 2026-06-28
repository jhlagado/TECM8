# TecMate Banked Service Architecture

This document captures the next TECM8/MON3-light direction: the fixed monitor
ROM should become the stable BIOS doorway, while VDU/TMS9918, TEC-FS, RTC
tools, and larger applications live in banked expansion ROM.

The important conclusion is that a single 16K fixed ROM cannot reasonably hold
MON3 compatibility, bank switching, a useful text/video system, TEC-FS, RTC
tools, editor, BASIC, assembler, debugger, and future graphics support. The
system needs additional ROM banks for specific routines. That is not a fallback;
it is the main architecture.

## ROM Roles

```text
C000h-FFFFh  fixed monitor ROM
8000h-BFFFh  bank-switched expansion ROM window
0000h-7FFFh  RAM, vectors, monitor RAM, and application workspace
```

The fixed ROM owns the stable entry points:

- reset and monitor fallback
- MON3-compatible monitor commands where practical
- restart/API dispatch
- bank select
- `farCall` and `farJump`
- compact keyboard, LCD, serial, delay, sound, and status services
- lowest practical SD sector services
- compact RTC hardware services if measured small enough

The fixed ROM should avoid large workflows:

- file managers
- storage formatting UI
- RTC setup UI
- RTC PRAM viewer
- rich GLCD terminal behaviour
- TMS9918 implementation detail
- editor, BASIC, assembler, debugger, games, and demos

Those belong in banked ROM unless measurement proves a specific routine is both
small and essential.

## Working Bank Allocation

This allocation is provisional, but it gives development a concrete shape after
the initial bank-call proof. It supersedes the older two-bank sketch now that
Debug80 supports the TEC-1G nine-bank expansion decode model:

| Bank | Role | Notes |
| --- | --- | --- |
| 0 | TecMate shell and launcher | First user-facing bank. Provides menu/shell glue and common dispatch. |
| 1 | VDU and TMS9918 services | Generic VDU layer plus TMS9918 backend routines. |
| 2 | TEC-FS services | Filesystem, volume/catalogue logic, higher-level file calls. |
| 3 | RTC tools and diagnostics | Clock setup UI, PRAM viewer/editor, diagnostic screens. |
| 4 | Editor or BASIC | First larger application payload. |
| 5 | Assembler/debugger tools | Development tools that can call VDU and TEC-FS services. |
| 6 | Graphics/game support | Sprite/pattern helpers, demos, game-development routines. |
| 7 | Reserved | Future driver or application bank. |
| 8 | Reserved | Future driver or application bank. |

This does not mean the bank numbers are permanent ABI. The fixed ROM should
eventually call services through a registry or manifest table. Early code may
use direct `farCall bank,target` while the layout is still stabilising.

## Far Call Convention

Banked code should not directly manipulate the expansion hardware latch during
normal operation. It should call fixed-ROM services.

The current source-level convention is:

```asm
        farCall bank,target
        farJump bank,target
```

`farCall` switches to the target bank, jumps through the fixed-ROM trampoline,
and lets the callee return with a normal `ret`. The return does not need a
special banked return instruction because the callee returns to fixed ROM first;
fixed ROM restores the previous `SYS_CTRL` bank bits, then returns to the
original caller.

`farJump` switches to the target bank and tail-transfers control without
resuming after the helper. It is for launch, handoff, and permanent transfer of
control.

The fixed ROM should preserve unrelated `SYS_CTRL` bits when switching banks.
Only the expansion-selection bits should be changed.

## Monitor RST 10h Dispatch Plan

The monitor should expose TecMate expansion services through RST 10h rather
than asking applications to know physical bank numbers. The fixed ROM remains
the stable doorway; bank 0 owns the first published expansion service map.

The near-term split should be:

```text
RST 10h C=50h-54h    fixed monitor bank-control services
RST 10h C=60h        generic TecMate monitor-to-expansion bridge
RST 10h C=61h-6Fh    reserved TecMate bridge/service range
bank 0 installed vector -> private service dispatcher
banked services      VDU/TMS9918, TEC-FS, RTC tools, applications
```

The first bridge service should be deliberately small. `C=60h` selects the
monitor bridge itself; `A` carries the TecMate service ID. The fixed-ROM shim
constructs the same per-call stack-word request used by the current
`callService` helper, validates the installed expansion service vector, enters
that bank/address through the fixed `BiosBankCall` path, and lets the installed
dispatcher route through its registry. That keeps physical bank selection out
of ordinary callers while still preserving the fixed ROM as the only code that
changes `SYS_CTRL`.

The bridge must preserve the existing bank-call rules:

- fixed ROM masks `SYS_CTRL` so unrelated bits are preserved
- for the `C=60h` bridge, `A` is the dispatch service ID and is not an
  argument to the target service
- target service arguments should use the remaining documented registers or
  parameter blocks
- banked services return with a normal `ret`
- fixed ROM restores the previous `SYS_CTRL` state before returning to the
  original caller
- unsupported service IDs return a carry-set error rather than jumping through
  an unknown address

This plan does not make GLCD movement a near-term dependency. GLCD should stay
as a containment boundary unless it blocks fixed-ROM space, service layout, or
compatibility testing. The first bridge users should be TecMate shell launch,
VDU/TMS9918 text services, and TEC-FS mount/volume/sector services.

## Service Registry Direction

Direct `farCall bank,target` is good enough for the first proof programs, but it
does not scale as a public ABI. Programs should not need permanent knowledge
that TEC-FS is in bank 2 or that a VDU function is at a particular address.

The target model is:

```text
service id -> bank selector bits + entry address + ABI version
```

The service registry may live in fixed ROM, bank 0, or a small manifest table
that fixed ROM knows how to read. The early requirement is simply that every
bank exposes enough metadata for tools and Debug80 to identify what is mapped
at `8000h-BFFFh`.

## VDU And TMS9918 Direction

TecMate should expose a generic VDU layer and a lower-level TMS9918 backend.

Generic VDU calls are for shell, editor, BASIC, assembler, debugger, menus, and
ordinary tools:

```text
vduInit
vduClear
vduSetCursor
vduPutChar
vduPutString
vduNewLine
vduScroll
vduWriteHexByte
vduWriteHexWord
```

TMS9918 calls are for the backend itself and for programs that need direct
control of the video chip:

```text
tmsInit
tmsSetRegister
tmsWriteVram
tmsReadVram
tmsFillVram
tmsCopyToVram
tmsLoadPatterns
tmsLoadColours
tmsSetNameTable
tmsSpriteSetup
```

The fixed ROM should hold only the stable dispatch doorway, not a full TMS9918
driver. The TMS backend, fonts, pattern tables, sprite helpers, and demos belong
in banked ROM.

## TEC-FS Direction

TEC-FS is now a standard banked subsystem, not a small add-on. It replaces the
PATA path and the full FAT32 monitor implementation as the long-term TEC
storage model.

The fixed ROM should provide the lowest practical SD services:

```text
sdInit
sdReadSector
sdWriteSector
sdCardInfo
sdLastError
```

The TEC-FS bank should provide higher-level filesystem operations:

```text
tecfsMount
tecfsSelectVolume
tecfsList
tecfsOpen
tecfsRead
tecfsWrite
tecfsClose
tecfsLoadRange
tecfsSaveRange
tecfsDelete
tecfsRename
tecfsGetMetadata
tecfsSetMetadata
```

The current storage direction is still a FAT32-formatted SD card containing
multiple contiguous TEC-FS image volumes. Each TEC-FS volume should be 128 MiB
with 4 KiB blocks. On a 4 GiB-class card, the working target is 30 user volumes
plus one spare/work volume for repair, compaction, migration, or copy-then-swap
maintenance.

The fixed ROM should not contain the full filesystem UI, formatter, repair
tool, or host-interchange policy. Those are banked tools.

## RTC Split

RTC support should be split into compact BIOS services and banked tools.

Keep in fixed ROM if measured small enough:

- DS1302 detect/presence check
- get time
- set time
- get date
- set date
- get/set day
- 12/24-hour mode
- compact BCD helpers if shared by callers
- raw RTC RAM byte read/write if small and useful

Move out of fixed ROM:

- interactive clock setup UI
- RTC PRAM dump/viewer
- RTC PRAM editor
- LCD/keypad RTC screens
- RTC help text and prompts

The banked RTC tool can call the fixed RTC BIOS services. That keeps the useful
hardware support resident without paying the fixed-ROM cost for the user
interface.

## First Implementation Increments

1. Add a banked service architecture note and keep it current as decisions land.
2. Create a minimal VDU/TMS9918 skeleton in the expansion ROM with no full
   hardware dependency yet.
3. Mark the RTC source split points: service routines to keep, UI routines to
   move.
4. Add a TEC-FS bank skeleton with service names and volume constants.
5. Add a simple service registry or manifest structure so banked services are
   discovered by ID rather than hard-coded forever.
6. Measure fixed-ROM savings from removing RTC UI, PATA/FAT32 UI, and bulky
   GLCD UI paths.

The guiding rule is simple: fixed ROM is the stable BIOS doorway; banked ROM is
where TecMate grows into a usable operating environment.
