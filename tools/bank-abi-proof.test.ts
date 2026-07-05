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

  assert.match(proof, /callBankService 0x01,VDU_CALL,VDU_SVC_INIT/);
  assert.match(proof, /callService ABI_PROBE_NESTED/);
  assert.match(proof, /ld \(ABI_PROBE_REQUEST\),a[\s\S]*farCall 0x01,VDU_ENTRY/);
  assert.match(proof, /ld a,ABI_PROBE_FARJUMP[\s\S]*farJump 0x03,RTC_ENTRY/);
  assert.match(proof, /ld a,ABI_PROBE_RETURNING_FARJUMP[\s\S]*farJump 0x03,RTC_ENTRY/);
  assert.match(proof, /callService VDU_INIT/);
  assert.match(proof, /callService TFS_MOUNT/);
  assert.match(proof, /callService RTC_TOOL/);
  assert.match(proof, /callService GLC_ENTRY/);
  assert.match(proof, /callService SHL_ENTRY/);
  assert.match(proof, /callService SHL_RUN_COMMAND/);
  assert.match(proof, /callService 0x7F[\s\S]*ld \(ABI_TRACE_BASE\+21\),a[\s\S]*jp nc,BankAbiFarJumpReturnedFail/);
  assert.match(runner, /loadTec1gExpansionRomImage/);
  assert.match(runner, /applyExpansionRomMemory/);
  assert.match(runner, /function assertProofPassed/);
  assert.match(runner, /resultAddr=0x/);
  assert.match(runner, /pc=0x/);
  assert.match(runner, /sp=0x/);
  assert.match(runner, /sysCtrl=0x/);
  assert.match(runner, /physicalBank=/);
  assert.match(runner, /trace9=0x/);
  assert.match(runner, /trace21=0x/);
  assert.match(runner, /SYS_CTRL restored after nested farCall/);
  assert.match(runner, /farCall target sees original A argument/);
  assert.match(runner, /farCall preserved stack pointer low byte/);
  assert.match(runner, /farCall preserved stack pointer high byte/);
  assert.match(runner, /returning farJump target did not resume after farJump op/);
  assert.match(runner, /service registry dispatched VDU init/);
  assert.match(runner, /service registry dispatched GLCD boundary entry/);
  assert.match(runner, /service registry dispatched shell entry/);
  assert.match(runner, /shell command loop classified asm action/);
  assert.match(runner, /shell command loop rejected unknown command/);
  assert.match(runner, /shell edit leaves result low byte at none/);
  assert.match(runner, /farJump did not return to caller/);
  assert.match(packageJson, /"proof:bank-abi"/);
  assert.match(packageJson, /proof:bank-abi/);
});
