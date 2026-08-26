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
  assert.match(doc, /classifies exact `edit`, `asm`, `run`, and `dir` commands/);
  assert.match(doc, /`dir` leaves the target pointer and flags clear, calls the bank-2 TEC-FS\s+catalogue summarizer/);
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
  assert.match(doc, /3248 occupied bytes currently/);
  assert.match(doc, /3248 bytes total high-water span across all banks/);
  assert.match(doc, /native object-service transport keeps the expansion footprint small/);
  assert.match(doc, /bank 0 span: 1284 -> 1289 bytes/);
  assert.match(doc, /bank 2 span: 1042 -> 1051 bytes/);
  assert.match(doc, /expansion total span: 3234 -> 3248 bytes/);
  assert.match(doc, /fixed monitor occupied: 9007 -> 9017 bytes/);
  assert.match(doc, /fixed monitor span: unchanged at 16384 bytes/);
  assert.match(doc, /native object-service transport reserves public selector `91h`/);
  assert.match(doc, /unknown shell commands are now proof-backed as `ERRCMD` \/ `NONE`/);
  assert.match(doc, /shell checkpoint matrix is pinned as the current command surface/);
  assert.match(doc, /TEC-FS metadata updates are constrained to the bank-2 caller-buffer model/);
  assert.match(doc, /ROM editor starts from a small source file-buffer ABI on the VDU\/TMS9918\s+path/);
  assert.match(doc, /bank 0 is guarded as an exact-word classifier and dispatcher/);
  assert.match(doc, /size gate now prints per-bank soft-budget headroom/);
  assert.match(doc, /next manual demo path is `edit` -> TEC-FS target\/metadata lookup ->\s+editor file-buffer service -> VDU\/TMS9918 source window/);
  assert.match(doc, /TEC-FS services are classified as implemented proof services,\s+stubbed\/reserved services, and deferred filesystem work/);
  assert.match(doc, /assembler remains gated behind editor-buffer input and TEC-FS binary\/map\s+output readiness/);
  assert.match(doc, /fixed monitor span: 16384\/16384 bytes/);
  assert.match(doc, /bank 0 span: 1289 bytes, softFree=759/);
  assert.match(doc, /bank 2 span: 1051 bytes, softFree=3045/);
  assert.match(doc, /bank 7 span: 45 bytes, softFree=8147/);
  assert.match(doc, /expansion total span: 3248 bytes, softFree=29520/);
  assert.match(doc, /npm run checkpoint:tecmate-rom/);
  assert.match(doc, /shell command matrix/);
  assert.match(doc, /aggregate two-slot\s+`dir` count/);
  assert.match(doc, /current ROM footprint/);
  assert.match(doc, /service inventory exercised\s+by the proof/);
});

test('TecMate OS progress note records the next compact milestones', () => {
  assert.match(doc, /## Next Compact Milestones/);
  assert.match(doc, /minimal\s+read\/write sector and metadata update path/);
  assert.match(doc, /without pulling FAT32\/PATA back\s+into the monitor/);
  assert.match(doc, /smallest editor-facing file buffer contract/);
  assert.match(doc, /load, mark\s+dirty, and save one source file through TEC-FS/);
  assert.match(doc, /Keep the assembler bank as an unsupported skeleton/);
  assert.match(doc, /VDU\/TMS9918 text services needed by the shell\/editor path/);
  assert.match(doc, /Treat GLCD as a compatibility boundary and low-priority optional bank/);
  assert.match(doc, /core editor\/TEC-FS\/assembler path/);
});

test('TecMate OS progress note keeps game work behind general services', () => {
  assert.match(doc, /connect the shell result convention,\s+assembler artifact convention, TEC-FS metadata record/);
  assert.match(doc, /games are a proving profile for the general\s+TecMate services rather than a separate platform/);
});
