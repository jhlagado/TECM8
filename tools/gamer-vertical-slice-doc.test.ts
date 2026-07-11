const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const gameDoc = readFileSync(resolve(root, 'docs/game-register-contracts.md'), 'utf8');
const assemblerDoc = readFileSync(resolve(root, 'docs/tecmate-self-hosted-assembler.md'), 'utf8');
const abiDoc = readFileSync(resolve(root, 'docs/mon3/tecmate-banked-service-abi.md'), 'utf8');

test('game/profile direction uses general TecMate runtime services', () => {
  assert.match(gameDoc, /Game-specific conventions must not weaken the general TecMate ABI/);
  assert.match(gameDoc, /documented TecMate BIOS services/);
  assert.match(gameDoc, /documented VDU\/TMS9918 services/);
  assert.match(gameDoc, /documented TEC-FS services/);
  assert.match(assemblerDoc, /TFS_FORMAT_META_RECORD/);
  assert.match(abiDoc, /TFS_FORMAT_META_RECORD/);
});

test('game/profile API contracts do not clobber returned carriers', () => {
  assert.match(gameDoc, /\.routine out A clobbers zero,sign,parity,halfCarry[\s\S]*API_GetInput:/);
  assert.match(gameDoc, /\.routine in IX,B,C out carry clobbers A,B,C,D,E,H,L,zero,sign,parity,halfCarry[\s\S]*API_MoveActorBlocked:/);
  assert.doesNotMatch(gameDoc, /clobbers AF/);
});

test('game/profile API contracts keep input-only accumulator calls free to clobber A', () => {
  assert.match(gameDoc, /\.routine in A clobbers A,H,L,zero,sign,parity,halfCarry[\s\S]*API_AddScore:/);
  assert.match(gameDoc, /\.routine in A clobbers A,zero,sign,parity,halfCarry[\s\S]*API_PlaySound:/);
});
