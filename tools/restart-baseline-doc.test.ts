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

test('roadmap records the ROM shell checkpoint and the next editor slice', () => {
  const roadmap = readRepoFile('docs/roadmap.md');
  assert.match(roadmap, /## Current Checkpoint: ROM Shell And Banked Services/);
  assert.match(roadmap, /Debug80 TecMate ROM demo milestone is complete/);
  assert.match(roadmap, /shell classification for exact `edit`, `asm`, `run`, and `dir`/);
  assert.match(roadmap, /## Next Implementation Milestone: ROM Editor File-Buffer Vertical Slice/);
  assert.match(
    roadmap,
    /shell `edit`[\s\S]*TEC-FS target and metadata lookup[\s\S]*editor file-buffer service[\s\S]*VDU\/TMS9918 32-byte-record source window/,
  );
  assert.match(roadmap, /A Debug80 proof verifies the target descriptor/);
  assert.match(roadmap, /ROM size and register-contract gates remain green/);
});
