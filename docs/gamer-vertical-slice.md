# Gamer Vertical Slice Specification

## Goal

Build the first proof that TECM8 can support a Z80/TMS9918-style game-writing
workflow:

```text
AZM user routines + simple assets + native runtime -> runnable game image
```

The slice should produce a tiny maze collection game in Debug80. The player can
move around one room, collide with walls, touch a collectible, and update a
score or counter. The player's behaviour is written as ordinary AZM/Z80 code
called by the game runtime.

This is not the full studio. It is the smallest buildable proof of the core
model from `docs/gamer.md`.

## Design Principles

Keep the first slice narrow.

- Prove game behaviour slots before designing a full IDE.
- Use ordinary AZM/Z80 before adding assembler ergonomics.
- Use simple asset definitions before building visual editors.
- Prefer a native runtime with stable contracts over ad hoc demo code.
- Keep output inspectable: binary, symbols, listing, and generated maps where
  available.
- Run under Debug80 first, then use hardware validation later.

The slice should be good enough to expose real architectural pressure, but not
so large that it becomes a hidden full engine project.

## Demo Game

The demo game should be a single-room maze collector.

Required behaviour:

- display a tile-based room
- show a player sprite
- read directional input
- move the player one step or pixel increment at a time
- block movement against wall tiles
- place one collectible actor
- detect player/collectible touch
- remove or hide the collectible after touch
- increment a score, counter, or game variable
- keep running in a stable main loop

This demo is preferred over Tetris for the first slice because it proves the
engine shape that most later games need: room drawing, sprites, actors, input,
collision, touches, and game state.

Tetris should be a later milestone because it exercises array logic and game
rules more than the shared tile/sprite runtime.

## Scope

### In Scope

- one fixed display/video mode
- one room
- one tileset
- one sprite set
- static tile collision tags
- a compact actor table
- a player actor
- one collectible actor type
- actor init/update/touch hooks
- input polling through a documented runtime API
- blocked actor movement through a documented runtime API
- simple score or collection counter
- host-side build flow
- Debug80 runnable target
- symbol/listing output where current tooling supports it

### Out Of Scope

- full visual editor
- music tracker
- scrolling
- multiple rooms
- room streaming
- dynamic asset loading
- cartridge export
- package marketplace
- assembler language extensions
- generalized scripting system
- advanced sprite multiplexing
- full debugger UI
- complete safety sandbox

## TECM8 Integration Shape

The vertical slice should sit alongside the current TECM8 proof-driven workflow.

Conceptual command flow:

```text
host build tool
  -> assemble game runtime
  -> assemble user routines
  -> convert simple assets
  -> link or pack runtime + routines + assets
  -> emit Debug80-loadable image
  -> emit symbols/listing
  -> run proof/smoke target
```

The first implementation can be host-driven. It does not need to be fully
self-hosted inside the TECM8 shell yet. The architecture should still preserve
the later path where the shell can run commands such as:

```text
game build
game run
game debug
```

The game runtime should use the TECM8 service direction rather than inventing a
separate system boundary. In particular, it should align with:

- the ROM/banked-tool direction in `docs/mon3/tecmate-banked-service-architecture.md`
- the future VDU/TMS9918 profile direction in `docs/tecm8-bios-api.md`
- the AZM source and contract style in `docs/azm-style-guide.md`

## Runtime Architecture

The first runtime should have these parts:

```text
GameRuntime
  boot/init
  frame loop
  input manager
  room/map renderer
  actor manager
  tile collision helper
  sprite presenter
  game-state bytes
  public API symbols
  debug/proof hooks
```

The runtime loop should be simple:

```text
1. wait for frame or use the available Debug80 timing strategy
2. read input
3. update frame counters
4. iterate active actors
5. call each actor update routine
6. test actor touches
7. update sprite state
8. apply queued tile/sprite display changes
9. repeat
```

The user should not replace this loop in the first slice.

## Actor Model

Use two layers:

- actor type definitions
- live actor instances

An actor type defines default behaviour:

```text
type id
default sprite
init routine
update routine
touch routine
default flags
```

