const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const bank0 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank0.asm'), 'utf8');
const ops = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank_ops.asmi'), 'utf8');
const runner = readFileSync(resolve(root, 'tools/run-tecmate-monitor-launch-proof.ts'), 'utf8');
const doc = readFileSync(resolve(root, 'docs/mon3/tecmate-monitor-launch-contract.md'), 'utf8');
const abiDoc = readFileSync(resolve(root, 'docs/mon3/tecmate-banked-service-abi.md'), 'utf8');

test('bank 0 entry is a named TecMate bootstrap sequence', () => {
  assert.match(bank0, /@Tecm8ExpansionBank0Entry:[\s\S]*call Tecm8BootstrapVdu[\s\S]*call Tecm8BootstrapTecfs[\s\S]*call Tecm8BootstrapInput[\s\S]*call Tecm8BootstrapShell[\s\S]*ret/);
  assert.match(bank0, /Tecm8BootstrapVdu:[\s\S]*callService VDU_INIT[\s\S]*ld \(DBG_TRACE_4\),a[\s\S]*ret/);
  assert.match(bank0, /Tecm8BootstrapTecfs:[\s\S]*callService TFS_MOUNT[\s\S]*ld \(DBG_TRACE_5\),a[\s\S]*ret/);
});

test('bank 0 bootstrap has explicit input and shell placeholders', () => {
  assert.match(ops, /^SHL_BOOT_INPUT_READY\s+\.equ\s+0x70/m);
  assert.match(ops, /^SHL_BOOT_READY\s+\.equ\s+0x71/m);
  assert.match(bank0, /Tecm8BootstrapInput:[\s\S]*ld a,SHL_BOOT_INPUT_READY[\s\S]*ld \(DBG_TRACE_7\),a[\s\S]*ret/);
  assert.match(bank0, /Tecm8BootstrapShell:[\s\S]*callService RTC_TOOL[\s\S]*ld \(DBG_TRACE_6\),a[\s\S]*ld a,SHL_BOOT_READY[\s\S]*ld \(DBG_TRACE_8\),a[\s\S]*ret/);
});

test('monitor launch proof and contract cover the bootstrap phases', () => {
  assert.match(runner, /input bootstrap marker/);
  assert.match(runner, /shell bootstrap marker/);
  assert.match(doc, /call Tecm8BootstrapVdu/);
  assert.match(doc, /call Tecm8BootstrapInput/);
  assert.match(doc, /call Tecm8BootstrapShell/);
});

test('bank 0 publishes a private service registry table', () => {
  assert.doesNotMatch(ops, /^TECM8_SERVICE_REGISTRY\s+\.equ\s+/m);
  assert.match(ops, /^SVC_REG_ENTRY_SIZE\s+\.equ\s+0x04/m);
  assert.match(ops, /^SVC_REG_END\s+\.equ\s+0x00/m);
  assert.match(bank0, /@Tecm8ServiceRegistry:\s*[\s\S]*\.db\s+VDU_INIT,VDU_BANK\s*[\s\S]*\.dw\s+VDU_ADDR/);
  assert.match(bank0, /\.db\s+TFS_MOUNT,TFS_BANK\s*[\s\S]*\.dw\s+TFS_ADDR/);
  assert.match(bank0, /\.db\s+RTC_TOOL,RTC_BANK\s*[\s\S]*\.dw\s+RTC_ADDR/);
  assert.match(bank0, /\.db\s+GLC_ENTRY,GLC_BANK\s*[\s\S]*\.dw\s+GLC_ADDR/);
  assert.match(bank0, /\.db\s+SHL_ENTRY,SHL_BANK\s*[\s\S]*\.dw\s+Tecm8ShellEntry/);
  assert.match(bank0, /@Tecm8ServiceRegistryEnd:\s*[\s\S]*\.db\s+SVC_REG_END/);
  assert.match(abiDoc, /byte 0: service ID/);
  assert.match(abiDoc, /later table-driven dispatcher/);
  assert.match(abiDoc, /registry labels are private implementation details/);
});
