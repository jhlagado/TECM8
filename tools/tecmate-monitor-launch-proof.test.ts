const { existsSync, readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');

test('TecMate monitor launch proof artifacts are wired into the repository', () => {
  assert.equal(existsSync(resolve(root, 'proofs/tecmate-monitor-launch/README.md')), true);
  assert.equal(existsSync(resolve(root, 'tools/run-tecmate-monitor-launch-proof.ts')), true);
});

test('TecMate monitor launch proof exercises the fixed-ROM discovery launcher path', () => {
  const runner = readFileSync(resolve(root, 'tools/run-tecmate-monitor-launch-proof.ts'), 'utf8');
  const monitor = readFileSync(resolve(root, 'roms/tec1g/tecm8/monitor/monitor.asm'), 'utf8');
  const pkg = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8'));

  assert.match(monitor, /launchExpansion:[\s\S]*call discoverExpansion[\s\S]*call validateExpansionVector[\s\S]*call BiosBankCallDirect/);
  assert.match(runner, /symbolNumber\(MONITOR_D8_PATH, 'launchExpansion'\)/);
  assert.match(runner, /installed expansion menu address/);
  assert.match(runner, /bank 0 entry marker/);
  assert.match(runner, /TEC-FS service marker/);
  assert.equal(
    pkg.scripts['proof:tecmate-monitor-launch'],
    'npm run rom:check && node --experimental-strip-types tools/run-tecmate-monitor-launch-proof.ts',
  );
  assert.match(pkg.scripts.check, /npm run proof:tecmate-monitor-launch/);
});
