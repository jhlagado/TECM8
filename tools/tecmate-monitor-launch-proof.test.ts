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
  assert.match(runner, /bank 0 header magic E/);
  assert.match(runner, /bank 0 header install routine/);
  assert.match(runner, /installed expansion service address/);
  assert.match(runner, /runAlternateInstallCase/);
  assert.match(runner, /alternate expansion menu address/);
  assert.match(runner, /alternate expansion service address/);
  assert.match(runner, /const TFS_MOUNT = 0x61/);
  assert.doesNotMatch(runner, /TECM8_BIOS_SERVICE_BRIDGE/);
  assert.match(runner, /bridge TEC-FS mount side effect/);
  assert.match(runner, /bridge returned A/);
  assert.match(runner, /missing expansion returned carry set/);
  assert.match(runner, /bridge SYS_CTRL restored/);
  assert.match(runner, /bank 0 entry marker/);
  assert.match(runner, /TEC-FS service marker/);
  assert.match(runner, /input service marker/);
  assert.match(runner, /shell entry marker/);
  assert.match(runner, /assertDemoVram/);
  assert.match(runner, /demo TMS9918 device active/);
  assert.match(runner, /demo VDU first splash character/);
  assert.match(runner, /demo status first character/);
  assert.match(runner, /demo input service bank side effect/);
  assert.match(runner, /demo input neutral joystick state/);
  assert.match(runner, /demo TEC-FS mount side effect/);
  assert.equal(
    pkg.scripts['proof:tecmate-monitor-launch'],
    'npm run rom:check && node --experimental-strip-types tools/run-tecmate-monitor-launch-proof.ts',
  );
  assert.match(pkg.scripts.check, /npm run proof:tecmate-monitor-launch/);
});
