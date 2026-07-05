const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const doc = readFileSync(resolve(root, 'docs/input-polling-abi.md'), 'utf8');

test('input polling ABI keeps the application model polling based', () => {
  assert.match(doc, /cooperative polling service/);
  assert.match(doc, /not an interrupt-driven\s+application callback system/);
  assert.match(doc, /read one input snapshot during their main loop/);
  assert.match(doc, /matrix keyboard/);
  assert.match(doc, /hex keypad/);
  assert.match(doc, /optional joystick or game panel/);
});

test('input polling ABI records current and future snapshot fields', () => {
  for (const symbol of [
    'INP_PARAM_STATUS',
    'INP_PARAM_LAST_ERROR',
    'INP_PARAM_BANK',
    'INP_PARAM_VERSION',
    'INP_PARAM_KEYS_LO',
    'INP_PARAM_KEYS_HI',
    'INP_PARAM_JOYSTICK',
    'INP_PARAM_MODIFIERS',
  ]) {
    assert.match(doc, new RegExp(symbol));
  }

  assert.match(doc, /previous key and joystick state/);
  assert.match(doc, /pressed-edge and released-edge bitfields/);
  assert.match(doc, /raw matrix diagnostics/);
  assert.match(doc, /input-changed or dirty flag/);
});

test('input polling ABI matches the current bank 6 proof boundary', () => {
  const ops = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank_ops.asmi'), 'utf8');
  const runner = readFileSync(resolve(root, 'tools/run-input-bank-proof.ts'), 'utf8');

  assert.match(doc, /public expansion service is `INP_READ`/);
  assert.match(doc, /bank-local selector passed to bank 6 is\s+`INP_SVC_READ`/);
  assert.match(doc, /bank 6/);
  assert.match(doc, /`A = 86h`, carry\s+clear/);
  assert.match(doc, /neutral key and joystick\s+fields/);
  assert.match(doc, /`KEY:0000 JOY:00` on the TMS9918 screen/);
  assert.match(doc, /visible debug\/status echo of\s+the parameter block/);
  assert.match(ops, /INP_READ\s+\.equ\s+SVC_BASE\+0x04/);
  assert.match(ops, /INP_SVC_READ\s+\.equ\s+0x01/);
  assert.match(ops, /INP_PARAM_JOYSTICK/);
  assert.match(runner, /'input service bank'/);
  assert.match(runner, /'input joystick bitfield'/);
});

test('input polling ABI keeps hardware details behind services', () => {
  assert.match(doc, /register-first for hot paths/);
  assert.match(doc, /parameter-block state for shared snapshots and diagnostics/);
  assert.match(doc, /`A` plus carry for small status results/);
  assert.match(doc, /no direct hardware parsing by profile\/game\/application code/);
  assert.match(doc, /neutral bitfield when it is absent/);
});
