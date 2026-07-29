const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');

const root = resolve(__dirname, '..');
const read = (path: string): string => readFileSync(resolve(root, path), 'utf8');

test('TecMate workspace demo documents boot, UI, bounds, and recovery', () => {
  const doc = read('docs/debug80-tecmate-workspace.md');
  const config = JSON.parse(read('debug80.json'));

  assert.match(doc, /npm run debug80:tecmate-workspace-image/);
  assert.match(doc, /select \*\*Expansion\*\*/);
  assert.match(doc, /Ctrl-O[\s\S]*Ctrl-N[\s\S]*Ctrl-A[\s\S]*Ctrl-R/);
  assert.match(doc, /48 fixed 32-byte records/);
  assert.match(doc, /1–27 characters/);
  assert.match(doc, /\/src\/\.tecmate\.s/);
  assert.match(doc, /\/src\/\.main\.asm\.b/);
  assert.match(doc, /Restore last saved file\?[\s\S]*Y\/N/);
  assert.match(doc, /npm run proof:tecfs-mon3-file/);
  assert.equal(
    config.targets.main.tec1g.sdImagePath,
    'demos/debug80/tecmate-workspace-fat32.img',
  );
});
