# Game-Facing Register Contracts

TecMate game support should use the same contract discipline as the rest of the
system: small documented entry points, register-first arguments, clear clobber
rules, and conservative failure reporting.

This document does not define the first game runtime implementation. It defines
the calling-convention bias that should shape that runtime when it arrives.

## Principles

- Register arguments are the default for hot game APIs.
- Stack arguments are not the normal API style for per-frame game code.
- The stack is still used for return addresses, saved registers, local
  preservation, and bank-call gateway frames.
- Game hooks and APIs should be documented with AZM-style register contracts.
- If a contract cannot be checked by the self-hosted assembler yet, it should
  still be written so host AZM, reviewers, and future tooling can use it.
- Game-specific conventions must not weaken the general TecMate ABI. They sit
  above the BIOS, VDU, input, TEC-FS, shell, and debugger service boundaries.

## Register Roles

The first game runtime should treat registers as follows unless measurement
shows a better convention:

| Register | Preferred game role |
| --- | --- |
| `A` | Small value input/output, status, input bitfield, score amount, sound id. |
| `B` | Small signed or unsigned argument, commonly `dx`. |
| `C` | Small signed or unsigned argument, commonly `dy`, or a service selector when calling TecMate BIOS services. |
| `DE` | Secondary pointer, packed coordinate, or scratch pair. |
| `HL` | Data pointer, other actor pointer, table pointer, or scratch pair. |
| `IX` | Current actor pointer for beginner-facing actor hooks. |
| `IY` | Reserved until a later runtime contract assigns it. |

`A`, `B`, `C`, `D`, `E`, `H`, `L`, and non-output flags are the natural
clobber set for many game APIs.
`IX` should be preserved across beginner-facing actor hooks unless a specific
advanced hook says otherwise. `IY` should remain preserved until the runtime
has a documented use for it.

## Hook Contracts

Actor update hook, v1 convention:

```asm
.routine in IX clobbers A,B,C,D,E,H,L,zero,sign,parity,halfCarry
Player_Update:
        ret
```

Meaning:

- `IX` points at the current actor record.
- The routine returns with `ret`.
- `A`, `B`, `C`, `D`, `E`, `H`, `L`, and non-output flags may be used freely.
- `IX` still points at the current actor on return.
- `IY` is reserved and should not be modified.
- Flags are not meaningful unless the specific hook defines them.

Actor touch hook, v1 convention:

```asm
.routine in IX,HL clobbers A,B,C,D,E,H,L,zero,sign,parity,halfCarry
Actor_Touch:
        ret
```

Meaning:

- `IX` points at the current actor.
- `HL` points at the other actor or contact target.
- The hook may destroy an actor, update score, or trigger a sound through
  documented runtime APIs.

The exact pointer convention can be changed before the first runtime is
implemented, but the implementation must document the final convention before
game routines depend on it.

## Runtime API Contracts

Early game APIs should be small, register-first routines. Draft examples:

```asm
.routine out A clobbers zero,sign,parity,halfCarry
API_GetInput:
        ret
```

`API_GetInput` returns a compact input bitfield in `A`.

```asm
.routine in IX,B,C out carry clobbers A,B,C,D,E,H,L,zero,sign,parity,halfCarry
API_MoveActorBlocked:
        ret
```

`API_MoveActorBlocked` uses `IX` as actor pointer, `B` as signed `dx`, and `C`
as signed `dy`. Carry clear means movement was applied. Carry set means movement
was blocked.

```asm
.routine in IX clobbers A,zero,sign,parity,halfCarry
API_DestroyCurrentActor:
        ret
```

`API_DestroyCurrentActor` marks the current actor inactive.

```asm
.routine in A clobbers A,H,L,zero,sign,parity,halfCarry
API_AddScore:
        ret
```

`API_AddScore` adds the value in `A` to the current score or collection counter.

```asm
.routine in A clobbers A,zero,sign,parity,halfCarry
API_PlaySound:
        ret
```

`API_PlaySound` triggers or queues a sound id. It may be a no-op in the first
runtime slice.

## Relationship To TecMate Services

Game code should not call private bank labels directly. It should call:

- documented game runtime APIs
- documented TecMate BIOS services
- documented VDU/TMS9918 services
- documented input services once they exist
- documented TEC-FS services for project/data loading when required

The same rule already used by banked TecMate services applies here: internal
labels may move, but public service contracts should remain stable or versioned.

## Self-Hosted Assembler Implication

The self-hosted assembler does not need to enforce these contracts at first.
It should eventually parse and preserve them, then grow simple checks after the
core assembler is reliable.

Until then, contracts still serve four useful purposes:

- they make examples reviewable
- they keep host AZM checks useful
- they tell the debugger which registers matter at a hook boundary
- they help game authors learn what the machine is doing
