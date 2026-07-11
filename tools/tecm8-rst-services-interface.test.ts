const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const ops = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank_ops.asmi'), 'utf8');
const bank0 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank0.asm'), 'utf8');
const bank1 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank1.asm'), 'utf8');
const bank2 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank2.asm'), 'utf8');
const bank3 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank3.asm'), 'utf8');
const bank4 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank4.asm'), 'utf8');
const bank5 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank5.asm'), 'utf8');
const bank6 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank6.asm'), 'utf8');
const bank7 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank7.asm'), 'utf8');
const bank8 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank8.asm'), 'utf8');
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
  const match = bank0.match(/Tecm8ServiceRegistry:\n([\s\S]*?)Tecm8ServiceRegistryEnd:/);
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

function equatesWithPrefix(prefix: string): Array<{ name: string; value: number }> {
  return [...ops.matchAll(new RegExp(`^(${prefix}[A-Z0-9_]+)\\s+\\.equ\\s+([^\\n;]+)`, 'gm'))]
    .map((match) => ({
      name: match[1],
      value: parseNumber(match[2]),
    }));
}

function assertUniqueSelectors(entries: Array<{ name: string; value: number }>, label: string): void {
  const seen = new Map<number, string>();

  for (const entry of entries) {
    assert.ok(!seen.has(entry.value), `${label} ${entry.name} duplicates ${hexByte(entry.value)} used by ${seen.get(entry.value)}`);
    seen.set(entry.value, entry.name);
  }
}

function assertContiguous(entries: Array<{ name: string; value: number }>, orderedNames: string[], label: string): void {
  const values = new Map(entries.map((entry) => [entry.name, entry.value]));
  assert.equal(entries.length, orderedNames.length, `${label} ordered list should cover every selector`);
  for (const [index, name] of orderedNames.entries()) {
    assert.equal(values.get(name), values.get(orderedNames[0])! + index, `${label} ${name} should be contiguous`);
  }
}

function entryBlock(source: string, startLabel: string, endLabel: string): string {
  const match = source.match(new RegExp(`${startLabel}:\\n([\\s\\S]*?)${endLabel}:`));
  if (!match) {
    throw new Error(`missing block ${startLabel}..${endLabel}`);
  }
  return match[1];
}

function assertAdjacentDispatch(source: string, selector: string, labelPrefix: string): void {
  assert.match(source, new RegExp(`cp ${selector}\\s*\\n\\s*jp z,`), `${labelPrefix} should dispatch ${selector}`);
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

test('TECM8 bank-local service selector families are unique and byte-sized', () => {
  for (const prefix of ['VDU_SVC_', 'TMS_SVC_', 'TFS_SVC_', 'RTC_SVC_', 'GLC_SVC_', 'INP_SVC_', 'ASM_SVC_', 'RUN_SVC_']) {
    const entries = equatesWithPrefix(prefix);
    assert.ok(entries.length > 0, `${prefix} should define bank-local selectors`);
    assertUniqueSelectors(entries, prefix);

    for (const entry of entries) {
      assert.ok(entry.value > 0 && entry.value <= 0xff, `${entry.name} should be a byte-sized bank-local selector`);
      assert.ok(entry.value < equateValue('SVC_BASE'), `${entry.name} should stay out of the public RST service range`);
    }
  }
});

test('TECM8 bank-local dispatchers mention every selector they expose', () => {
  const vduServices = equatesWithPrefix('VDU_SVC_');
  const tmsServices = equatesWithPrefix('TMS_SVC_');
  assertContiguous(
    vduServices,
    [
      'VDU_SVC_INIT',
      'VDU_SVC_CLEAR',
      'VDU_SVC_SET_CURSOR',
      'VDU_SVC_PUT_CHAR',
      'VDU_SVC_PUT_STRING',
      'VDU_SVC_NEWLINE',
      'VDU_SVC_SET_ROWCOL',
      'VDU_SVC_SCROLL_UP',
      'VDU_SVC_STATUS_LINE',
      'VDU_SVC_PUT_STRING_N',
    ],
    'bank1 VDU selector',
  );
  assertContiguous(
    tmsServices,
    ['TMS_SVC_INIT', 'TMS_SVC_SET_REGISTER', 'TMS_SVC_WRITE_VRAM', 'TMS_SVC_FILL_VRAM', 'TMS_SVC_READ_VRAM'],
    'bank1 TMS selector',
  );
  assert.match(bank1, /cp VDU_SVC_INIT[\s\S]*cp VDU_SVC_PUT_STRING_N\+1[\s\S]*Tecm8VduServiceTable:/);
  assert.match(bank1, /cp TMS_SVC_INIT[\s\S]*cp TMS_SVC_READ_VRAM\+1[\s\S]*Tecm8TmsServiceTable:/);
  assert.equal((bank1.match(/^\s*j[pr]\s+vdu[A-Z][A-Za-z0-9]+Impl/gm) ?? []).length, vduServices.length);
  assert.equal((bank1.match(/^\s*j[pr]\s+tms[A-Z][A-Za-z0-9]+Impl/gm) ?? []).length, tmsServices.length);

  for (const name of equatesWithPrefix('TFS_SVC_').map((entry) => entry.name)) {
    assertAdjacentDispatch(bank2, name, 'bank2');
  }
  assert.match(bank0, /\.db\s+RTC_SVC_TOOL_ENTRY/);
  assert.match(entryBlock(bank3, 'Tecm8ExpansionBank3Entry', 'rtcToolEntry'), /cp RTC_SVC_TOOL_ENTRY\s*\n\s*jp z,rtcServiceEntryImpl/);
  for (const name of equatesWithPrefix('RTC_SVC_').map((entry) => entry.name).filter((name) => name !== 'RTC_SVC_TOOL_ENTRY')) {
    assertAdjacentDispatch(bank3, name, 'bank3');
  }
  for (const name of equatesWithPrefix('GLC_SVC_').map((entry) => entry.name)) {
    assertAdjacentDispatch(bank4, name, 'bank4');
  }
  for (const name of equatesWithPrefix('INP_SVC_').map((entry) => entry.name)) {
    assertAdjacentDispatch(bank6, name, 'bank6');
  }
  for (const name of equatesWithPrefix('ASM_SVC_').map((entry) => entry.name)) {
    assertAdjacentDispatch(bank7, name, 'bank7');
  }
  for (const name of equatesWithPrefix('RUN_SVC_').map((entry) => entry.name)) {
    assertAdjacentDispatch(bank8, name, 'bank8');
  }
  assert.match(bank5, /cp TFS_DRIVER_OP_READ\s*\n\s*jp z,tecfsSectorBridgeRead\s*\n\s*cp TFS_DRIVER_OP_WRITE\s*\n\s*jp z,tecfsSectorBridgeWrite/);
});
