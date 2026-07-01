const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');

test('monitor register contract audit is documented and wired to package scripts', () => {
  const pkg = readFileSync(resolve(root, 'package.json'), 'utf8');
  const tool = readFileSync(resolve(root, 'tools/audit-monitor-register-contracts.ts'), 'utf8');
  const report = readFileSync(resolve(root, 'docs/mon3/monitor-register-contract-audit.md'), 'utf8');
  const progress = readFileSync(resolve(root, 'docs/mon3/tecmate-os-progress.md'), 'utf8');
  const readme = readFileSync(resolve(root, 'docs/README.md'), 'utf8');

  assert.match(pkg, /"mon3:contracts:audit"/);
  assert.match(tool, /diagnostic\.code !== 'AZMN_REGISTER_CONTRACTS'/);
  assert.match(tool, /Unexpected AZM diagnostics/);
  assert.match(report, /Strict contract diagnostics: `298`/);
  assert.match(report, /roms\/tec1g\/tecm8\/monitor\/monitor\.asm \| 203/);
  assert.match(report, /roms\/tec1g\/tecm8\/monitor\/disassembler\.asm \| 52/);
  assert.match(report, /roms\/tec1g\/tecm8\/monitor\/rtc\.asm \| 39/);
  assert.match(report, /roms\/tec1g\/tecm8\/monitor\/sound\.asm \| 4/);
  assert.match(report, /Use AZM's register contract policy/);
  assert.match(progress, /Monitor Register Contract Audit/);
  assert.match(progress, /Register Contract Policy/);
  assert.match(progress, /New TecMate code should continue using strict AZM register contracts/);
  assert.match(readme, /Monitor Register Contract Audit/);
  assert.match(readme, /Register Contract Policy/);
  assert.match(readme, /TecMate OS Progress/);
});
