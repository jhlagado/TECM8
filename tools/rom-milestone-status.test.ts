const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { execFileSync } = require('node:child_process');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');

test('ROM milestone status reports integrated proof surfaces', () => {
  const pkg = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8'));
  const tool = readFileSync(resolve(root, 'tools/rom-milestone-status.ts'), 'utf8');

  assert.equal(pkg.scripts['rom:milestone:status'], 'node --experimental-strip-types tools/rom-milestone-status.ts');
  for (const text of [
    'monitor launch',
    'shell command loop',
    'VDU/TMS9918',
    'TEC-FS',
    'input snapshot',
    'bank ABI',
    'proofs/tecmate-monitor-launch/tecmate-monitor-launch-last-run.json',
    'proofs/shell-commands/last-run.json',
    'proofs/tms9918-bank/tms9918-bank-proof-last-run.json',
    'proofs/tecfs-bank/tecfs-bank-proof-last-run.json',
    'proofs/input-bank/input-bank-proof-last-run.json',
    'proofs/bank-abi/bank-abi-proof-last-run.json',
  ]) {
    assert.match(tool, new RegExp(text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  }
});

test('ROM milestone status command prints the current integrated status', () => {
  execFileSync('npm', ['run', 'rom:check'], {
    cwd: root,
    encoding: 'utf8',
  });
  for (const script of [
    'proof:tecmate-monitor-launch',
    'proof:shell-commands',
    'proof:tms9918-bank',
    'proof:tecfs-bank',
    'proof:input-bank',
    'proof:bank-abi',
  ]) {
    execFileSync('npm', ['run', script, '--silent'], {
      cwd: root,
      encoding: 'utf8',
    });
  }

  const output = execFileSync('npm', ['run', 'rom:milestone:status', '--silent'], {
    cwd: root,
    encoding: 'utf8',
  });

  assert.match(output, /TecMate milestone status/);
  assert.match(output, /monitor: span=16384\/16384/);
  assert.match(output, /expansion: occupied=\d+ span=\d+\/65536 hard-budget/);
  for (const proof of ['monitor launch', 'shell command loop', 'VDU/TMS9918', 'TEC-FS', 'input snapshot', 'bank ABI']) {
    assert.match(output, new RegExp(`last-run proof ${proof}: ok`));
  }
});
