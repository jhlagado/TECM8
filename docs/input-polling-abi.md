# Input Polling ABI

TecMate input should be a cooperative polling service, not an interrupt-driven
application callback system. Interactive programs, profile-generated programs,
and game-style runtimes should read one input snapshot during their main loop,
compare it with their previous snapshot if they need edges, update state, and
then render any dirty output.

The ABI has to cover three physical input sources:

- the TEC-1G matrix keyboard
- the existing hex keypad path used by MON3 and compatibility tools
- the optional joystick or game panel

The first implementation can be sparse. It only has to make the boundary stable:
one service reads the current input state into a known snapshot area, and absent
hardware reports neutral values rather than an error.

## Snapshot Shape

The snapshot should distinguish current state from derived state. The hardware
read service owns the current fields. A runtime loop may derive previous state,
pressed edges, released edges, dirty bits, repeat state, or higher-level actions
outside the hot hardware reader.

The current bank 6 proof uses these fields:

| Field | Meaning |
| --- | --- |
| `INP_PARAM_STATUS` | zero for a valid snapshot |
| `INP_PARAM_LAST_ERROR` | last error value, preserved when unknown selectors fail |
| `INP_PARAM_BANK` | physical bank that served the request |
| `INP_PARAM_VERSION` | input service version |
| `INP_PARAM_KEYS_LO` | low byte of compact key state |
| `INP_PARAM_KEYS_HI` | high byte of compact key state |
| `INP_PARAM_JOYSTICK` | joystick bitfield |
| `INP_PARAM_MODIFIERS` | modifier bitfield |

Later runtime-facing state can add:

- previous key and joystick state
- pressed-edge and released-edge bitfields
- key-repeat counters
- raw matrix diagnostics for test tools
- a single input-changed or dirty flag for polling loops

That derived state should not be required for the low-level hardware read to be
useful. A game loop can compute `pressed = current & ~previous` and
`released = previous & ~current` in its own working RAM when it needs those
edges.

## Service Contract

The public expansion service is `INP_READ`, routed to bank 6 through the
TecMate expansion service registry. The bank-local selector passed to bank 6 is
`INP_SVC_READ` at `INP_ENTRY`. The proof expects that bank-local read to return
`A = 86h`, carry clear, `INP_PARAM_BANK = 06h`, and neutral key and joystick
fields.

The contract direction is:

- register-first for hot paths
- parameter-block state for shared snapshots and diagnostics
- `A` plus carry for small status results
- no interrupt-driven application callbacks
- no direct hardware parsing by profile/game/application code

The optional joystick panel must report a neutral bitfield when it is absent.
That lets software poll the same snapshot on machines with and without the panel.

The current ROM shell scaffold displays the first neutral snapshot as
`KEY:0000 JOY:00` on the TMS9918 screen. That is a visible debug/status echo of
the parameter block, not a separate input API.

## Loop Model

A program should normally do this:

1. Poll input once.
2. Copy or remember the previous snapshot if edge detection is needed.
3. Update program variables.
4. Set dirty flags for changed views or bound output fields.
5. Render only the dirty output.

This is intentionally close to a game loop. It also works for HyperCard-like
interactive applications because user-facing components become views over polled
state, not event-handler entry points.
