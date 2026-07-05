const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const doc = readFileSync(resolve(root, 'docs/profile-preprocessor-contract.md'), 'utf8');

test('profile preprocessor contract keeps profiles optional above ordinary assembly', () => {
  assert.match(doc, /profiles are optional project shapers/);
  assert.match(doc, /generate ordinary AZM-compatible source/);
  assert.match(doc, /do not replace the assembler/);
  assert.match(doc, /hand-written AZM\/Z80 source[\s\S]*AZM or TecMate assembler/);
  assert.match(doc, /profile source[\s\S]*generated AZM\/Z80 source and resources[\s\S]*AZM or TecMate assembler/);
});

test('profile preprocessor contract protects inspectability and general-purpose use', () => {
  assert.match(doc, /profile-generated programs, monitor code, ROM tools, diagnostics,\s+utilities, and hand-written applications/);
  assert.match(doc, /emit inspectable assembly that can be traced back to the\s+profile source/);
  assert.doesNotMatch(doc, /listed equivalent/);
  assert.match(doc, /must not require a hidden bytecode interpreter/);
  assert.match(doc, /Behaviour routines should be real Z80/);
  assert.match(doc, /same TecMate BIOS, shell, VDU,\s+input, TEC-FS, and debugger contracts/);
  assert.match(doc, /Debug80 maps and source\s+debugging/);
});

test('profile preprocessor contract scopes the first profile without making TecMate game-only', () => {
  assert.match(doc, /games stress the\s+display, input, timing, resource, and debugging surfaces/);
  assert.match(doc, /does not make\s+TecMate a game-only system/);
  assert.match(doc, /actors, rooms, sprites, maps, and other game-specific records/);
  assert.match(doc, /routine slots such as `Actor_Init`, `Actor_Update`, `Actor_Touch`, and\s+`Room_Enter`/);
  assert.doesNotMatch(doc, /screens, rooms, cards/);
  assert.doesNotMatch(doc, /`KEY_STEP`/);
  assert.match(doc, /Out Of Scope For The First Version/);
  assert.match(doc, /a general scripting language/);
  assert.match(doc, /dynamic event dispatch as the default model/);
  assert.match(doc, /opaque runtime that hides the generated assembly/);
});
