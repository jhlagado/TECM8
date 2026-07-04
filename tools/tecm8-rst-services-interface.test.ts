const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const ops = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank_ops.asmi'), 'utf8');
const bank0 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank0.asm'), 'utf8');
const rstInterface = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/tecm8-rst-services.asmi'), 'utf8');

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
  const expression = equateExpression(name);
  return expression
    .split('+')
    .map((part) => parseNumber(part))
    .reduce((sum, value) => sum + value, 0);
}

function hexByte(value: number): string {
  return `0x${value.toString(16).toUpperCase().padStart(2, '0')}`;
}

function registeredServiceNames(): string[] {
  const match = bank0.match(/@Tecm8ServiceRegistry:\n([\s\S]*?)@Tecm8ServiceRegistryEnd:/);
  assert.ok(match, 'missing Tecm8ServiceRegistry block');
  return [...match[1].matchAll(/^\s*\.db\s+([A-Z0-9_]+),/gm)].map((entry) => entry[1]);
}

function exactServiceContracts(): Array<{ selector: number; name: string }> {
  return [...rstInterface.matchAll(/^service rst 0x10 C (0x[0-9A-Fa-f]{2}) ([A-Z0-9_]+)$/gm)]
    .map((match) => ({
      selector: Number.parseInt(match[1].slice(2), 16),
      name: match[2],
    }));
}

test('TECM8 RST 10h interface has exact contracts for registered services', () => {
  assert.match(rstInterface, /service rst 0x10 C >= 0x60 TECMATE_EXPANSION_SERVICE/);

  for (const name of registeredServiceNames()) {
    const value = hexByte(equateValue(name));
    const servicePattern = new RegExp(`service rst 0x10 C ${value} ${name}[\\s\\S]*?out A,carry[\\s\\S]*?end`);
    assert.match(rstInterface, servicePattern, `missing exact RST contract for ${name}`);
  }
});

test('TECM8 registered expansion services have unique selectors in the expansion range', () => {
  const seen = new Map<number, string>();

  for (const name of registeredServiceNames()) {
    const selector = equateValue(name);
    assert.ok(selector >= equateValue('SVC_BASE'), `${name} should be in expansion service range`);
    assert.ok(!seen.has(selector), `${name} duplicates selector ${hexByte(selector)} used by ${seen.get(selector)}`);
    seen.set(selector, name);
  }
});

test('TECM8 exact RST contracts are unique and intentionally scoped', () => {
  const seen = new Map<number, string>();
  const registered = new Set(registeredServiceNames());
  const allowedNonRegistryContracts = new Set(['MON_SYS_GET', 'ABI_PROBE_NESTED']);

  for (const contract of exactServiceContracts()) {
    assert.ok(
      !seen.has(contract.selector),
      `${contract.name} duplicates exact RST selector ${hexByte(contract.selector)} used by ${seen.get(contract.selector)}`,
    );
    seen.set(contract.selector, contract.name);

    assert.ok(
      registered.has(contract.name) || allowedNonRegistryContracts.has(contract.name),
      `${contract.name} exact RST contract should be registered or explicitly allowed`,
    );
  }
});
