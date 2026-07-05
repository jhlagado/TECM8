# TECM8 Game Creation Mission

## Purpose

TECM8 should grow beyond a self-hosted assembly environment into a practical
game creation environment for a Z80 machine with a TMS9918-style video profile.
The aim is not to hide the machine. The aim is to make real machine-code game
writing approachable by giving it a game-shaped structure.

The central question is:

```text
If we were designing a 1980s-style game computer today, with hindsight, what
should replace BASIC as the primary creative environment?
```

The proposed answer is a TECM8 game creation system:

```text
asset tools + native Z80 runtime + ordinary AZM/Z80 behaviour routines
+ debugging/profiling + package/export flow
```

The user should not begin with a blank assembler file and the burden of writing
a complete game engine. TECM8 should provide a fast engine, a project structure,
and asset preparation tools. The user writes small, meaningful Z80 routines that
control game behaviour.

## Core Thesis

The studio owns the structure. The user owns the behaviour.

The engine owns:

- the main loop
- frame timing
- input scanning
- TMS9918/VDU setup through the TECM8 display profile
- tile and room drawing
- sprite update scheduling
- actor iteration
- collision primitives
- sound ticking
- asset loading and unpacking
- room transitions
- package loading
- debug and profiling hooks

The user writes routines such as:

- actor init
- actor update
- actor touch/collision response
- room enter
- room tick
- trigger activation
- scoring rules
- enemy movement
- puzzle rules
- game-state transitions

This keeps the Z80 at the centre of the experience while removing accidental
complexity around graphics setup, sprite tables, map formats, loaders, and
distribution.

## Relationship To TECM8

This system should be a natural extension of TECM8, not a separate fantasy
computer.

TECM8 is already moving toward a ROM-based operating system with:

- a resident shell and project workflow
- banked tools for larger applications
- a BIOS/service boundary
- source editing, assembly, running, and later debugging
- future VDU/TMS9918 display profiles

The game creation system should fit that shape:

```text
TECM8 shell
  -> game project commands
  -> game builder/package tool
  -> native Z80 game runtime
  -> user AZM/Z80 routines
  -> VDU/TMS9918 and storage services
```

The game runtime should be a tool/runtime profile launched by TECM8. It should
use the same principles as the rest of the system: explicit contracts, small
stable service surfaces, banked code where size demands it, and runnable proof
targets in Debug80 before depending on hardware validation.

## Broader Runtime Framing

The game system should not be designed as a game engine that later grows random
application features. That direction would likely become messy.

The better frame is:

```text
Can the same studio + runtime + AZM routine model be generalised beyond games?
```

Yes. The game studio should be the first specialised profile of a broader TECM8
application creation model.

The generalisable pattern is:

```text
visual/resource editor
+ runtime services
+ object or event hooks
+ user-written AZM/Z80 routines
+ packaged output
```

For games, the nouns are:

- room
- actor
- sprite
- tile
- collision
- update
- touch
- spawn

For wider software, the nouns become:

- screen
- object
- widget
- document
- record
- command
- event
- file
- timer

The deep model stays the same. Only the profile vocabulary changes. A game
actor is a runtime object with state and event handlers. A button, menu item,
form field, text window, file entry, serial terminal, music pattern, or editor
buffer can use the same underlying idea.

## Frame Loop And Event Loop

Games are naturally frame-loop programs:

```text
read input
update actors
detect collisions
render
play sound
repeat
```

General applications are more naturally event-loop programs:

```text
wait for key/input/timer/file event
dispatch event to the current screen or object
update state
redraw changed parts
repeat
```

The long-term TECM8 runtime should support both modes:

```text
Runtime Kernel
  frame/tick loop        for games, demos, animation
  event loop             for apps, editors, and tools
  screen manager
  input manager
  file services
  text/graphics services
  object/event dispatcher
  AZM routine hooks
```

The first game slice does not need to implement this whole kernel. It should,
however, avoid choices that make the runtime impossible to generalise later.

## Object/Event Model Direction

The broader model is an object with state and event routines.

Game objects might include:

- player
- enemy
- bullet
- coin
- door

Application objects might include:

- button
- menu
- text field
- list
- cursor
- document
- serial port
- file entry

Potential object events include:

- init
- draw
- key
- select
- update or tick
- open
- close
- save
- load

A game actor may use `INIT`, `UPDATE`, `TOUCH`, and `DESTROY`. A menu item may
use `DRAW` and `SELECT`. A text editor buffer may use `OPEN`, `KEY`, `SAVE`,
and `DRAW`. A serial terminal may use `KEY`, `RX_BYTE`, `DRAW`, and `TIMER`.

The mechanism is the same:

```z80
SaveButton_Select:
    CALL API_SaveCurrentDocument
    RET
```

is conceptually the same as:

```z80
Coin_Touch:
    CALL API_AddScore
    CALL API_DestroyCurrentActor
    RET
```

The object changed. The hook model did not.

## Future Profiles

