const { strict: assert } = require('node:assert');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { test } = require('node:test');

const root = resolve(__dirname, '..');

function readRepoFile(path: string): string {
  return readFileSync(resolve(root, path), 'utf8');
}

test('README documents the current Debug80 monorepo development dependency', () => {
  const readme = readRepoFile('README.md');
  assert.match(readme, /### Debug80 Development Dependency/);
  assert.match(readme, /packages\/debug80-runtime\/dist/);
  assert.match(readme, /apps\/debug80-vscode\/resources\/bundles\/tec1g\/mon3\/v1/);
  assert.match(readme, /DEBUG80_ROOT/);
  assert.match(readme, /DEBUG80_RUNTIME_ROOT/);
  assert.match(readme, /DEBUG80_MON3_BUNDLE_ROOT/);
  assert.match(readme, /npm run check/);
});

test('roadmap records the ROM shell checkpoint and completed toolchain slices', () => {
  const roadmap = readRepoFile('docs/roadmap.md');
  assert.match(roadmap, /## Current Checkpoint: ROM Shell And Banked Services/);
  assert.match(roadmap, /Debug80 TecMate ROM demo milestone is complete/);
  assert.match(roadmap, /shell classification for exact `edit`, `asm`, `run`, and `dir`/);
  assert.match(roadmap, /## Completed Implementation Milestone: Persistent Interactive ROM Editor/);
  assert.match(
    roadmap,
    /shell `edit`[\s\S]*bank-4 editor and bank-6 translated key loop[\s\S]*VDU\/TMS9918 32-byte records and blinking block cursor[\s\S]*bank-2 data-sector writes and metadata commit[\s\S]*return to shell and reopen/,
  );
  assert.match(roadmap, /A Debug80 proof saves a grown two-page source/);
  assert.match(roadmap, /ROM size and register-contract gates remain green/);
  assert.match(roadmap, /## Completed Implementation Milestone: Self-Hosted Build And Run/);
  assert.match(roadmap, /asm reports BUILD at a source record/);
  assert.match(roadmap, /emits executable and TMAP data\/metadata through bank 2/);
  assert.match(roadmap, /validates, loads, executes, and returns safely to the shell/);
  assert.match(roadmap, /next ambitious milestone should turn the single resident source buffer into\s+a practical multi-file project toolchain/);
});
