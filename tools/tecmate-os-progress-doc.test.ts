const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const doc = readFileSync(resolve(root, 'docs/mon3/tecmate-os-progress.md'), 'utf8');

test('TecMate OS progress note records current first-loop banked services', () => {
  assert.match(doc, /TecMate shell one-command classifier/);
  assert.match(doc, /input snapshot boundary/);
  assert.match(doc, /formats a blank\s+`TFM1` metadata record/);
  assert.match(doc, /file type, flags, load address,\s+end address, run address, required hardware/);
  assert.match(doc, /`SHL_RUN_COMMAND`/);
  assert.match(doc, /documented result-code convention/);
  assert.match(doc, /cursor-preserving status line/);
  assert.match(doc, /input snapshot service for matrix keyboard and joystick state/);
});

test('TecMate OS progress note records current expansion footprint', () => {
  assert.match(doc, /144K total expansion image/);
  assert.match(doc, /2010 occupied bytes currently/);
  assert.match(doc, /2010 bytes total high-water span across all banks/);
});

test('TecMate OS progress note keeps game work behind general services', () => {
  assert.match(doc, /connect the shell result convention,\s+assembler artifact convention, TEC-FS metadata record/);
  assert.match(doc, /games are a proving profile for the general\s+TecMate services rather than a separate platform/);
});
