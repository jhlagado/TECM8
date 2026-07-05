const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const doc = readFileSync(resolve(root, 'docs/mon3/tecmate-os-progress.md'), 'utf8');

test('TecMate OS progress note records current first-loop banked services', () => {
  assert.match(doc, /TecMate shell one-command classifier/);
  assert.match(doc, /input snapshot boundary/);
  assert.match(doc, /run service skeleton/);
  assert.match(doc, /formats a blank\s+`TFM1` metadata record/);
  assert.match(doc, /file type, flags, load address,\s+end address, run address, required hardware/);
  assert.match(doc, /`SHL_RUN_COMMAND`/);
  assert.match(doc, /documented result-code\s+convention/);
  assert.match(doc, /clears the TMS9918 text plane/);
  assert.match(doc, /visible `TecMate ROM Shell`\s+screen/);
  assert.match(doc, /current TEC-FS geometry as `TFS:30\+1 128M 4K`/);
  assert.match(doc, /current input snapshot as `KEY:0000 JOY:00`/);
  assert.match(doc, /shows the prompt\s+marker/);
  assert.match(doc, /cursor-preserving status line/);
  assert.match(doc, /input snapshot service for matrix keyboard and joystick state/);
});

test('TecMate OS progress note records current expansion footprint', () => {
  assert.match(doc, /144K total expansion image/);
  assert.match(doc, /2666 occupied bytes currently/);
  assert.match(doc, /2666 bytes total high-water span across all banks/);
  assert.match(doc, /TEC-FS geometry-line milestone reduced the footprint by 2 bytes/);
  assert.match(doc, /bank 0 span: 997 -> 995 bytes/);
  assert.match(doc, /expansion total span: 2668 -> 2666 bytes/);
  assert.match(doc, /fixed monitor span: unchanged at 16384 bytes/);
});

test('TecMate OS progress note keeps game work behind general services', () => {
  assert.match(doc, /connect the shell result convention,\s+assembler artifact convention, TEC-FS metadata record/);
  assert.match(doc, /games are a proving profile for the general\s+TecMate services rather than a separate platform/);
});
