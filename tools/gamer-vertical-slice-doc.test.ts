const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const doc = readFileSync(resolve(root, 'docs/gamer-vertical-slice.md'), 'utf8');

test('gamer vertical slice uses general TecMate runtime services', () => {
  assert.match(doc, /## Runtime Contract/);
  assert.match(doc, /first game profile should be a user of TecMate services/);
  assert.match(doc, /`VDU_SVC_STATUS_LINE`[\s\S]*Show build\/run\/debug status/);
  assert.match(doc, /`INP_READ`[\s\S]*matrix-keyboard and joystick state/);
  assert.match(doc, /`TFS_FORMAT_META_RECORD`[\s\S]*blank metadata record[\s\S]*patches with type, load\/run, and hardware fields/);
  assert.match(doc, /assembler artifact convention[\s\S]*`\.asm`, `\.bin`, and `\.map`/);
  assert.match(doc, /should not define separate game-only storage, input, or status/);
  assert.match(doc, /`TFS_FILE_GAME` or\s+`TFS_FILE_BINARY` metadata record/);
  assert.match(doc, /`TFS_META_FLAG_EXECUTABLE`/);
  assert.match(doc, /`TFS_META_HW_TMS9918` and `TFS_META_HW_JOYSTICK`/);
  assert.match(doc, /`TFS_FORMAT_META_RECORD` supplies the blank `TFM1` record/);
  assert.match(doc, /game build\s+tool must then write `TFS_META_OFFSET_FILE_TYPE`/);
});

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