The mature system can become an integrated Z80 application studio with several
profiles:

- game profile
- text application profile
- utility application profile
- music/art profile
- card or hypertext profile
- development tool profile

The game profile should still come first. Games force the runtime to be fast,
small, and honest about machine limits. If TECM8 can support simple games, it
can likely support many screen-based utilities. The reverse is not guaranteed.

The broader system is strongest for software that is:

- screen-based
- event-driven
- resource-based
- stateful but compact
- educational
- interactive

Good later targets include music trackers, sprite editors, tile editors, map
editors, text adventures, calculators, serial terminals, simple card-file apps,
HyperCard-like stacks, menu utilities, file managers, disk tools, monitors,
debuggers, configuration tools, and teaching programs.

Harder targets include full word processors, large spreadsheets, large
databases, web-like document systems, complex compiler toolchains, multi-window
GUIs, large file editing, rich proportional text layout, and serious networking
applications. Those are not impossible, but the memory, display, and data
structure constraints become the main design problem.

## Non-Game Services Needed Later

To generalise beyond games, TECM8 will need services that ordinary game engines
often underemphasise:

- text drawing, text boxes, scrolling regions, cursors, input fields, wrapping,
  insert/delete helpers
- file and document operations for open, read, write, append, save, load, list,
  rename, and delete
- small UI objects such as menus, buttons, lists, text fields, dialogs, status
  bars, scrollable text areas, and file pickers
- fixed block, line buffer, document buffer, scratch buffer, resource handle,
  and bank/segment conventions
- command tables for actions such as new, open, save, quit, copy, paste, find,
  run, build, and export

These are not first-slice game requirements. They are the reason to keep the
game runtime cleanly layered rather than hard-wired to a single game shape.

## Why Not BASIC

BASIC was valuable because it was immediate, small, and approachable. It is a
poor centre for this particular goal because performant tile/sprite games need
control over timing, memory, graphics data, collision, and per-frame behaviour.

BASIC tends to push game authors toward:

- slow per-frame interpreted code
- ad hoc POKE/CALL patterns
- repeated reinvention of input, sprites, collision, and timing
- source-listing distribution rather than game packaging
- weak visibility into what the machine is actually doing

TECM8 should preserve the immediacy and learning value of BASIC, but replace
the programming model with one better suited to games:

```text
visual or structured assets + native engine + real Z80 behaviour routines
```

## Why Z80 Assembly Remains The Behaviour Language

The educational value is the point. A TECM8 game author should learn real
machine-code programming through visible game changes:

- registers
- flags
- conditional branches
- loops
- memory reads and writes
- tables and arrays
- routine calls
- calling conventions
- actor state
- hardware limits
- performance budgets

The code should not be toy code. It should move a player, steer an enemy, test
a wall, collect an item, update a score, or switch a room.

Example:

```z80
Player_Update:
    CALL API_GetInput

    BIT INPUT_LEFT,A
    CALL NZ,Player_MoveLeft

    BIT INPUT_RIGHT,A
    CALL NZ,Player_MoveRight

    BIT INPUT_FIRE,A
    CALL NZ,Player_Fire

    RET
```

Example:

```z80
Enemy_Update:
    LD A,(IX+ACTOR_X)
    DEC A
    LD (IX+ACTOR_X),A

    CALL API_TestWall
    RET Z

    CALL API_TurnActorAround
    RET
```

These routines are ordinary Z80. The important design constraint is that they
run inside a prepared runtime model with documented inputs, outputs, clobbers,
and allowed engine calls.

## Game-Writing Model

The user should write code in slots, not start by owning the whole program.

Initial routine slots should be deliberately small:

- actor init
- actor update
- actor touch
- room enter

Later routine slots can include:

- room tick
- trigger activate
- actor hit wall
- actor hit actor
- actor destroy
- menu/state update
- optional custom draw

Each slot needs a contract. A contract should state:

- when the engine calls the routine
- what pointer or context is active
- which registers contain arguments
- which registers may be clobbered
- what flags or return values mean
- which engine APIs are safe to call
- which memory areas belong to the routine, actor, room, or engine

The beginner-facing model can prefer clarity, even if some examples are not the
most cycle-perfect form. Expert paths can expose lower-level options once the
basic model works.

## Actor And Room Concepts

Games should be described in terms of rooms, actors, assets, and behaviour
routines.

An actor type is a definition:

- default sprite or animation
- init routine
- update routine
- touch routine
- default collision behaviour
- default flags and state bytes

An actor instance is a live object:

- active/inactive state
- type
- position
- sprite frame
- velocity or movement state
- collision bounds
- user state bytes
- timers and flags

Rooms should own:

- a tile map
- collision tags
- placed actors
- triggers
- exits or warps
- optional room-enter logic
- optional room-local state

This model should support the early game classes that naturally fit a
Z80/TMS9918 machine:

- maze collection games
- Tetris-like puzzle games
- Pac-Man-like maze games
- single-screen arcade games
- tile-based puzzle games
- top-down adventure rooms
- simple shooters
- demos

