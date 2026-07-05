const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');

test('monitor register contract audit is documented and wired to package scripts', () => {
  const pkg = readFileSync(resolve(root, 'package.json'), 'utf8');
  const config = JSON.parse(readFileSync(resolve(root, 'debug80.json'), 'utf8'));
  const tool = readFileSync(resolve(root, 'tools/audit-monitor-register-contracts.ts'), 'utf8');
  const expansionGate = readFileSync(resolve(root, 'tools/check-expansion-register-contracts.ts'), 'utf8');
  const report = readFileSync(resolve(root, 'docs/mon3/monitor-register-contract-audit.md'), 'utf8');
  const policy = readFileSync(resolve(root, 'docs/mon3/register-contract-policy.md'), 'utf8');
  const progress = readFileSync(resolve(root, 'docs/mon3/tecmate-os-progress.md'), 'utf8');
  const readme = readFileSync(resolve(root, 'docs/README.md'), 'utf8');
  const azm = config.targets.main.azm;

  assert.match(pkg, /"mon3:contracts:audit"/);
  assert.match(pkg, /"rom:contracts:check"/);
  assert.match(pkg, /"check": ".*npm run rom:contracts:check/);
  assert.equal(azm.registerContracts, 'off');
  assert.deepEqual(azm.registerContractsPolicy.strict, [
    'src/*.asm',
    'src/**/*.asm',
    'proofs/*.asm',
    'proofs/**/*.asm',
    'roms/tec1g/tecm8/expansion/*.asm',
    'roms/tec1g/tecm8/expansion/**/*.asm',
  ]);
  assert.deepEqual(azm.registerContractsPolicy.audit, [
    'roms/tec1g/tecm8/monitor/monitor.asm',
    'roms/tec1g/tecm8/monitor/rtc.asm',
    'roms/tec1g/tecm8/monitor/sound.asm',
    'roms/tec1g/tecm8/monitor/disassembler.asm',
  ]);
  assert.deepEqual(azm.registerContractsPolicy.off, [
    'roms/tec1g/mon3/**/*.asm',
    'roms/tec1g/tecm8/monitor/glcd_library.asm',
    'roms/tec1g/tecm8/monitor/pata_fat32.asm',
  ]);
  assert.equal(azm.registerContractsProfile, 'mon3');
  assert.deepEqual(azm.registerContractsInterfaces, [
    'roms/tec1g/tecm8/expansion/tecm8-rst-services.asmi',
  ]);
  assert.equal(azm.emitRegisterReport, true);
  assert.match(tool, /diagnostic\.code !== 'AZMN_REGISTER_CONTRACTS'/);
  assert.match(tool, /Unexpected AZM diagnostics/);
  assert.match(expansionGate, /const BANK_COUNT = 9/);
  assert.match(expansionGate, /bank < BANK_COUNT/);
  assert.match(expansionGate, /registerContracts: 'strict'/);
  assert.match(expansionGate, /registerContractsInterfaces: \[RST_INTERFACE\]/);
  assert.match(expansionGate, /tecm8-rst-services\.asmi/);
  assert.match(policy, /`debug80\.json` now records the staged policy on the `main` target/);
  assert.match(policy, /Direct-child and recursive globs are both listed deliberately/);
  assert.match(policy, /`npm run rom:contracts:check` remains the release gate for the expansion ROM/);
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
