# TecMate Monitor Launch Contract

This document records the current fixed-ROM launch path for a TecMate-style
expansion supervisor. The monitor at `C000h-FFFFh` keeps the familiar TEC-1G
menu, but its first menu item is now a generic `Expansion` hook rather than a
hardcoded TecMate jump.

## Fixed monitor responsibility

The monitor owns discovery because it is the only code region that is not
bank-switched. The launcher is intentionally small:

```asm
launchExpansion:
        call discoverExpansion
        call validateExpansionVector
        jr c,launchExpansionMissing
        ld a,(EXP_MENU_VEC_BANK)
        ld b,a
        ld hl,(EXP_MENU_VEC_ADDR)
        call BiosBankCallDirect
        ret
```

That sequence means:

| Step | Meaning |
| --- | --- |
| `discoverExpansion` | selects physical bank 0, discovers an `EXPR` header, and calls the advertised install routine |
| `validateExpansionVector` | checks the installed menu vector is a bank/address pair inside `8000h-BFFFh` |
| `BiosBankCallDirect` | calls the installed menu vector and restores the previous `SYS_CTRL` state on return |

The fixed monitor does not know the TecMate shell internals. It knows only the
generic expansion header, the monitor RAM vector contract, and the bank-call
mechanism.

If discovery fails, or if the installed vector is invalid, the monitor clears
the menu/service vectors and returns through `launchExpansionMissing` after
displaying the short "No Expansion" LCD message. Expansion service requests
made through `RST 10h` also rediscover the supervisor before dispatch. If no
valid service vector is installed, the bridge returns `A=FFh` with carry set.

## Expansion bank 0 responsibility

Physical bank 0 is the supervisor bank. Its `8000h` bytes are header data, not
a routine entry point:

```asm
@Tecm8ExpansionHeader:
        .db     EXP_MAGIC_0,EXP_MAGIC_1
        .db     EXP_MAGIC_2,EXP_MAGIC_3
        .db     EXP_HEADER_VERSION
        .db     EXP_BANK
        .db     EXP_TYPE_SUPERVISOR
        .db     0x00
        .dw     Tecm8ExpansionInstall
        .db     0x00
```

The install routine writes the menu and service vectors into monitor RAM. The
menu vector currently points at the TecMate bootstrap scaffold:

```asm
@Tecm8ExpansionBank0Entry:
        ld a,EXP_BANK
        ld (DBG_TRACE_0),a
        call Tecm8BootstrapVdu
        call Tecm8BootstrapTecfs
        call Tecm8BootstrapInput
        call Tecm8BootstrapShell
        ret
```

For now this is still a demo scaffold, not the final shell. It deliberately
proves a small runnable system: the bootstrap initializes the VDU, touches the
TEC-FS boundary, reads the input snapshot boundary, and then enters the shell
entry service so the `TecMate ROM Shell` home screen and `POLL` status are
visible through the TMS9918 VDU path after the first input/update/render loop
slice.
The important shape is already in place:

| Item | Current value | Purpose |
| --- | --- | --- |
| `EXP_BANK0_INSTALL` | `800Bh` | bank-0 install routine advertised by the header |
| installed menu vector | monitor RAM | menu launch target supplied by bank 0 |
| installed service vector | monitor RAM | service dispatcher supplied by bank 0 |
| `SHL_ENTRY` | `80h` | expansion service number for shell launch |

Bank 0 is allowed to call into other physical banks through the fixed monitor's
bank services. The `farCall` and `callService` ops are source-level wrappers
around that ABI; they do not change the monitor discovery contract.

`callService` enters MON3 with the requested service ID directly in `C`. MON3
routes `C >= SVC_BASE` through the installed expansion service vector and calls
the installed dispatcher through `BiosBankCall`. The dispatcher and shell labels
are private bank-0 source labels, not fixed public entry addresses.

## Return behaviour

The `Expansion` menu item is entered through the normal MON3 `runRoutine` path,
which pushes `softBoot` before jumping to the selected menu routine. The
expansion provider itself is then called through `BiosBankCallDirect`, so the
pre-launch `SYS_CTRL` state is restored before `launchExpansion` returns.

The proof harness supplies its own RAM return address so the same returning
path can be observed without running the whole monitor menu loop. That proves
the handoff reaches the installed menu vector and returns through the monitor
bank-call machinery. It does not yet define a final full-shell exit policy.

## Shell exit contract

The initial TecMate shell-exit contract is deliberately conservative:

| Exit path | Contract |
| --- | --- |
| Menu-launched expansion | bank 0 is called through the fixed monitor bank-call path; `launchExpansion` then returns to the monitor menu path with `softBoot` on the stack |
| Monitor-launch proof-launched TecMate | bank 0 may exit with a plain `ret`; the proof harness supplies a RAM halt return address |
| Far-called TecMate service | service routines must return through the fixed monitor `BiosBankCall` mechanism, not through the menu launcher |
| Full shell exit | still undecided; future shell code must choose between `ret`, soft boot, warm restart, or a dedicated monitor service |

This means the current bootstrap may be tested as a returning routine, but the
operating-system shell should not assume that arbitrary expansion banks can
return to arbitrary callers with only a near `ret`. Cross-bank calls remain the
job of the fixed monitor bank ABI.

## What the proof covers

`npm run proof:tecmate-monitor-launch` rebuilds the monitor and expansion ROMs,
then uses the D8 maps to locate `launchExpansion` and the installed bank-0 menu
target. The proof runs two isolated cases.

Installed expansion case:

1. the monitor discovers the bank-0 `EXPR` header
2. bank 0 installs a menu vector into monitor RAM
3. the monitor calls the installed menu vector through the bank-call path
4. bank 0 runs the TecMate bootstrap/service chain
5. the test-only return path reaches the proof halt stub
6. Debug80's TMS9918 VRAM contains the visible `TecMate ROM Shell` title,
   `VDU:TMS TEC-FS:ROM` mode line, `>` prompt, and `POLL` status text from the
   first loop slice
7. the input parameter block reports the bank-6 neutral snapshot
8. the TEC-FS parameter block reports the current mount geometry
9. a RAM `RST 10h C=TFS_MOUNT` call reaches the installed service dispatcher

Missing expansion case:

1. no expansion image is installed in the Debug80 expansion banks
2. `launchExpansion` returns through the missing-expansion path
3. menu and service vectors remain cleared
4. no bank-0 bootstrap trace markers are written
5. a RAM `RST 10h C=TFS_MOUNT` call returns `A=FFh` with no service dispatch
6. `SYS_CTRL` is restored after both launch and service-bridge paths

This is the first stable bridge between the old monitor menu and a
cartridge-like expansion supervisor.

## Design implication

This lets MON3 shrink slowly. The fixed monitor only needs enough permanent code
to boot, expose core BIOS services, manage expansion-bank selection, discover an
expansion supervisor, and call installed vectors. Larger services such as
TMS9918/VDU support, TEC-FS, RTC UI, and GLCD compatibility can live behind the
banked service ABI in expansion ROMs.
