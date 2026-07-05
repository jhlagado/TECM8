# TecMate ROM Ownership Policy

This is the working ownership rule for MON3/TecMate ROM work. It exists to stop
fixed-ROM growth from happening by accident.

## Fixed Monitor ROM

The fixed `C000h-FFFFh` ROM is the stable BIOS and recovery layer. It owns:

- reset, interrupt, NMI, and RST entry points
- classic monitor startup and recovery behaviour
- fixed `RST 10h` service dispatch
- bank switching, far-call, and far-jump services
- expansion discovery and installed menu/service vectors
- compact hardware primitives that must remain callable while the expansion
  window is being switched

Any fixed-ROM growth must name the service it enables and the code it replaces,
relocates, or deliberately keeps. If it cannot justify that, it belongs in an
expansion bank.

## Expansion ROM

The banked `8000h-BFFFh` window is where TecMate grows. It owns:

- bank 0 supervisor, registry, shell, and launch policy
- VDU/TMS9918 services
- TEC-FS mount, volume, locator, block, metadata, and file services
- input snapshot services
- assembler, runner, debugger, and editor-facing services
- optional device backends and application/profile runtimes

Expansion-bank callers should use service IDs, dispatch tables, and source-level
`farCall`/`farJump` helpers. They should not depend on private implementation
labels in another bank.

## Storage

PATA is not part of the standard TecMate fixed-ROM direction. FAT32 remains the
outer card/container compatibility format, but TecMate runtime storage should
move toward TEC-FS services in expansion ROM.

The fixed monitor may keep or rebuild a compact SD sector primitive if that is
needed as the stable hardware boundary. It should not grow a new FAT32 browser,
PATA path, or human-facing storage UI. Those belong in TEC-FS tooling, banked
compatibility code, or PC utilities.

## Display

The main display direction is VDU/TMS9918 first. GLCD remains useful, but it is
not a near-term fixed-ROM priority.

GLCD work should stay as a banked boundary unless it blocks fixed-ROM space,
service layout, or compatibility testing. Do not spend fixed-ROM bytes on GLCD
terminal policy, banner assets, scrollback, or editor-specific display logic.

## Review Rule

Every ROM-facing increment should answer three questions before commit:

1. Did fixed monitor size change?
2. Did expansion ROM size change, and in which bank?
3. Does the change follow this ownership policy?

The answer should be visible through `npm run rom:size:delta`, the review notes,
or the commit context.