The first goal is not to support every possible game. The first goal is to make
the common tile/sprite path coherent.

## Engine API Direction

The runtime should expose stable game-facing APIs through documented symbols or
a jump table. The engine internals may change, but game code should call a
small contract surface.

Early API groups should cover:

- input state
- actor movement
- blocked movement against room collision
- tile collision queries
- actor spawn and destroy
- sound effect trigger placeholder
- score/counter or game variable helpers if useful
- room change placeholder

The API should use Z80-friendly register arguments for hot calls. Stack-style
formal parameters are not a good default for per-frame code on this CPU.

Every API needs:

- symbol name
- purpose
- inputs
- outputs
- carry/flag meaning
- clobber list
- preconditions
- examples

The API should be versioned early. Even if the first version is small, it should
be treated as a contract.

## Asset And Project Model

The mature system should include tools for:

- tile editing
- sprite editing
- animation editing
- map/room editing
- collision tagging
- actor placement
- sound effect editing
- music editing
- Z80 routine editing
- package building
- emulator/debugger launch
- export

The first implementation does not need the full visual studio. It can begin
with text, JSON, TOML, binary fixtures, or simple host-side conversion tools.
The important thing is to prove the flow:

```text
game project -> assets and routines -> assembled/packed output -> runnable game
```

A future project may look like:

```text
MyGame/
  game.toml
  src/
    actors/
    rooms/
    main.asm
  assets/
    tiles/
    sprites/
    maps/
    sound/
  build/
    mygame.bin
    mygame.tgc
    symbols.map
```

The exact file formats should follow implementation pressure. The separation of
engine, user routines, assets, manifest, and generated output is the important
part.

## Debugging And Transparency

The system should teach by showing what is happening.

Important debugger and inspection goals:

- run/pause
- step instruction
- step over calls
- break on a routine
- break on actor update
- inspect registers and flags
- inspect current actor
- inspect actor table
- inspect memory
- inspect sprite state
- inspect room/map state
- show source line where possible
- show symbols and listings
- show generated or lowered assembly if later AZM transforms are used

Performance should also be visible:

- active actor count
- sprite usage
- sprite scanline pressure
- tile and pattern usage
- estimated routine cycles where practical
- rough frame budget status
- VRAM update cost

Cycle estimates will be approximate, especially around branches, but even rough
feedback is educational.

## Safety And Modes

Raw Z80 can crash the runtime. That is acceptable for expert work, but poor for
the first learning path.

The system should offer a guided mode with warnings for common mistakes:

- missing `RET`
- clobbering preserved registers
- writing outside documented actor or game state
- disabling interrupts
- direct VDP access in guided routines
- using dangerous instructions in beginner-facing slots
- calling APIs from the wrong context

Expert mode should allow full machine access. The first version should prefer
warnings and documentation over hard sandboxing. Perfect sandboxing is not a
realistic goal for this kind of machine without changing the hardware model.

## Assembler Extensions Are Deferred

The original foundation note included substantial discussion of AZM structured
forms, AST transforms, branch helpers, loop helpers, actor field access helpers,
API-call lowering, register preservation helpers, and state-machine syntax.

Those ideas are valuable, but they are not the centre of this document.

For the game-writing mission, assume only:

- user behaviour routines are ordinary AZM/Z80 source
- engine symbols and constants are available to those routines
- routine contracts are documented clearly
- listings, symbols, and source maps are preserved where possible
- any future structured syntax must lower to inspectable Z80

The language ergonomics deserve their own design discussion after the first
runtime model is proven. The goal is "assembly with structure", not a disguised
high-level language.

## Non-Goals For The First Game Effort

The first game effort should not attempt:

- a complete visual IDE
- a complete music tracker
- advanced scrolling
- a perfect sandbox
- a full cartridge export system
- a complete Pac-Man clone
- a complete Tetris clone
- an online sharing platform
- a high-level language compiler
- a complex ECS architecture
- a separate operating system

The first effort should prove the model:

```text
native game runtime + AZM routines + assets + runnable output
```

## Next Document

The first buildable step is specified separately in
`docs/gamer-vertical-slice.md`.

That document should stay concrete and testable: a small maze collection game
that proves a tile map, a player actor, input, blocked movement, one collectible,
score/state update, assembly of user routines, linking with the runtime, and a
runnable Debug80 target.

## Long-Term Vision

The mature system should feel like a retro software creation studio for a
Z80/TMS9918-class TECM8 profile. Games are the first and most demanding path,
but the deeper idea is a structured Z80 application studio:

- assets are built visually or through structured tools
- object and event logic is written in real Z80
- runtime profiles provide fast common primitives
- the debugger makes the machine visible
- performance is part of the learning loop
- games and compact applications can be packaged, run, exported, shared, and
  remixed

The philosophical centre remains:

```text
Make real machine code approachable through structured, profile-driven creation,
with games as the first and most demanding profile.
```