A live actor instance stores runtime state:

```text
active flag
type id
x
y
sprite id/frame
state byte
flags
timer
user byte 0
user byte 1
```

Keep the first actor record compact. Do not over-design an ECS. The record only
needs enough state for the player and a collectible.

The first slice can use IX as the current actor pointer in user-facing routines
if that makes examples clearer. The runtime internals may use HL or other
registers where measured pressure requires it. The IX-vs-HL trade-off should be
recorded, not settled globally by the first demo.

## Routine Hooks

The first slice should support these hooks:

```text
Actor_Init
Actor_Update
Actor_Touch
Room_Enter
```

Only `Actor_Update` is mandatory for the first player proof. `Actor_Touch` is
needed for the collectible proof. `Actor_Init` and `Room_Enter` may be stubs at
first, but the hook shape should exist so the contract is visible.

### Actor Update Contract

```text
Called when:
  once per frame for each active actor with an update routine

Input:
  IX = current actor pointer, beginner-facing convention for v1

Output:
  routine returns with RET
  flags are not meaningful unless the specific hook says otherwise

Allowed:
  read/write documented current actor fields
  read documented game globals
  call public game runtime APIs

Clobbers:
  AF, BC, DE, HL may be clobbered by user routine and engine APIs
  IX should still point at the current actor on return in guided examples
  IY is reserved until a later contract defines it
```

### Actor Touch Contract

```text
Called when:
  the runtime detects a relevant overlap between current actor and another actor

Input:
  IX = current actor pointer
  HL = other actor pointer, or another documented pointer register if HL proves
       better for runtime implementation

Output:
  routine returns with RET

Allowed:
  destroy current actor
  update score/counter
  trigger sound placeholder

Clobbers:
  AF, BC, DE, HL may be clobbered unless the implementation narrows this later
```

The exact pointer convention can change during implementation if measurement
shows a better path, but the final slice must document what it actually uses.

## Minimal Public API

The first API should be small and stable enough for the demo.

### API_GetInput

```text
Input:
  none

Output:
  A = input bitfield

Clobbers:
  zero, sign, parity, halfCarry
```

### API_MoveActorBlocked

```text
Input:
  IX = current actor pointer
  B = signed dx
  C = signed dy

Output:
  carry clear if movement applied
  carry set if blocked by room collision

Clobbers:
  A, B, C, D, E, H, L, zero, sign, parity, halfCarry
```

### API_DestroyCurrentActor

```text
Input:
  IX = current actor pointer

Output:
  current actor marked inactive

Clobbers:
  A, zero, sign, parity, halfCarry
```

### API_AddScore

```text
Input:
  A = amount to add

Output:
  score/counter updated

Clobbers:
  A, H, L, zero, sign, parity, halfCarry
```

### API_PlaySound

```text
Input:
  A = sound id

Output:
  no-op is acceptable in the first slice

Clobbers:
  A, zero, sign, parity, halfCarry
```

These names are draft names. Implementation may adjust names to match TECM8
style, but the resulting symbols must be documented.

## Input Model

Use a compact input bitfield.

Required bits:

```text
INPUT_LEFT
INPUT_RIGHT
INPUT_UP
INPUT_DOWN
INPUT_FIRE
```

The first demo only needs directions. Fire is included because it is a common
game input and keeps the API ready for a second demo without adding machinery.

## Asset Model

The first assets can be plain source data or generated from simple host-side
files. Visual editors are not required.

Required assets:

- tileset
- collision tags for tile ids
- room tile map
- player sprite
- collectible sprite
- actor placement table

The first room can be small and static. It should contain enough walls to prove
blocked movement and enough open area to prove normal movement.

The asset format should be boring and inspectable. If JSON/TOML is used on the
host side, the builder should emit explicit assembled data or binary data. If
the first proof uses `.db` data directly, that is acceptable as long as the
boundaries are documented.

## Project Layout

The first demo project can live under a proof/demo directory rather than
claiming the final project format.

Suggested shape:

