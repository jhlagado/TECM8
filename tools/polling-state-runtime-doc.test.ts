const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const doc = readFileSync(resolve(root, 'docs/polling-state-runtime.md'), 'utf8');

test('polling state runtime defines the cooperative loop', () => {
  assert.match(doc, /cooperative polling model/);
  assert.match(doc, /poll input and timers[\s\S]*update state records[\s\S]*set dirty masks[\s\S]*run routine slots[\s\S]*redraw dirty regions/);
  assert.match(doc, /closer to a game loop than a desktop event system/);
  assert.match(doc, /ordinary programming model should not depend on interrupt-driven\s+application callbacks/);
});

test('polling state runtime uses compact records and coarse dirty masks', () => {
  assert.match(doc, /A state record is a compact block of bytes/);
  assert.match(doc, /profile decides the record layout and\s+generates offsets/);
  assert.match(doc, /does not need a dirty flag\s+for every variable/);
  assert.match(doc, /dirty bits at the level that avoids waste/);
  assert.match(doc, /does not need a spreadsheet engine or a full dependency graph/);
});

test('polling state runtime keeps routine slots explicit and register-first', () => {
  assert.match(doc, /Routine slots are named calls made by the profile runtime/);
  assert.match(doc, /not hidden\s+event handlers/);
  assert.match(doc, /Direct tables and\s+ordinary calls are preferred over a general event queue/);
  assert.match(doc, /Routine slots should prefer register arguments/);
  assert.match(doc, /return status through `A` and carry/);
});

test('polling state runtime rejects heavy desktop abstractions as first-version defaults', () => {
  assert.match(doc, /default object orientation/);
  assert.match(doc, /automatic event bubbling/);
  assert.match(doc, /per-variable dirty history for every value/);
  assert.match(doc, /general dependency solving/);
  assert.match(doc, /hidden scheduler/);
});
