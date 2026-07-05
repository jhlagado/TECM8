const { existsSync, readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');

test('input bank proof artifacts are wired into the repository', () => {
  assert.equal(existsSync(resolve(root, 'proofs/input-bank/input-bank-proof.asm')), true);
  assert.equal(existsSync(resolve(root, 'tools/run-input-bank-proof.ts')), true);
});

test('package check runs the input bank proof', () => {
  const pkg = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8'));
  assert.equal(pkg.scripts['proof:input-bank'], 'node --experimental-strip-types tools/run-input-bank-proof.ts');
  assert.match(pkg.scripts.check, /npm run proof:input-bank/);
});

test('input bank proof covers neutral snapshot fields', () => {
  const proof = readFileSync(resolve(root, 'proofs/input-bank/input-bank-proof.asm'), 'utf8');
  const runner = readFileSync(resolve(root, 'tools/run-input-bank-proof.ts'), 'utf8');
  const bank6 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank6.asm'), 'utf8');

  assert.match(proof, /ld a,INP_SVC_READ[\s\S]*farCall 0x06,INP_ENTRY[\s\S]*cp 0x86/);
  assert.match(proof, /ld a,\(INP_PARAM_BANK\)[\s\S]*cp 0x06/);
  assert.match(proof, /ld a,\(INP_PARAM_KEYS_LO\)[\s\S]*or a[\s\S]*jp nz,InputProofFail/);
  assert.match(proof, /ld a,\(INP_PARAM_JOYSTICK\)[\s\S]*or a[\s\S]*jp nz,InputProofFail/);
  assert.match(proof, /ld a,0x5A[\s\S]*ld \(INP_PARAM_STATUS\),a[\s\S]*ld a,0xA5[\s\S]*ld \(INP_PARAM_LAST_ERROR\),a/);
  assert.match(proof, /ld a,0x7F[\s\S]*farCall 0x06,INP_ENTRY[\s\S]*jp nc,InputProofFail[\s\S]*cp INP_ERR_UNKNOWN[\s\S]*ld a,\(INP_PARAM_STATUS\)[\s\S]*cp 0x5A[\s\S]*ld a,\(INP_PARAM_LAST_ERROR\)[\s\S]*cp 0xA5/);
  assert.match(runner, /input status preserved after unknown selector/);
  assert.match(runner, /input last error preserved after unknown selector/);
  assert.match(runner, /assertEqual\(params\[6\], 0x00, 'input joystick bitfield'\)/);
  assert.match(runner, /assertEqual\(params\[7\], 0x00, 'input modifiers bitfield'\)/);
  assert.match(bank6, /ld a,INP_ERR_UNKNOWN\s+scf\s+ret/);
  assert.match(bank6, /Tecm8InputRead:[\s\S]*ld \(INP_PARAM_KEYS_LO\),a[\s\S]*ld \(INP_PARAM_JOYSTICK\),a/);
});