```text
games/maze-collector/
  game.toml
  src/
    player.asm
    coin.asm
    room.asm
  assets/
    tiles.*
    sprites.*
    room.*
  build/
    maze-collector.bin
    maze-collector.map
```

Generated files should stay under `build/` or another ignored output directory.
Source, fixtures, and docs should be tracked.

## Build Flow

The build flow should prove the eventual TECM8 workflow without requiring the
full shell integration.

Minimum host-side flow:

```text
npm script or tool command
  -> assemble runtime
  -> assemble user routines
  -> convert assets if needed
  -> combine binary sections
  -> write runnable image
  -> write symbols/listing where available
```

The build should fail clearly when:

- a required routine symbol is missing
- an actor type references an unknown routine
- an asset file is malformed
- actor or asset counts exceed the first-slice limits
- the output image exceeds its target memory range

## Debug80 Proof

The slice is complete only when it can run under Debug80 through an automated or
semi-automated target.

Required verification:

- runtime boots
- room appears or the display buffer contains expected room output
- player actor exists
- simulated input moves the player in open space
- simulated input into a wall does not pass through the wall
- touching the collectible deactivates it
- score/counter changes after collection
- the program remains in the loop after the collection event

If visual verification is difficult in the first pass, memory-state assertions
are acceptable. The proof should still preserve the path toward visual Debug80
inspection.

## Memory And Addressing

The first implementation should define a concrete memory map before coding.
This document does not fix exact addresses.

The map needs named regions for:

- runtime code
- user routine code
- asset data
- actor table
- room state
- game globals
- stack
- scratch buffers
- display or VDP staging data

The map should respect existing TECM8/Debug80 conventions where practical. Do
not assume final banked ROM placement for the first proof; a RAM-loaded target
is acceptable if it is documented as a proof target.

## Error Handling

The first runtime can fail hard for impossible internal states, but the builder
should provide useful host-side errors.

Runtime checks worth keeping:

- actor count limit exceeded during spawn
- unknown actor type
- invalid room pointer
- unsupported tile id or collision id in debug builds

Builder checks are more important than runtime safety in this slice because the
first demo data is static.

## Deliverables

The first vertical slice should deliver:

- documented game runtime entry point
- documented actor record layout
- documented hook contracts
- documented minimal API
- demo player routine in AZM/Z80
- demo collectible routine in AZM/Z80
- static room/map data
- static sprite/tile data or placeholders if display support is still being
  proved
- host build command
- Debug80 run/proof command
- symbols/listing output where available
- short README or doc section explaining how to run the demo

## Acceptance Criteria

The slice is accepted when:

- a fresh checkout can build the demo with one documented command
- the demo runs under the TECM8 Debug80 profile or a clearly named game profile
- user behaviour code is ordinary AZM/Z80, not hard-coded into the runtime
- the runtime calls at least one user `Actor_Update` routine
- movement uses a documented engine API
- wall collision is enforced
- collectible touch uses a documented hook or API path
- score/counter state changes after collection
- the relevant contracts are written down beside the implementation

## Open Questions

These should be answered during implementation, not solved prematurely here.

- Should the first proof target a TMS9918 emulation path immediately, or use a
  simpler display buffer while the VDU profile is still forming?
- Should IX remain the beginner-facing actor pointer for v1, or should the
  first implementation use HL and provide clearer helper examples?
- Should room collision be tile-grid based only, or should actor bounding boxes
  be introduced immediately?
- Should the first asset data be direct `.db` source, generated binary, or
  generated assembly from JSON/TOML?
- Should the runtime live under `src/`, `roms/`, `games/`, or a new dedicated
  `game-runtime/` area?
- How much of the Debug80 proof should assert visual state versus actor/game
  memory state?

## Deferred Topics

Do not include these in the first slice unless implementation pressure proves
they are necessary:

- structured AZM control-flow transforms
- actor-field syntax sugar
- API-call lowering syntax
- register-preservation helpers
- full package format
- full source-aware debugger
- sound/music editor
- visual tile/sprite/map editors
- multi-room project format
- final banked ROM ABI

The first slice should make those discussions better informed by giving them a
real runtime target.
