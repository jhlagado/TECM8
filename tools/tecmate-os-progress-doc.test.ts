const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const doc = readFileSync(resolve(root, 'docs/mon3/tecmate-os-progress.md'), 'utf8');

test('TecMate OS progress note records current first-loop banked services', () => {
  assert.match(doc, /TecMate shell one-command classifier/);
  assert.match(doc, /input snapshot boundary/);
  assert.match(doc, /validated artifact loader and runner/);
  assert.match(doc, /formats a blank\s+`TFM1` metadata record/);
  assert.match(doc, /file type, flags, load address,\s+end address, run address, required hardware/);
  assert.match(doc, /`SHL_RUN_COMMAND`/);
  assert.match(doc, /classifies exact `edit`, `asm`, `run`, and `dir` commands/);
  assert.match(doc, /`dir` leaves the target pointer and flags clear, calls the bank-2 TEC-FS\s+catalogue summarizer/);
  assert.match(doc, /Build errors carry a source record/);
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
  assert.match(doc, /15217 occupied bytes currently/);
  assert.match(doc, /15703 bytes total high-water span across all banks/);
  assert.match(doc, /self-hosted build-and-run milestone keeps the expansion footprint bounded/);
  assert.match(doc, /bank 0 span: unchanged at 1320 bytes/);
  assert.match(doc, /bank 2 span: 1531 -> 2025 bytes/);
  assert.match(doc, /bank 7 span: 45 -> 2173 bytes/);
  assert.match(doc, /expansion total span: 6283 -> 9313 bytes/);
  assert.match(doc, /fixed monitor span: unchanged at 16384 bytes/);
  assert.match(doc, /latest implementation loop completed the self-hosted build-and-run path/);
  assert.match(doc, /unknown shell commands are now proof-backed as `ERRCMD` \/ `NONE`/);
  assert.match(doc, /shell checkpoint matrix is pinned as the current command surface/);
  assert.match(doc, /TEC-FS saves write resident data pages first and commit catalogue metadata/);
  assert.match(doc, /ROM editor uses a three-page source workspace on the VDU\/TMS9918 path/);
  assert.match(doc, /bank 0 is guarded as an exact-word classifier and dispatcher/);
  assert.match(doc, /size gate now prints per-bank soft-budget headroom/);
  assert.match(doc, /manual demo path is `edit` -> interactive editor -> bank-6 keys/);
  assert.match(doc, /TEC-FS services are classified as implemented proof services,\s+stubbed\/reserved services, and deferred filesystem work/);
  assert.match(doc, /bank 7 assembles the resident source records in two passes/);
  assert.match(doc, /bank 8 validates a `4000h-4FFFh` executable/);
  assert.match(doc, /integrated Debug80 proof performs edit, save, diagnose, fix, rebuild/);
  assert.match(doc, /fixed monitor span: 16384\/16384 bytes/);
  assert.match(doc, /bank 0 span: 2015 bytes, softFree=33/);
  assert.match(doc, /bank 2 span: 4064 bytes, softFree=32/);
  assert.match(doc, /bank 7 span: 3724 bytes, softFree=4468/);
  assert.match(doc, /bank 8 span: 2435 bytes, softFree=1661/);
  assert.match(doc, /expansion total span: 19126 bytes, softFree=13642/);
  assert.match(doc, /npm run checkpoint:tecmate-rom/);
  assert.match(doc, /shell command matrix/);
  assert.match(doc, /aggregate two-slot\s+`dir` count/);
  assert.match(doc, /current ROM footprint/);
  assert.match(doc, /service inventory exercised\s+by the proof/);
});

test('TecMate OS progress note records the next ambitious milestone', () => {
  assert.match(doc, /## Next Ambitious Milestone/);
  assert.match(doc, /bounded single-file loop into a practical project\s+development environment/);
  assert.match(doc, /`.equ`, simple expressions, includes/);
  assert.match(doc, /bounded multi-file project through TEC-FS/);
  assert.match(doc, /debugger-facing breakpoints, stepping/);
  assert.match(doc, /Keep bank 0 compact, GLCD optional/);
});

test('TecMate OS progress note keeps game work behind general services', () => {
  assert.match(doc, /connect the working build artifacts and\s+source map to multi-file project resolution and debugger operations/);
  assert.match(doc, /games are a proving\s+profile for the general\s+TecMate services rather than a separate platform/);
});
