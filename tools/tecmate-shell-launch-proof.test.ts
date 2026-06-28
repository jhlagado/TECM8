const { existsSync, readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');

test('TecMate shell launch proof artifacts are wired into the repository', () => {
  assert.equal(existsSync(resolve(root, 'proofs/tecmate-shell-launch/tecmate-shell-launch-proof.asm')), true);
  assert.equal(existsSync(resolve(root, 'tools/run-tecmate-shell-launch-proof.ts')), true);
});

test('TecMate shell launch proof exercises direct and registry launch paths', () => {
  const proof = readFileSync(resolve(root, 'proofs/tecmate-shell-launch/tecmate-shell-launch-proof.asm'), 'utf8');
  const runner = readFileSync(resolve(root, 'tools/run-tecmate-shell-launch-proof.ts'), 'utf8');
  const pkg = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8'));

  assert.match(proof, /farCall 0x00,TECM8_SHELL_ENTRY/);
  assert.match(proof, /callService TECM8_SERVICE_SHELL_ENTRY/);
  assert.match(proof, /TECM8_SHELL_PARAM_BANK/);
  assert.match(proof, /TECM8_SHELL_PARAM_FEATURES/);
  assert.match(proof, /CheckShellSplash:/);
  assert.match(proof, /\.db\s+"TecMate",0/);
  assert.match(runner, /shell launch proof result marker/);
  assert.match(runner, /direct shell launch return/);
  assert.match(runner, /registry shell launch return/);
  assert.match(runner, /shell splash cursor low/);
  assert.match(runner, /shell splash T/);
  assert.equal(
    pkg.scripts['proof:tecmate-shell-launch'],
    'npm run rom:check && node --experimental-strip-types tools/run-tecmate-shell-launch-proof.ts',
  );
  assert.match(pkg.scripts.check, /npm run proof:tecmate-shell-launch/);
});
