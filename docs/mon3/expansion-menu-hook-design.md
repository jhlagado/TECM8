# MON3 Expansion Menu Hook Design

## Decision

MON3 should not hardcode TecMate as a special monitor feature. MON3 should expose
one generic expansion menu hook. TecMate, BASIC, a games cartridge, or another
bank-0 supervisor can install itself behind that hook.

The first implementation should use a hybrid discovery model:

1. MON3 keeps a static main-menu item called `Expansion`.
2. MON3 has a small expansion discovery routine.
3. Discovery selects physical bank 0 and checks a header at `8000h`.
4. If the bank-0 header is valid, MON3 calls the header-provided install entry.
5. The install entry writes expansion menu/service vectors into MON3 RAM.
6. The `Expansion` item calls a small MON3 launcher.
7. The launcher checks the installed expansion menu vector.
8. If the vector is zero, MON3 reports that no expansion menu is installed.
9. If the vector is nonzero, MON3 validates the bank/address pair and calls the
   expansion menu provider through the monitor bank-call machinery.
10. Bank 0 owns the richer policy: scanning subordinate banks, validating ROM
   headers, building service tables, and presenting an expansion-specific menu.

This keeps MON3 generic and small while allowing bank 0 to behave like a
cartridge supervisor.

## Why Not Dynamic Main-Menu Rebuild Yet

MON3's menu engine is already flexible. `menuDriver` accepts `HL` as a pointer to
a menu configuration, and the menu controller can run a menu from any address
that contains the expected count, title, labels, and two-byte routine addresses.

The existing main menu, however, is static ROM data:

```asm
mainMenuCFG:
        .db 12
        .db "TEC-1G"
        .db "= TEC-1G Main Menu =",0
        .db "TecMate",0
        .dw launchTecMate
```

Appending a true dynamic item would mean copying or rebuilding the main menu in
RAM so the count, labels, and routine addresses can change. That is possible,
but it is more monitor code and more RAM pressure than needed for the first
version.

The hybrid hook gives most of the value immediately: the MON3 main menu remains
stable, and the selected expansion can present its own dynamic submenu through
the existing menu engine.

## MON3 Responsibilities

MON3 should provide only the socket:

- a generic `Expansion` main-menu item
- an expansion discovery routine that checks physical bank 0 for a valid header
- installed expansion menu vector fields in RAM
- installed expansion service vector fields in RAM, if needed for `RST 10h`
  bridging
- a small launcher routine that checks whether the menu vector is installed
- compact failure handling when no expansion menu is installed

MON3 should not know TecMate service numbers, VDU bank layout, TEC-FS bank
layout, or cartridge-specific menu contents.

The installed vectors must not be plain 16-bit addresses. A vector into the
expansion window is a fixed four-byte v1 structure:

```text
byte 0  physical bank, 0..8
byte 1  address low byte
byte 2  address high byte
byte 3  flags, reserved in v1 and written as 00h
```

An address of `0000h` means the vector is uninstalled. If installed, MON3 must
validate that the bank is in range and the address is inside the expansion
window, `8000h-BFFFh`, before transferring control.

The v1 MON3 RAM contract should publish these fields:

```text
EXP_MENU_VEC_BANK   physical bank for the expansion menu provider
EXP_MENU_VEC_ADDR   two-byte little-endian address, or 0000h if uninstalled
EXP_MENU_VEC_FLAGS  reserved, must be 00h in v1

EXP_SVC_VEC_BANK    physical bank for the expansion service dispatcher
EXP_SVC_VEC_ADDR    two-byte little-endian address, or 0000h if uninstalled
EXP_SVC_VEC_FLAGS   reserved, must be 00h in v1
```

Returning calls must go through the monitor bank-call machinery so the previous
`SYS_CTRL` state is restored on `RET`. MON3 code should not open-code "select
bank, then call" for installed vectors.

