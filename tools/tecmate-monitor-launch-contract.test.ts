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

test('TecMate monitor launch contract documents the fixed-ROM discovery handoff', () => {
  assert.match(monitor, /launchExpansion:[\s\S]*call discoverExpansion[\s\S]*call validateExpansionVector[\s\S]*call BiosBankCallDirect/);
  assert.match(monitor, /discoverExpansion:[\s\S]*cp "E"[\s\S]*cp "X"[\s\S]*cp "P"[\s\S]*cp "R"[\s\S]*call BiosBankCallDirect/);
  assert.match(monitor, /runRoutine:[\s\S]*ld de,softBoot\s+;get return address\s+push de\s+;put return address on stack\s+jp \(hl\)/);
  assert.match(doc, /discovers an `EXPR` header/);
  assert.match(doc, /installed menu vector/);
  assert.match(doc, /bank-call machinery/);
  assert.match(doc, /restores the previous `SYS_CTRL`/);
  assert.match(doc, /If discovery fails/);
  assert.match(doc, /returns `A=FFh` with carry set/);
});

test('TecMate monitor launch contract names the bank-0 bootstrap ABI', () => {
  for (const name of [
    'EXP_BANK0_INSTALL',
    'SHL_ENTRY',
  ]) {
    assert.match(ops, new RegExp(`^${name}\\s+\\.equ\\s+`, 'm'));
    assert.match(doc, new RegExp(`\\\`${name}\\\``));
  }

  assert.match(doc, new RegExp(`\\\`EXP_BANK0_INSTALL\\\` \\| \\\`${docHex('EXP_BANK0_INSTALL')}\\\``));
  assert.match(doc, new RegExp(`\\\`SHL_ENTRY\\\` \\| \\\`${docHex('SHL_ENTRY')}\\\``));
  assert.match(doc, /installed menu vector \| monitor RAM/);
  assert.match(doc, /installed service vector \| monitor RAM/);
  assert.match(doc, /private\s+bank-0 source labels, not fixed public entry addresses/);
});

test('TecMate monitor launch contract is tied to the proof runner', () => {
  assert.equal(
    pkg.scripts['proof:tecmate-monitor-launch'],
    'npm run rom:check && node --experimental-strip-types tools/run-tecmate-monitor-launch-proof.ts',
  );
  assert.match(pkg.scripts.check, /npm run proof:tecmate-monitor-launch/);
  assert.match(doc, /npm run proof:tecmate-monitor-launch/);
  assert.match(runner, /symbolNumber\(MONITOR_D8_PATH, 'launchExpansion'\)/);
  assert.match(runner, /symbolNumber\(BANK0_D8_PATH, 'Tecm8ExpansionBank0Entry'\)/);
  assert.match(runner, /runInstalledExpansionCase/);
  assert.match(runner, /runMissingExpansionCase/);
  assert.match(runner, /expansionImage: false/);
  assert.match(runner, /assertClearedExpansionVectors/);
  assert.match(runner, /bank 0 entry marker/);
  assert.match(runner, /TEC-FS service marker/);
  assert.match(runner, /input service marker/);
  assert.match(runner, /shell entry marker/);
  assert.match(runner, /assertDemoVram/);
  assert.match(runner, /demo TMS9918 device active/);
  assert.match(runner, /demo VDU first splash character/);
  assert.match(runner, /demo status first character/);
  assert.match(runner, /demo input service bank side effect/);
  assert.match(runner, /demo TEC-FS mount side effect/);
  assert.match(runner, /bridge TEC-FS mount side effect/);
  assert.match(runner, /bridge returned carry clear/);
  assert.match(runner, /missing expansion TEC-FS mount side effect remains clear/);
  assert.match(runner, /missing expansion returned carry set/);
  assert.match(doc, /Installed expansion case:/);
  assert.match(doc, /TMS9918 VRAM contains the visible `TecMate` splash and `READY`/);
  assert.match(doc, /input parameter block reports the bank-6 neutral snapshot/);
  assert.match(doc, /TEC-FS parameter block reports the current mount geometry/);
  assert.match(doc, /Missing expansion case:/);
});
