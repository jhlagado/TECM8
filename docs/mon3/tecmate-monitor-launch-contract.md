# TecMate Monitor Launch Contract

This document records the current fixed-ROM launch path for TecMate. It is the
contract between the MON3-derived monitor at `C000h-FFFFh` and the banked
TecMate expansion image at `8000h-BFFFh`.

The current monitor still boots into the familiar TEC-1G menu. TecMate is
entered through the first main-menu item, not by replacing the reset path. This
keeps the turn-on experience compatible while giving the new operating system a
stable entry point.

## Fixed monitor responsibility

The monitor owns the launch because it is the only code region that is not
bank-switched. The launcher is intentionally small:

```asm
launchTecMate:
        xor a
        call BiosBankSelect
        jp 08000H
```

That sequence means:

| Step | Meaning |
| --- | --- |
| `xor a` | select physical expansion bank `0` |
| `call BiosBankSelect` | update the expansion bits in `SYS_CTRL` while preserving unrelated control bits |
| `jp 08000H` | transfer control to the start of the selected expansion window |

The fixed monitor does not know the TecMate shell internals. Its only launch
contract is: select expansion physical bank 0, then jump to `8000h`.

## Expansion bank 0 responsibility

Physical bank 0 is the TecMate bootstrap bank. Its `8000h` entry currently runs
the first service chain:

```asm
@Tecm8ExpansionBank0Entry:
        ld a,TECM8_EXPANSION_BANK
        ld (TECM8_DEMO_TRACE_0),a
        call Tecm8BootstrapVdu
        call Tecm8BootstrapTecfs
        call Tecm8BootstrapInput
        call Tecm8BootstrapShell
        ret
```

For now this is still a proof scaffold, not the final shell. The important
shape is already in place:

| Item | Current value | Purpose |
| --- | --- | --- |
| `TECM8_DEMO_BANK0_ENTRY` | `8000h` | monitor launch target |
| `TECM8_SERVICE_CALL` | `80A0h` | bank-0 service registry |
| `TECM8_SHELL_ENTRY` | `8120h` | provisional shell entry |
| `TECM8_SERVICE_SHELL_ENTRY` | `80h` | registry service number for shell launch |

Bank 0 is allowed to call into other physical banks through the fixed monitor's
bank services. The `farCall` and `callService` ops are source-level wrappers
around that ABI; they do not change the monitor launch contract.

## Return behaviour

The `launchTecMate` routine itself uses `jp 08000H`, so it is not a far call
and it does not provide an automatic expansion-bank return. The current monitor
menu reaches menu routines through `runRoutine`, which pushes `softBoot` before
it jumps to the selected routine. That means the present bank-0 scaffold can
use a plain `ret` to return to the monitor soft-boot path.

The proof harness supplies its own RAM return address so the same bank-0 `ret`
can be observed without running the whole monitor menu loop. That proves the
handoff reaches code that can return normally. It does not prove a full TecMate
shell-exit policy, and it does not restore whatever expansion bank was selected
before launch. A formal shell-exit contract still needs to decide whether
TecMate exits by `ret`, soft boot, warm restart, or a dedicated monitor service.

## Shell exit contract

The initial TecMate shell-exit contract is deliberately conservative:

| Exit path | Contract |
| --- | --- |
| Menu-launched TecMate | bank 0 may exit with a plain `ret`; the monitor menu has already placed `softBoot` on the stack |
| Monitor-launch proof-launched TecMate | bank 0 may exit with a plain `ret`; the proof harness supplies a RAM halt return address |
| Far-called TecMate service | service routines must return through the fixed monitor `BiosBankCall` mechanism, not through the menu launcher |
| Full shell exit | still undecided; future shell code must choose between `ret`, soft boot, warm restart, or a dedicated monitor service |

This means the current bootstrap may be tested as a returning routine, but the
operating-system shell should not assume that arbitrary expansion banks can
return to arbitrary callers with only a near `ret`. Cross-bank calls remain the
job of the fixed monitor bank ABI.

## What the proof covers

`npm run proof:tecmate-monitor-launch` rebuilds the monitor and expansion ROMs,
then uses the monitor D8 map to locate `launchTecMate`. The proof starts there
and checks that:

1. the monitor selects expansion physical bank 0
2. execution reaches the visible expansion window at `8000h`
3. bank 0 runs the TecMate bootstrap/service chain
4. the test-only return path reaches the proof halt stub

This is the first stable bridge between the old monitor menu and the new
TecMate expansion-resident operating system.

## Design implication

This lets MON3 shrink slowly. The fixed monitor only needs enough permanent code
to boot, expose core BIOS services, manage expansion-bank selection, and enter
TecMate. Larger services such as TMS9918/VDU support, TEC-FS, RTC UI, and GLCD
compatibility can live behind the banked service ABI in expansion ROMs.