For v1, both the expansion menu vector and expansion service vector are
returning calls. A permanent handoff to an expansion operating environment can
be added later with an explicit non-returning flag or separate vector, but it is
not part of the first contract.

## Bank 0 Responsibilities

Bank 0 is the supervisor for a particular expansion system.

For TecMate, bank 0 should:

- publish a valid supervisor header at `8000h`
- provide an install entry through that header
- install the MON3 expansion menu vector
- optionally install a MON3 expansion service vector
- scan subordinate banks if the ROM set uses bank headers
- validate magic, version, bank id, type, and optional checksum
- build its own installed-bank bitmap and service registry
- present the TecMate menu using MON3 `menuDriver` or its own UI
- route higher-level TecMate services to banks 1..8

Other systems can use the same MON3 hook with a completely different bank-0
policy.

## ROM Presence

The minimal ROM presence test should be a header at the start of the mapped
bank. MON3 only needs to discover physical bank 0 for the first version:

```text
8000h  magic, for example "EXPR"
8004h  header version
8005h  expected physical bank id
8006h  ROM type
8007h  flags
8008h  install address low byte
8009h  install address high byte
800Ah  reserved, must be 00h in v1
```

This header is not a routine entry point. It is data. Its job is to answer:

```text
Is this bank occupied by a ROM that follows the expected expansion format?
```

The only fixed address implied here is the hardware-mapped bank start
`8000h`. Routine addresses remain private to the ROM set unless registered by
bank 0.

For bank 0, a valid install address allows MON3 to perform a late-bound install:

```text
save the pre-discovery SYS_CTRL state
select bank 0
read and validate header at 8000h
if valid, install address != 0000h, and install address is in 8000h-BFFFh:
    call bank 0 install address through the monitor bank-call machinery
restore the pre-discovery SYS_CTRL state
```

Discovery must preserve the `SYS_CTRL` state that existed before probing bank 0.
If the implementation selects bank 0 before using `BiosBankCall`, it must save
the pre-probe state separately and restore it after the probe/install path.
Otherwise `BiosBankCall` would restore to bank 0 rather than to the caller's
original expansion mapping.

The install routine must return normally. It may write MON3 vector RAM, installed
flags, and optional display/debug state. It should not require MON3 to know any
TecMate-specific service numbers.

MON3 must reject malformed headers and malformed installed vectors. A bad bank
number, a zero vector where installation is required, nonzero reserved flags,
nonzero reserved header bytes, or an address outside `8000h-BFFFh` should leave
the relevant vector uninstalled.

## Service Routing

The first service bridge should be late-bound:

```text
RST 10h expansion service request
  -> MON3 checks installed expansion service vector
  -> if zero: unknown service
  -> if nonzero: validate bank/address and call the installed supervisor
     dispatcher through the monitor bank-call machinery
```

Bank 0 then owns the actual dispatch. It can use source-aware calls to private
labels inside the TecMate ROM set, or it can route through its own scanned
service table.

MON3 should not round-robin through every bank asking whether it handles a
service. That makes MON3 policy-heavy, creates conflict-order problems, and
requires every ROM to implement a query ABI. Bank 0 is the right place for that
complexity.

## Near-Term Implementation Shape

The next implementation should replace the hardcoded `TecMate` main-menu item
with a generic `Expansion` item and add MON3 discovery for a bank-0 supervisor
header.

Initial behaviour:

```text
MON3 reset or first Expansion selection
  clear installed expansion vectors
  select physical bank 0
  check 8000h header magic/version/bank/type
  if valid:
      call header install address through the monitor bank-call machinery

Expansion selected
  if EXP_MENU_ADDR == 0000h:
      show no-expansion message and return to MON3
  else:
      validate EXP_MENU_BANK and EXP_MENU_ADDR
      call EXP_MENU_ADDR through the monitor bank-call machinery
```

TecMate bank 0 can then install that vector during its startup path and present
its own menu. Later, the same mechanism can support BASIC, games, diagnostics,
or another cartridge-like system without MON3 knowing those names.
