const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const doc = readFileSync(resolve(root, 'docs/mon3/tecmate-monitor-launch-contract.md'), 'utf8');
const monitor = readFileSync(resolve(root, 'roms/tec1g/tecm8/monitor/monitor.asm'), 'utf8');
const bank0 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank0.asm'), 'utf8');
const monitorLaunchRunner = readFileSync(resolve(root, 'tools/run-tecmate-monitor-launch-proof.ts'), 'utf8');
const shellLaunchProof = readFileSync(resolve(root, 'proofs/tecmate-shell-launch/tecmate-shell-launch-proof.asm'), 'utf8');

test('shell exit contract is grounded in the monitor menu return path', () => {
  assert.match(monitor, /runRoutine:[\s\S]*ld de,softBoot\s+;get return address\s+push de\s+;put return address on stack\s+jp \(hl\)/);
  assert.match(monitor, /launchExpansion:[\s\S]*call discoverExpansion[\s\S]*call BiosBankCallDirect/);
  assert.match(doc, /Menu-launched expansion \| bank 0 is called through the fixed monitor bank-call path/);
  assert.match(doc, /`softBoot` on the stack/);
});

test('shell exit contract distinguishes proof returns from production shell policy', () => {
  assert.match(monitorLaunchRunner, /STACK_RETURN/);
  assert.match(monitorLaunchRunner, /RETURN_STUB/);
  assert.match(shellLaunchProof, /callService SHL_ENTRY/);
  assert.match(doc, /Monitor-launch proof-launched TecMate \| bank 0 may exit with a plain `ret`/);
  assert.match(doc, /Full shell exit \| still undecided/);
});

test('shell exit contract keeps cross-bank returns on the fixed monitor ABI', () => {
  assert.match(bank0, /@Tecm8ExpansionBank0Entry:[\s\S]*callService VDU_INIT[\s\S]*ret/);
  assert.match(bank0, /farCall TFS_MOUNT_BANK,TFS_MOUNT_ADDR/);
  assert.match(doc, /Far-called TecMate service \| service routines must return through the fixed monitor `BiosBankCall` mechanism/);
  assert.match(doc, /Cross-bank calls remain the\s+job of the fixed monitor bank ABI/);
});
