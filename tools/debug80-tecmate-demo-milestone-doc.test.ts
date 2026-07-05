const { existsSync, readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const docPath = resolve(root, 'docs/debug80-tecmate-demo-milestone.md');
const doc = readFileSync(docPath, 'utf8');

test('Debug80 TecMate demo milestone document exists and scopes the demo', () => {
  assert.equal(existsSync(docPath), true);
  assert.match(doc, /boot a TEC-1G Debug80\s+session using the project-owned monitor and expansion ROMs/);
  assert.match(doc, /make the new ROM architecture observable as a small runnable system/);
  assert.match(doc, /fixed monitor ROM at `C000h-FFFFh`/);
  assert.match(doc, /banked expansion image in the `8000h-BFFFh` window/);
});

test('Debug80 TecMate demo milestone defines observable service flow', () => {
  assert.match(doc, /MON3-compatible monitor startup path/);
  assert.match(doc, /TecMate entry/);
  assert.match(doc, /bank 0 shell\/demo loop/);
  assert.match(doc, /visible VDU\/TMS output/);
  assert.match(doc, /input snapshot read/);
  assert.match(doc, /TEC-FS service boundary touched/);
  assert.match(doc, /shell status\/result shown/);
});

test('Debug80 TecMate demo milestone has concrete acceptance criteria', () => {
  for (const phrase of [
    '`npm run rom:check` builds the project-owned monitor and expansion ROMs',
    'Debug80 launches those ROM artifacts through the TECM8 profile',
    'monitor discovery path installs the bank 0 menu/service vectors',
    'TecMate entry path reaches bank 0 without direct fixed-address coupling',
    'writes visible text through the VDU/TMS service boundary',
    'reads the bank 6 input snapshot boundary',
    'calls the bank 2 TEC-FS boundary',
    'final Debug80 trace or screen state proves success',
    '`npm run rom:size:summary` is recorded with before/after footprint deltas',
  ]) {
    assert.match(doc, new RegExp(phrase.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  }
});

test('Debug80 TecMate demo milestone is backed by the monitor launch proof', () => {
  const runner = readFileSync(resolve(root, 'tools/run-tecmate-monitor-launch-proof.ts'), 'utf8');
  const bank0 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank0.asm'), 'utf8');

  assert.match(bank0, /call Tecm8BootstrapVdu[\s\S]*call Tecm8BootstrapTecfs[\s\S]*call Tecm8BootstrapInput[\s\S]*call Tecm8BootstrapShell/);
  assert.match(bank0, /Tecm8BootstrapInput:[\s\S]*callService INP_READ[\s\S]*ld \(DBG_TRACE_7\),a/);
  assert.match(bank0, /Tecm8BootstrapShell:[\s\S]*callService RTC_TOOL[\s\S]*callService SHL_ENTRY[\s\S]*ld \(DBG_TRACE_8\),a/);
  assert.match(runner, /assertDemoVram/);
  assert.match(runner, /demo TMS9918 device active/);
  assert.match(runner, /demo VDU first splash character/);
  assert.match(runner, /demo input neutral joystick state/);
  assert.match(runner, /demo TEC-FS mount side effect/);
});

test('Debug80 TecMate demo milestone keeps scope small', () => {
  assert.match(doc, /full TEC-FS catalogue, allocator, file load, or file save/);
  assert.match(doc, /a real assembler/);
  assert.match(doc, /a complete editor loop/);
  assert.match(doc, /a game runtime/);
  assert.match(doc, /GLCD feature work/);
  assert.match(doc, /direct boot into TecMate as the final product policy/);
});
