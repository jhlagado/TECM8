# VDU/TMS Minimum Primitives

TecMate needs a compact display layer for shell, editor, profile-generated
programs, and game-style interactive programs. The first target is the
TMS9918-style VDU because it gives the system a real text and video surface
without depending on the MON3 GLCD terminal assumptions.

This is not a game engine and not a general graphics library. It is the minimum
service surface that lets higher-level code draw text, manage a cursor, and
touch TMS9918 VRAM through a stable banked boundary.

## Current Bank 1 Boundary

The bank 1 dispatcher already separates two families:

- VDU text services from `VDU_SVC_INIT` through `VDU_SVC_PUT_STRING_N`
- raw TMS services from `TMS_SVC_INIT` through `TMS_SVC_READ_VRAM`

The public service registry currently exposes `VDU_INIT` as the public service
ID for bank 1 initialization. The registry routes that request to `VDU_ADDR`,
which is `VDU_CALL` at `VDU_ENTRY`, and passes the bank-local selector
`VDU_SVC_INIT` in `A`. Bank-local callers use the same `VDU_CALL` boundary with
a bank-local selector in `A`.

The current parameter block is `TMS_PARAM_BASE` and includes:

| Field | Meaning |
| --- | --- |
| `TMS_PARAM_VALUE` | character, fill byte, register value, or VRAM byte |
| `TMS_PARAM_REGISTER` | TMS register number |
| `TMS_PARAM_ADDR_LO` / `TMS_PARAM_ADDR_HI` | VRAM address or cursor input |
| `TMS_PARAM_CURSOR_LO` / `TMS_PARAM_CURSOR_HI` | current text cursor address |
| `TMS_PARAM_STRING_LO` / `TMS_PARAM_STRING_HI` | string pointer |
| `TMS_PARAM_COUNT_LO` / `TMS_PARAM_COUNT_HI` | byte count for fills, and max length for bounded string output |
| `TMS_PARAM_ROW` / `TMS_PARAM_COL` | text row and column for cursor positioning |

## Minimum Text Services

The minimum text layer should remain small:

- initialize the VDU
- clear the 32x24 name table
- set cursor by VRAM address
- set cursor by row and column
- put one character
- put a zero-terminated string
- put a bounded string
- advance to the next line
- scroll the visible text area up
- write a short status line

These services are enough for a shell, simple editor status, proof output, error
messages, and beginner-facing profile programs. More elaborate drawing should
be built above this layer or emitted by a profile preprocessor as ordinary
assembly that calls these services.

`VDU_SVC_PUT_STRING` keeps the legacy zero-terminated behavior and does not read
`TMS_PARAM_COUNT_LO/HI`, so stale fill counts cannot truncate old callers.
`VDU_SVC_PUT_STRING_N` is the bounded variant. It uses `TMS_PARAM_COUNT_LO/HI`
as a maximum byte count and stops at the first zero byte or after the requested
number of bytes, whichever comes first.

## Minimum Raw TMS Services

The raw TMS layer should stay as a thin hardware boundary:

- perform the small current TMS initialization path
- set a TMS register
- write one VRAM byte
- fill a VRAM range
- read one VRAM byte

This gives profile-generated programs a way to load pattern tables, color
tables, name tables, and later sprite data without forcing every operation into
the text VDU abstraction.

## Growth Policy

New display work should be judged against the ROM footprint budget. Add a VDU
primitive only when it removes repeated hot code, protects a stable ABI, or is
needed by the shell/editor/profile path. Avoid adding a broad graphics library
to bank 1 until there is a measured vertical slice that needs it.

GLCD support should not drive this bank's design. A GLCD backend can exist later
as a separate optional service, but it should not pull MON3 GLCD terminal policy
into the TMS-facing VDU contract.
