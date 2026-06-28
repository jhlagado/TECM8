const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const doc = readFileSync(resolve(root, 'docs/mon3/tecmate-monitor-launch-contract.md'), 'utf8');
const monitor = readFileSync(resolve(root, 'roms/tec1g/tecm8/monitor/monitor.asm'), 'utf8');
const ops = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank_ops.asmi'), 'utf8');
const runner = readFileSync(resolve(root, 'tools/run-tecmate-monitor-launch-proof.ts'), 'utf8');
const pkg = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8'));

function equateExpression(name: string): string {
  const match = ops.match(new RegExp(`^${name}\\s+\\.equ\\s+([^\\n;]+)`, 'm'));
  assert.ok(match, `missing equate ${name}`);
  return match[1].trim();
}

function parseNumber(token: string): number {
  const trimmed = token.trim();
  if (/^0x[0-9a-f]+$/i.test(trimmed)) {
    return Number.parseInt(trimmed.slice(2), 16);
  }
  if (/^[0-9a-f]+h$/i.test(trimmed)) {
    return Number.parseInt(trimmed.slice(0, -1), 16);
  }
  if (/^[0-9]+$/.test(trimmed)) {
    return Number.parseInt(trimmed, 10);
  }
  return equateValue(trimmed);
}

function equateValue(name: string): number {
  return equateExpression(name)
    .split('+')
    .map((part) => parseNumber(part))
    .reduce((sum, value) => sum + value, 0);
}

function docHex(name: string): string {
  const value = equateValue(name);
  const width = value <= 0xff ? 2 : 4;
  return `${value.toString(16).toUpperCase().padStart(width, '0')}h`;
}

test('TecMate monitor launch contract documents the fixed-ROM handoff', () => {
  assert.match(monitor, /launchTecMate:\s+xor a\s+call BiosBankSelect\s+jp 08000H/);
  assert.match(monitor, /runRoutine:[\s\S]*ld de,softBoot\s+;get return address\s+push de\s+;put return address on stack\s+jp \(hl\)/);
  assert.match(doc, /select expansion physical bank 0/);
  assert.match(doc, /jump to `8000h`/);
  assert.match(doc, /not a far call/);
  assert.match(doc, /pushes `softBoot`/);
  assert.match(doc, /plain `ret`/);
  assert.match(doc, /does not restore whatever expansion bank was selected/);
});

test('TecMate monitor launch contract names the bank-0 bootstrap ABI', () => {
  for (const name of [
    'TECM8_DEMO_BANK0_ENTRY',
    'TECM8_SERVICE_CALL',
    'TECM8_SHELL_ENTRY',
    'TECM8_SERVICE_SHELL_ENTRY',
  ]) {
    assert.match(ops, new RegExp(`^${name}\\s+\\.equ\\s+`, 'm'));
    assert.match(doc, new RegExp(`\\\`${name}\\\``));
  }

  assert.match(doc, new RegExp(`\\\`TECM8_DEMO_BANK0_ENTRY\\\` \\| \\\`${docHex('TECM8_DEMO_BANK0_ENTRY')}\\\``));
  assert.match(doc, new RegExp(`\\\`TECM8_SERVICE_CALL\\\` \\| \\\`${docHex('TECM8_SERVICE_CALL')}\\\``));
  assert.match(doc, new RegExp(`\\\`TECM8_SHELL_ENTRY\\\` \\| \\\`${docHex('TECM8_SHELL_ENTRY')}\\\``));
  assert.match(doc, new RegExp(`\\\`TECM8_SERVICE_SHELL_ENTRY\\\` \\| \\\`${docHex('TECM8_SERVICE_SHELL_ENTRY')}\\\``));
});

test('TecMate monitor launch contract is tied to the proof runner', () => {
  assert.equal(
    pkg.scripts['proof:tecmate-monitor-launch'],
    'npm run rom:check && node --experimental-strip-types tools/run-tecmate-monitor-launch-proof.ts',
  );
  assert.match(pkg.scripts.check, /npm run proof:tecmate-monitor-launch/);
  assert.match(doc, /npm run proof:tecmate-monitor-launch/);
  assert.match(runner, /symbolNumber\('launchTecMate'\)/);
  assert.match(runner, /bank 0 entry marker/);
  assert.match(runner, /TEC-FS service marker/);
});
