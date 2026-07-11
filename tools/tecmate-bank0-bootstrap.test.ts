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
  assert.match(bank0, /Tecm8ExpansionBank0Entry:[\s\S]*call Tecm8BootstrapVdu[\s\S]*call Tecm8BootstrapTecfs[\s\S]*call Tecm8BootstrapInput[\s\S]*call Tecm8BootstrapShell[\s\S]*ret/);
  assert.match(bank0, /Tecm8BootstrapVdu:[\s\S]*callService VDU_INIT[\s\S]*ld \(DBG_TRACE_4\),a[\s\S]*ret/);
  assert.match(bank0, /Tecm8BootstrapTecfs:[\s\S]*callService TFS_MOUNT[\s\S]*ld \(DBG_TRACE_5\),a[\s\S]*ret/);
});

test('bank 0 bootstrap calls input and shell services', () => {
  assert.match(ops, /^INP_READ\s+\.equ\s+SVC_BASE\+0x04/m);
  assert.match(ops, /^SHL_ENTRY\s+\.equ\s+SVC_BASE\+0x20/m);
  assert.match(bank0, /Tecm8BootstrapInput:[\s\S]*callService INP_READ[\s\S]*ld \(DBG_TRACE_7\),a[\s\S]*ret/);
  assert.match(bank0, /Tecm8BootstrapShell:[\s\S]*callService RTC_TOOL[\s\S]*ld \(DBG_TRACE_6\),a[\s\S]*callService SHL_ENTRY[\s\S]*ld \(DBG_TRACE_8\),a[\s\S]*ret/);
});

test('monitor launch proof and contract cover the bootstrap phases', () => {
  assert.match(runner, /input service marker/);
  assert.match(runner, /shell entry marker/);
  assert.match(runner, /assertDemoVram/);
  assert.match(doc, /call Tecm8BootstrapVdu/);
  assert.match(doc, /call Tecm8BootstrapInput/);
  assert.match(doc, /call Tecm8BootstrapShell/);
});

test('bank 0 publishes a private service registry table', () => {
  assert.doesNotMatch(ops, /^TECM8_SERVICE_REGISTRY\s+\.equ\s+/m);
  assert.match(ops, /^SVC_REG_ENTRY_SIZE\s+\.equ\s+0x05/m);
  assert.match(ops, /^SVC_REG_END\s+\.equ\s+0x00/m);
  assert.match(bank0, /Tecm8ServiceRegistry:\s*[\s\S]*\.db\s+VDU_INIT,VDU_BANK\s*[\s\S]*\.dw\s+VDU_ADDR\s*[\s\S]*\.db\s+VDU_SVC_INIT/);
  assert.match(bank0, /\.db\s+TFS_MOUNT,TFS_BANK\s*[\s\S]*\.dw\s+TFS_ADDR\s*[\s\S]*\.db\s+TFS_SVC_MOUNT/);
  assert.match(bank0, /\.db\s+RTC_TOOL,RTC_BANK\s*[\s\S]*\.dw\s+RTC_ADDR\s*[\s\S]*\.db\s+RTC_SVC_TOOL_ENTRY/);
  assert.match(bank0, /\.db\s+GLC_ENTRY,GLC_BANK\s*[\s\S]*\.dw\s+GLC_ADDR\s*[\s\S]*\.db\s+GLC_ENTRY/);
  assert.match(bank0, /\.db\s+SHL_ENTRY,SHL_BANK\s*[\s\S]*\.dw\s+Tecm8ShellEntry\s*[\s\S]*\.db\s+SHL_ENTRY/);
  assert.match(bank0, /\.db\s+ABI_PROBE_NESTED,VDU_BANK\s*[\s\S]*\.dw\s+VDU_ENTRY\s*[\s\S]*\.db\s+ABI_PROBE_NESTED/);
  assert.match(bank0, /Tecm8ServiceRegistryEnd:\s*[\s\S]*\.db\s+SVC_REG_END/);
  assert.match(abiDoc, /byte 0: public service ID carried in C/);
  assert.match(abiDoc, /byte 4: target-local service selector loaded into A/);
  assert.match(abiDoc, /dispatcher scans this private registry table at runtime/);
  assert.match(abiDoc, /registry labels are private implementation details/);
});
