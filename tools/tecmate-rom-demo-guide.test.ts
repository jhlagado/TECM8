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
  assert.match(guide, /runs `asm` through the shell command service, reaches the bank-7 assembler skeleton, and renders `ASM` then `UNSUP`/);
  assert.match(guide, /runs `run` through the shell command service, reaches the bank-8 run skeleton, and renders `RUN` then `UNSUP`/);
  assert.match(guide, /runs `dir` through the shell command service, checks the bank-2 TEC-FS catalogue summary, renders result status `OK`, and proves the bad-buffer path renders `FILE`/);
  assert.match(guide, /Proof-backed service inventory/);
  assert.match(guide, /bank 2: TEC-FS mount, catalogue summary, catalogue advance, bad-buffer error/);
  assert.match(guide, /bank 7: assembler skeleton handoff and unsupported result/);
  assert.match(guide, /bank 8: run skeleton handoff and unsupported result/);
  assert.match(guide, /Proof-backed shell command matrix/);
  assert.match(guide, /\| Command \| Route \| Visible status \| Visible result \| Detail \|/);
  assert.match(guide, /fixed monitor, expansion discovery, bank 0 shell scaffold, VDU\/TMS9918/);
  assert.match(guide, /input snapshot service, TEC-FS service boundary, assembler\/run skeleton handoffs, shell command status\/result paths, and `dir` catalogue summary/);
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
  assert.match(output, /^- shell asm status: ASM$/m);
  assert.match(output, /^- shell asm result status: UNSUP$/m);
  assert.match(output, /^- shell run status: RUN$/m);
  assert.match(output, /^- shell run result status: UNSUP$/m);
  assert.match(output, /^- shell dir result status: OK$/m);
  assert.match(output, /^- shell dir error result status: FILE$/m);
  assert.match(output, /^- shell dir aggregate count: 2$/m);
  assert.match(output, /^- shell dir last summary: fileId=0022h, fileType=0003h, nameLen=8, flags=0001h$/m);
  assert.match(output, /^Proof-backed service inventory:$/m);
  assert.match(output, /^- fixed monitor: expansion discovery, installed menu vector, installed service vector$/m);
  assert.match(output, /^- bank 0: shell entry, one-command shell boundary, status\/result renderers$/m);
  assert.match(output, /^- bank 1: VDU\/TMS9918 text\/status rendering$/m);
  assert.match(output, /^- bank 2: TEC-FS mount, catalogue summary, catalogue advance, bad-buffer error$/m);
  assert.match(output, /^- bank 6: input snapshot boundary$/m);
  assert.match(output, /^- bank 7: assembler skeleton handoff and unsupported result$/m);
  assert.match(output, /^- bank 8: run skeleton handoff and unsupported result$/m);
  assert.match(output, /^Proof-backed shell command matrix:$/m);
  assert.match(output, /^\| edit \| bank 0 shell \| EDIT \| n\/a \| project main target \|$/m);
  assert.match(output, /^\| asm \| bank 7 skeleton \| ASM \| UNSUP \| project main target \|$/m);
  assert.match(output, /^\| run \| bank 8 skeleton \| RUN \| UNSUP \| project output target \|$/m);
  assert.match(output, /^\| dir \| bank 2 TEC-FS \| DIR \| OK \| count 2 \|$/m);
  assert.match(output, /^\| dir bad-buffer \| bank 2 TEC-FS \| n\/a \| FILE \| buffer error path \|$/m);
  assert.match(output, /final SYS_CTRL: 0001h/);
  assert.match(output, /final physical bank: 0/);
});
