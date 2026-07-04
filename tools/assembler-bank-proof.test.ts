const { existsSync, readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');

test('assembler bank proof artifacts are wired into the repository', () => {
  assert.equal(existsSync(resolve(root, 'proofs/assembler-bank/assembler-bank-proof.asm')), true);
  assert.equal(existsSync(resolve(root, 'tools/run-assembler-bank-proof.ts')), true);
});

test('package check runs the assembler bank proof', () => {
  const pkg = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8'));
  assert.equal(pkg.scripts['proof:assembler-bank'], 'node --experimental-strip-types tools/run-assembler-bank-proof.ts');
  assert.match(pkg.scripts.check, /npm run proof:assembler-bank/);
});

test('assembler bank proof covers unsupported skeleton service', () => {
  const proof = readFileSync(resolve(root, 'proofs/assembler-bank/assembler-bank-proof.asm'), 'utf8');
  const runner = readFileSync(resolve(root, 'tools/run-assembler-bank-proof.ts'), 'utf8');
  const bank7 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank7.asm'), 'utf8');

  assert.match(proof, /ld a,ASM_SVC_ASSEMBLE[\s\S]*farCall ASM_BANK,ASM_ENTRY[\s\S]*jp nc,AssemblerProofFail[\s\S]*cp ASM_ERR_UNSUPPORTED/);
  assert.match(proof, /ld a,\(ASM_PARAM_TARGET_LO\)[\s\S]*cp 0xAB/);
  assert.match(proof, /ld a,\(ASM_PARAM_TARGET_HI\)[\s\S]*cp 0xCD/);
  assert.match(runner, /assertEqual\(params\[0\], 0xe0, 'assembler status after unsupported assemble'\)/);
  assert.match(runner, /assertEqual\(params\[6\], 0x04, 'assembler shell result low byte'\)/);
  assert.match(bank7, /@Tecm8ExpansionBank7Entry:[\s\S]*cp ASM_SVC_ASSEMBLE\s*\n\s*jp z,asmAssembleUnsupported/);
  assert.match(bank7, /asmAssembleUnsupported:[\s\S]*ld \(ASM_PARAM_BANK\),a[\s\S]*ld \(ASM_PARAM_STATUS\),a[\s\S]*ld \(ASM_PARAM_RESULT_LO\),a[\s\S]*scf[\s\S]*ret/);
});
