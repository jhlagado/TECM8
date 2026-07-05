const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const doc = readFileSync(resolve(root, 'docs/vdu-tms-minimum-primitives.md'), 'utf8');

test('VDU/TMS minimum primitives doc keeps the display layer scoped', () => {
  assert.match(doc, /compact display layer/);
  assert.match(doc, /TMS9918-style VDU/);
  assert.match(doc, /not a game engine and not a general graphics library/);
  assert.match(doc, /minimum\s+service surface/);
});

test('VDU/TMS minimum primitives doc matches current bank 1 service families', () => {
  const ops = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank_ops.asmi'), 'utf8');
  const bank1 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank1.asm'), 'utf8');

  assert.match(doc, /VDU text services from `VDU_SVC_INIT` through `VDU_SVC_PUT_STRING_N`/);
  assert.match(doc, /raw TMS services from `TMS_SVC_INIT` through `TMS_SVC_READ_VRAM`/);
  assert.match(doc, /`VDU_INIT` as the public service\s+ID/);
  assert.match(doc, /routes that request to `VDU_ADDR`/);
  assert.match(doc, /`VDU_CALL` at `VDU_ENTRY`/);
  assert.match(doc, /bank-local selector\s+`VDU_SVC_INIT` in `A`/);
  assert.match(ops, /VDU_INIT\s+\.equ\s+SVC_BASE\+0x00/);
  assert.match(ops, /VDU_SVC_STATUS_LINE\s+\.equ\s+0x09/);
  assert.match(ops, /VDU_SVC_PUT_STRING_N\s+\.equ\s+0x0A/);
  assert.match(ops, /TMS_SVC_READ_VRAM\s+\.equ\s+0x24/);
  assert.match(bank1, /@vduServiceCall:/);
  assert.match(bank1, /Tecm8VduServiceTable:/);
  assert.match(bank1, /Tecm8TmsServiceTable:/);
});

test('VDU/TMS minimum primitives doc records parameter block fields', () => {
  for (const symbol of [
    'TMS_PARAM_VALUE',
    'TMS_PARAM_REGISTER',
    'TMS_PARAM_ADDR_LO',
    'TMS_PARAM_ADDR_HI',
    'TMS_PARAM_CURSOR_LO',
    'TMS_PARAM_CURSOR_HI',
    'TMS_PARAM_STRING_LO',
    'TMS_PARAM_STRING_HI',
    'TMS_PARAM_COUNT_LO',
    'TMS_PARAM_COUNT_HI',
    'TMS_PARAM_ROW',
    'TMS_PARAM_COL',
  ]) {
    assert.match(doc, new RegExp(symbol));
  }
});

test('VDU/TMS minimum primitives doc reserves a small text and raw VRAM surface', () => {
  for (const phrase of [
    'initialize the VDU',
    'clear the 32x24 name table',
    'set cursor by VRAM address',
    'set cursor by row and column',
    'put one character',
    'put a zero-terminated string',
    'put a bounded string',
    'advance to the next line',
    'scroll the visible text area up',
    'write a short status line',
    'perform the small current TMS initialization path',
    'set a TMS register',
    'write one VRAM byte',
    'fill a VRAM range',
    'read one VRAM byte',
  ]) {
    assert.match(doc, new RegExp(phrase));
  }
  assert.match(doc, /does not read\s+`TMS_PARAM_COUNT_LO\/HI`/);
  assert.match(doc, /stops at\s+the first zero byte or after the requested\s+number of bytes/);
});

test('VDU/TMS minimum primitives doc keeps GLCD out of the first VDU contract', () => {
  assert.match(doc, /New display work should be judged against the ROM footprint budget/);
  assert.match(doc, /Avoid adding a broad graphics library/);
  assert.match(doc, /GLCD support should not drive this bank's design/);
  assert.match(doc, /separate optional service/);
  assert.match(doc, /should not pull MON3 GLCD terminal policy\s+into the TMS-facing VDU contract/);
});
