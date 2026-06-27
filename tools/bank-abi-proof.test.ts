const { strict: assert } = require('node:assert');
const { existsSync, readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { test } = require('node:test');

const root = resolve(__dirname, '..');

function readRepoFile(path: string): string {
  return readFileSync(resolve(root, path), 'utf8');
}

test('bank ABI proof covers farCall restore and farJump handoff behavior', () => {
  assert.ok(existsSync(resolve(root, 'proofs/bank-abi/bank-abi-proof.asm')));
  const proof = readRepoFile('proofs/bank-abi/bank-abi-proof.asm');
  const runner = readRepoFile('tools/run-bank-abi-proof.ts');
  const packageJson = readRepoFile('package.json');

  assert.match(proof, /TECM8_BIOS_BANK_CALL/);
  assert.match(proof, /TECM8_BIOS_FAR_JUMP/);
  assert.match(proof, /TECM8_ABI_BANK1_NESTED/);
  assert.match(proof, /TECM8_ABI_BANK3_FARJUMP/);
  assert.match(runner, /loadTec1gExpansionRomImage/);
  assert.match(runner, /applyExpansionRomMemory/);
  assert.match(runner, /SYS_CTRL restored after nested farCall/);
  assert.match(runner, /farJump did not return to caller/);
  assert.match(packageJson, /"proof:bank-abi"/);
  assert.match(packageJson, /proof:bank-abi/);
});
