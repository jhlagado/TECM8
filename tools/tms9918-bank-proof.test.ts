const { existsSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');

test('TMS9918 bank proof artifacts are wired into the repository', () => {
  assert.equal(existsSync(resolve(root, 'proofs/tms9918-bank/tms9918-bank-proof.asm')), true);
  assert.equal(existsSync(resolve(root, 'tools/run-tms9918-bank-proof.ts')), true);
});
