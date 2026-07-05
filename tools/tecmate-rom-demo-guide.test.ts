const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { execFileSync } = require('node:child_process');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');

test('manual ROM demo command is wired to the proof-backed ROM launch path', () => {
  const pkg = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8'));

  assert.equal(
    pkg.scripts['demo:tecmate-rom:manual'],
    'npm run demo:tecmate-rom && node --experimental-strip-types tools/print-tecmate-rom-demo-guide.ts',
  );
  assert.match(pkg.scripts['demo:tecmate-rom'], /tools\/run-tecmate-monitor-launch-proof\.ts/);
  assert.doesNotMatch(pkg.scripts['demo:tecmate-rom:manual'], /debug80:editor-image|GO 4000h|src\/main\.asm/);
});

test('manual ROM demo guide documents the Debug80-visible ROM path', () => {
  const guide = readFileSync(resolve(root, 'tools/print-tecmate-rom-demo-guide.ts'), 'utf8');
  const milestone = readFileSync(resolve(root, 'docs/debug80-tecmate-demo-milestone.md'), 'utf8');

  assert.match(guide, /# TecMate ROM Demo Manual Launch/);
  assert.match(guide, /build\/roms\/tec1g\/tecm8\/monitor\/monitor\.bin/);
  assert.match(guide, /build\/roms\/tec1g\/tecm8\/expansion\/expansion-144k\.bin/);
  assert.match(guide, /monitor `Expansion` menu item/);
  assert.match(guide, /expect `TecMate ROM Shell`, `TFS:30\+1 128M 4K`, `KEY:0000 JOY:00`, `>`, and `POLL`/);
  assert.match(guide, /runs `edit` through the shell command service and renders status `EDIT`/);
  assert.match(guide, /fixed monitor, expansion discovery, bank 0 shell scaffold, VDU\/TMS9918/);
  assert.match(guide, /input snapshot service, TEC-FS service boundary, and shell command status path/);
  assert.match(guide, /Do not use `GO 4000h`, `debug80:editor-image`, or the old RAM editor path/);
  assert.match(milestone, /npm run demo:tecmate-rom:manual/);
  assert.match(milestone, /prints the exact\s+generated ROM artifacts, monitor route, expected TMS9918 text, and last-run\s+trace markers/);
});

test('manual ROM demo guide prints current proof-backed markers', () => {
  execFileSync('npm', ['run', 'demo:tecmate-rom'], {
    cwd: root,
    encoding: 'utf8',
  });
  const proof = JSON.parse(
    readFileSync(resolve(root, 'proofs/tecmate-monitor-launch/tecmate-monitor-launch-last-run.json'), 'utf8'),
  );
  const launchAddress = proof.launchAddress.toString(16).toUpperCase().padStart(4, '0');

  const output = execFileSync('node', ['--experimental-strip-types', 'tools/print-tecmate-rom-demo-guide.ts'], {
    cwd: root,
    encoding: 'utf8',
  });

  assert.match(output, /# TecMate ROM Demo Manual Launch/);
  assert.match(output, new RegExp(`launchExpansion: ${launchAddress}h`));
  assert.match(output, /installed trace: 0000h 0000h 0000h 0003h 0081h 0082h 0083h 0086h 0080h/);
  assert.match(output, /^- shell command status: EDIT$/m);
  assert.match(output, /final SYS_CTRL: 0001h/);
  assert.match(output, /final physical bank: 0/);
});
