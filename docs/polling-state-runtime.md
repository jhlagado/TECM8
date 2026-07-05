# TecMate Polling State Runtime

TecMate interactive programs should start from a cooperative polling model. The
main loop owns progress: it polls inputs, updates compact state records, marks
dirty state, redraws what changed, and returns to the loop.

This is deliberately closer to a game loop than a desktop event system. The
TEC-1G has no mouse, no window manager, and very little memory. A small polling
runtime is easier to inspect, debug, and fit into ROM.

```text
poll input and timers
update state records
set dirty masks
run routine slots
redraw dirty regions
repeat
```

Interrupts may still exist below this level for timing or hardware service
work, but the ordinary programming model should not depend on interrupt-driven
application callbacks.

## State Records

A state record is a compact block of bytes owned by an actor, room, card,
control, editor buffer, menu, or tool. The profile decides the record layout and
generates offsets. Behaviour routines receive enough context to update the
record without discovering layout at runtime.

For the first game profile, the common records are likely:

- actor instance record
- actor type table
- room record
- sprite/resource table
- input snapshot
- frame or tick state

For later card-like or tool profiles, the same model can describe fields,
menus, command state, editor buffers, or terminal state.

## Dirty Masks

Dirty state should be explicit and cheap. A program does not need a dirty flag
for every variable. It needs dirty bits at the level that avoids waste:

- input snapshot changed
- actor moved
- actor sprite changed
- room entered
- text field changed
- status line changed
- resource or file state changed
- full redraw required

The profile may generate dirty-bit constants and helper tables, but behaviour
code remains free to set and clear those bits directly.

For simple dependencies, such as `C = A + B`, the update routine can check
whether `A` or `B` is dirty, recompute `C`, mark `C` dirty, and return. TecMate
does not need a spreadsheet engine or a full dependency graph to support this
first version.

## Routine Slots

Routine slots are named calls made by the profile runtime. They are not hidden
event handlers. The loop decides when a slot is called.

Game-oriented slots may include:

- `Actor_Init`
- `Actor_Update`
- `Actor_Touch`
- `Room_Enter`
- `Room_Draw`
- `Frame_Begin`
- `Frame_End`

Tool-oriented slots may later include:

- `Screen_Open`
- `Screen_Update`
- `Screen_DrawDirty`
- `Control_Activate`
- `Buffer_Save`
- `Timer_Step`

The first implementation should keep the dispatcher simple. Direct tables and
ordinary calls are preferred over a general event queue.

## Register-First Calling

Routine slots should prefer register arguments for hot paths. A typical slot
can receive a record pointer, selector, or input snapshot in registers and
return status through `A` and carry where that matches the wider TecMate ABI.

Stack arguments are not forbidden, but they should be reserved for cold paths,
large parameter blocks, or tools where clarity matters more than frame cost.

## Non-Goals

- default object orientation
- automatic event bubbling
- per-variable dirty history for every value
- general dependency solving
- a hidden scheduler that makes control flow hard to debug
- interrupt-driven application callbacks as the normal user model

