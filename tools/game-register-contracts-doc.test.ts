const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const doc = readFileSync(resolve(root, 'docs/game-register-contracts.md'), 'utf8');

function assertMentionsAll(texts: string[]): void {
  for (const text of texts) {
    assert.match(doc, new RegExp(text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  }
}

test('game register contracts doc keeps register-first convention explicit', () => {
  assert.match(doc, /Register arguments are the default for hot game APIs/);
  assert.match(doc, /Stack arguments are not the normal API style for per-frame game code/);
  assert.match(doc, /Game-specific conventions must not weaken the general TecMate ABI/);
  assert.match(doc, /`IX` should be preserved across beginner-facing actor hooks/);
  assert.match(doc, /`IY` should remain preserved until the runtime\s+has a documented use/);
});

test('game register contracts doc defines draft register roles and hook contracts', () => {
  assertMentionsAll([
    '| `A` | Small value input/output, status, input bitfield, score amount, sound id. |',
    '| `B` | Small signed or unsigned argument, commonly `dx`. |',
    '| `C` | Small signed or unsigned argument, commonly `dy`, or a service selector when calling TecMate BIOS services. |',
    '| `IX` | Current actor pointer for beginner-facing actor hooks. |',
    '| `IY` | Reserved until a later runtime contract assigns it. |',
    'Actor update hook, v1 convention',
    '.routine in IX clobbers A,B,C,D,E,H,L,zero,sign,parity,halfCarry',
    'Player_Update:',
    'Actor touch hook, v1 convention',
    '.routine in IX,HL clobbers A,B,C,D,E,H,L,zero,sign,parity,halfCarry',
    'Actor_Touch:',
  ]);
});

test('game register contracts doc covers first runtime API contract examples', () => {
  assertMentionsAll([
    'API_GetInput:',
    '.routine out A clobbers zero,sign,parity,halfCarry',
    'API_MoveActorBlocked:',
    '.routine in IX,B,C out carry clobbers A,B,C,D,E,H,L,zero,sign,parity,halfCarry',
    'API_DestroyCurrentActor:',
    'API_AddScore:',
    '.routine in A clobbers A,H,L,zero,sign,parity,halfCarry',
    'API_PlaySound:',
    '.routine in A clobbers A,zero,sign,parity,halfCarry',
    '`API_MoveActorBlocked` uses `IX` as actor pointer, `B` as signed `dx`, and `C`',
    'Carry clear means movement was applied. Carry set means movement',
  ]);
  assert.doesNotMatch(doc, /.routine clobbers AF/);
});

test('game register contracts doc keeps game runtime layered on TecMate services', () => {
  assert.match(doc, /Game code should not call private bank labels directly/);
  assertMentionsAll([
    'documented game runtime APIs',
    'documented TecMate BIOS services',
    'documented VDU/TMS9918 services',
    'documented input services once they exist',
    'documented TEC-FS services for project/data loading when required',
  ]);
  assert.match(doc, /The self-hosted assembler does not need to enforce these contracts at first/);
  assert.match(doc, /eventually parse and preserve them/);
});
