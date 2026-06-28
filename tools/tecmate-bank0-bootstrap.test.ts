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
  assert.match(bank0, /Tecm8BootstrapVdu:[\s\S]*callService TECM8_SERVICE_VDU_INIT[\s\S]*ld \(TECM8_DEMO_TRACE_4\),a[\s\S]*ret/);
  assert.match(bank0, /Tecm8BootstrapTecfs:[\s\S]*callService TECM8_SERVICE_TECFS_MOUNT[\s\S]*ld \(TECM8_DEMO_TRACE_5\),a[\s\S]*ret/);
});

test('bank 0 bootstrap has explicit input and shell placeholders', () => {
  assert.match(ops, /^TECM8_BOOTSTRAP_INPUT_READY\s+\.equ\s+0x70/m);
  assert.match(ops, /^TECM8_BOOTSTRAP_SHELL_READY\s+\.equ\s+0x71/m);
  assert.match(bank0, /Tecm8BootstrapInput:[\s\S]*ld a,TECM8_BOOTSTRAP_INPUT_READY[\s\S]*ld \(TECM8_DEMO_TRACE_7\),a[\s\S]*ret/);
  assert.match(bank0, /Tecm8BootstrapShell:[\s\S]*callService TECM8_SERVICE_RTC_TOOL[\s\S]*ld \(TECM8_DEMO_TRACE_6\),a[\s\S]*ld a,TECM8_BOOTSTRAP_SHELL_READY[\s\S]*ld \(TECM8_DEMO_TRACE_8\),a[\s\S]*ret/);
});

test('monitor launch proof and contract cover the bootstrap phases', () => {
  assert.match(runner, /input bootstrap marker/);
  assert.match(runner, /shell bootstrap marker/);
  assert.match(doc, /call Tecm8BootstrapVdu/);
  assert.match(doc, /call Tecm8BootstrapInput/);
  assert.match(doc, /call Tecm8BootstrapShell/);
});

test('bank 0 publishes a fixed service registry table', () => {
  assert.match(ops, /^TECM8_SERVICE_REGISTRY\s+\.equ\s+0x8170/m);
  assert.match(ops, /^TECM8_SERVICE_REGISTRY_ENTRY_SIZE\s+\.equ\s+0x04/m);
  assert.match(ops, /^TECM8_SERVICE_REGISTRY_END\s+\.equ\s+0x00/m);
  assert.match(bank0, /@Tecm8ServiceRegistry:\s*[\s\S]*\.db\s+TECM8_SERVICE_VDU_INIT,TECM8_SERVICE_VDU_INIT_BANK\s*[\s\S]*\.dw\s+TECM8_SERVICE_VDU_INIT_ADDR/);
  assert.match(bank0, /\.db\s+TECM8_SERVICE_TECFS_MOUNT,TECM8_SERVICE_TECFS_MOUNT_BANK\s*[\s\S]*\.dw\s+TECM8_SERVICE_TECFS_MOUNT_ADDR/);
  assert.match(bank0, /\.db\s+TECM8_SERVICE_RTC_TOOL,TECM8_SERVICE_RTC_TOOL_BANK\s*[\s\S]*\.dw\s+TECM8_SERVICE_RTC_TOOL_ADDR/);
  assert.match(bank0, /\.db\s+TECM8_SERVICE_GLCD_ENTRY,TECM8_SERVICE_GLCD_ENTRY_BANK\s*[\s\S]*\.dw\s+TECM8_SERVICE_GLCD_ENTRY_ADDR/);
  assert.match(bank0, /\.db\s+TECM8_SERVICE_SHELL_ENTRY,TECM8_SERVICE_SHELL_ENTRY_BANK\s*[\s\S]*\.dw\s+TECM8_SERVICE_SHELL_ENTRY_ADDR/);
  assert.match(bank0, /@Tecm8ServiceRegistryEnd:\s*[\s\S]*\.db\s+TECM8_SERVICE_REGISTRY_END/);
  assert.match(abiDoc, /byte 0: service ID/);
  assert.match(abiDoc, /later table-driven dispatcher/);
});
