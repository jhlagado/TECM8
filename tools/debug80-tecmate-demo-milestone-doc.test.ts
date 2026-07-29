const { existsSync, readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const docPath = resolve(root, 'docs/debug80-tecmate-demo-milestone.md');
const doc = readFileSync(docPath, 'utf8');
const pkg = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8'));

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

test('Debug80 TecMate demo milestone defines the ROM demo command', () => {
  assert.equal(
    pkg.scripts['demo:tecmate-rom'],
    'npm run rom:check && node --experimental-strip-types tools/run-tecmate-monitor-launch-proof.ts && node --experimental-strip-types tools/check-rom-size-budget.ts --summary',
  );
  assert.match(doc, /## ROM Demo Command/);
  assert.match(doc, /npm run demo:tecmate-rom/);
  assert.match(doc, /npm run checkpoint:tecmate-rom/);
  assert.match(doc, /npm run rom:milestone:status/);
  assert.match(doc, /builds the TECM8 fixed monitor ROM/);
  assert.match(doc, /runs the Debug80 monitor-launch proof/);
  assert.match(doc, /prints the ROM size\s+summary/);
  assert.match(doc, /compact command matrix, and current ROM footprint/);
  assert.match(doc, /reports the current fixed-monitor\s+and expansion-bank footprint/);
  assert.match(doc, /monitor launch,\s+the shell command loop, VDU\/TMS9918, TEC-FS, input snapshot, and bank ABI/);
  assert.match(doc, /not the older GLCD editor demo path/);
});

test('Debug80 TecMate demo milestone records the manual ROM launch script', () => {
  assert.match(doc, /## Manual Debug80 Script/);
  assert.match(doc, /monitor ROM: `build\/roms\/tec1g\/tecm8\/monitor\/monitor\.bin`/);
  assert.match(doc, /expansion ROM: `build\/roms\/tec1g\/tecm8\/expansion\/expansion-144k\.bin`/);
  assert.match(doc, /`main` target may still compile the older\s+`src\/main\.asm` RAM program/);
  assert.match(doc, /use Debug80 only to inspect\s+the generated ROM artifacts/);
  assert.match(doc, /Do not start a RAM\s+program at `4000h`/);
  assert.match(doc, /Enter the monitor `Expansion` menu item/);
  assert.match(doc, /`TecMate ROM Shell` title, `TFS:30\+1 128M 4K` TEC-FS geometry line,\s+`KEY:0000 JOY:00` input echo, `>` prompt, and `POLL` status text/);
  assert.match(doc, /first input\/update\/render\s+loop slice/);
  assert.match(doc, /initial command matrix to show/);
  assert.match(doc, /`edit -> EDIT\/OK`, `asm -> ASM\/BUILD`, `run -> RUN\/FILE`,\s+`dir -> DIR\/OK`, and `dir bad-buffer -> FILE`/);
});

test('Debug80 TecMate demo milestone records the completed persistent editor workflow', () => {
  assert.match(doc, /## Completed Persistent Editor Workflow/);
  assert.match(doc, /shell `edit`[\s\S]*interactive bank-4 editor and bank-6 key service/);
  assert.match(doc, /multi-page 32-byte-record source workspace/);
  assert.match(doc, /bank-2 data-sector writes followed by a metadata-sector commit/);
  assert.match(doc, /solid-block character cursor/);
  assert.match(doc, /record split\/join/);
  assert.match(doc, /reopens to prove the saved `PAGEY` record persisted/);
});

test('Debug80 TecMate demo milestone records the complete build-and-run workflow', () => {
  assert.match(doc, /## Completed Self-Hosted Build-And-Run Workflow/);
  assert.match(doc, /asm reports BUILD at source record 4/);
  assert.match(doc, /edit reopens at record 4, column 2/);
  assert.match(doc, /asm emits 3E 5A 32 F0 4F C9 and TMAP/);
  assert.match(doc, /two artifact data writes and two metadata writes/);
  assert.match(doc, /run loads at 4000h, executes the marker write, and returns to the shell/);
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
    '`npm run checkpoint:tecmate-rom` is recorded with before/after footprint',
    '`npm run rom:milestone:status` reports `ok` for the integrated ROM proof',
  ]) {
    assert.match(doc, new RegExp(phrase.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  }
  assert.match(doc, /monitor launch, shell command loop, VDU\/TMS9918, TEC-FS, input\s+snapshot, and bank ABI/);
});

test('Debug80 TecMate demo milestone is backed by the monitor launch proof', () => {
  const runner = readFileSync(resolve(root, 'tools/run-tecmate-monitor-launch-proof.ts'), 'utf8');
  const bank0 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank0.asm'), 'utf8');

  assert.match(bank0, /call Tecm8BootstrapVdu[\s\S]*call Tecm8BootstrapTecfs[\s\S]*call Tecm8BootstrapInput[\s\S]*call Tecm8BootstrapShell/);
  assert.match(bank0, /Tecm8BootstrapInput:[\s\S]*callService INP_READ[\s\S]*ld \(DBG_TRACE_7\),a/);
  assert.match(bank0, /Tecm8BootstrapShell:[\s\S]*callService RTC_TOOL[\s\S]*callService SHL_ENTRY[\s\S]*ld \(DBG_TRACE_8\),a/);
  assert.match(runner, /assertDemoVram/);
  assert.match(runner, /demo TMS9918 device active/);
  assert.match(runner, /demo TEC-FS geometry line/);
  assert.match(runner, /demo input echo/);
  assert.match(runner, /demo prompt/);
  assert.match(runner, /demo input neutral joystick state/);
  assert.match(runner, /demo TEC-FS mount side effect/);
});

test('Debug80 TecMate demo milestone keeps scope small', () => {
  assert.match(doc, /full TEC-FS catalogue allocator beyond the bounded editor source workflow/);
  assert.match(doc, /complete Z80\/AZM language beyond the documented phase-one subset/);
  assert.match(doc, /unbounded files larger than the three-page ROM workspace/);
  assert.match(doc, /a game runtime/);
  assert.match(doc, /GLCD feature work/);
  assert.match(doc, /direct boot into TecMate as the final product policy/);
});
