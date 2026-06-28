# MON3 Expansion Menu Hook Design

## Decision

MON3 should not hardcode TecMate as a special monitor feature. MON3 should expose
one generic expansion menu hook. TecMate, BASIC, a games cartridge, or another
bank-0 supervisor can install itself behind that hook.

The first implementation should use a hybrid model:

1. MON3 keeps a static main-menu item called `Expansion`.
2. The `Expansion` item calls a small MON3 launcher.
3. The launcher checks an installed expansion menu vector in RAM.
4. If the vector is zero, MON3 reports that no expansion menu is installed.
5. If the vector is nonzero, MON3 transfers control to the installed expansion
   menu provider.
6. Bank 0 owns the richer policy: scanning subordinate banks, validating ROM
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
- an installed expansion menu vector in RAM
- an installed expansion service vector in RAM, if needed for `RST 10h` bridging
- a small launcher routine that checks whether the menu vector is installed
- compact failure handling when no expansion menu is installed

MON3 should not know TecMate service numbers, VDU bank layout, TEC-FS bank
layout, or cartridge-specific menu contents.

## Bank 0 Responsibilities

Bank 0 is the supervisor for a particular expansion system.

For TecMate, bank 0 should:

- run when entered through the expansion window
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

The minimal ROM presence test should be a header at the start of each mapped
bank:

```text
8000h  magic, for example "TM8R"
8004h  header version
8005h  expected physical bank id
8006h  ROM type
8007h  flags
8008h  optional install/menu/service table offsets
```

This header is not a routine entry point. It is data. Its job is to answer:

```text
Is this bank occupied by a ROM that follows the expected expansion format?
```

The only fixed address implied here is the hardware-mapped bank start
`8000h`. Routine addresses remain private to the ROM set unless registered by
bank 0.

## Service Routing

The first service bridge should be late-bound:

```text
RST 10h expansion service request
  -> MON3 checks expansion service vector
  -> if zero: unknown service
  -> if nonzero: call the installed supervisor dispatcher
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
with a generic `Expansion` item.

Initial behaviour:

```text
Expansion selected
  if EXP_MENU_VECTOR == 0000h:
      show no-expansion message and return to MON3
  else:
      call or jump through the vector
```

TecMate bank 0 can then install that vector during its startup path and present
its own menu. Later, the same mechanism can support BASIC, games, diagnostics,
or another cartridge-like system without MON3 knowing those names.

