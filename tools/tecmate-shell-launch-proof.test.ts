const { existsSync, readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');

test('TecMate shell launch proof artifacts are wired into the repository', () => {
  assert.equal(existsSync(resolve(root, 'proofs/tecmate-shell-launch/tecmate-shell-launch-proof.asm')), true);
  assert.equal(existsSync(resolve(root, 'tools/run-tecmate-shell-launch-proof.ts')), true);
});

test('TecMate shell launch proof exercises the service bridge launch path', () => {
  const proof = readFileSync(resolve(root, 'proofs/tecmate-shell-launch/tecmate-shell-launch-proof.asm'), 'utf8');
  const runner = readFileSync(resolve(root, 'tools/run-tecmate-shell-launch-proof.ts'), 'utf8');
  const pkg = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8'));

  assert.match(proof, /callService SHL_ENTRY/);
  assert.match(proof, /SHL_PARAM_BANK/);
  assert.match(proof, /SHL_PARAM_FEATURES/);
  assert.match(proof, /CheckShellSplash:/);
  assert.match(proof, /\.db\s+"TecMate",0/);
  assert.match(runner, /shell launch proof result marker/);
  assert.doesNotMatch(proof, /farCall 0x00,SHL_ENTRY/);
  assert.match(runner, /service bridge shell launch return/);
  assert.match(runner, /shell status P/);
  assert.match(runner, /shell loop tick/);
  assert.match(runner, /shell loop dirty mask/);
  assert.match(runner, /shell loop joystick/);
  assert.match(runner, /shell splash T/);
  assert.match(runner, /shell launch SYS_CTRL restored/);
  assert.match(runner, /shell launch SYS_MODE shadow restored/);
  assert.match(runner, /shell title/);
  assert.match(runner, /shell TEC-FS geometry line/);
  assert.match(runner, /shell input echo/);
  assert.match(runner, /shell prompt/);
  assert.match(runner, /shell status/);
  assert.equal(
    pkg.scripts['proof:tecmate-shell-launch'],
    'npm run rom:check && node --experimental-strip-types tools/run-tecmate-shell-launch-proof.ts',
  );
  assert.match(pkg.scripts.check, /npm run proof:tecmate-shell-launch/);
});
