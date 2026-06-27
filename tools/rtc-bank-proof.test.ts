const { existsSync, readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');

test('RTC bank proof artifacts are wired into the repository', () => {
  assert.equal(existsSync(resolve(root, 'proofs/rtc-bank/rtc-bank-proof.asm')), true);
  assert.equal(existsSync(resolve(root, 'tools/run-rtc-bank-proof.ts')), true);
});

test('package check runs the RTC bank proof', () => {
  const pkg = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8'));
  assert.equal(pkg.scripts['proof:rtc-bank'], 'node --experimental-strip-types tools/run-rtc-bank-proof.ts');
  assert.match(pkg.scripts.check, /npm run proof:rtc-bank/);
});
