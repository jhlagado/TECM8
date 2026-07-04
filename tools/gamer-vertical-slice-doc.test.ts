const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const doc = readFileSync(resolve(root, 'docs/gamer-vertical-slice.md'), 'utf8');

test('gamer vertical slice API contracts do not clobber returned carriers', () => {
  assert.match(doc, /### API_GetInput[\s\S]*Output:\n  A = input bitfield[\s\S]*Clobbers:\n  zero, sign, parity, halfCarry/);
  assert.match(doc, /### API_MoveActorBlocked[\s\S]*Output:\n  carry clear if movement applied[\s\S]*Clobbers:\n  A, B, C, D, E, H, L, zero, sign, parity, halfCarry/);
  assert.doesNotMatch(doc, /### API_GetInput[\s\S]*Clobbers:\n  AF/);
  assert.doesNotMatch(doc, /### API_MoveActorBlocked[\s\S]*Clobbers:\n  AF, BC, DE, HL/);
});

test('gamer vertical slice API contracts keep input-only accumulator calls free to clobber A', () => {
  assert.match(doc, /### API_AddScore[\s\S]*Input:\n  A = amount to add[\s\S]*Clobbers:\n  A, H, L, zero, sign, parity, halfCarry/);
  assert.match(doc, /### API_PlaySound[\s\S]*Input:\n  A = sound id[\s\S]*Clobbers:\n  A, zero, sign, parity, halfCarry/);
});
