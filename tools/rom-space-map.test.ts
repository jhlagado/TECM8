const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const bankBytes = 16384;

function readJson(path: string): any {
  return JSON.parse(readFileSync(resolve(root, path), 'utf8'));
}

function hex(value: number): string {
  return `${value.toString(16).toUpperCase().padStart(4, '0')}h`;
}

function bankMeasurement(bank: number): { occupied: number; span: number; highWaterEnd: number; freeAfterHighWater: number } {
  const d8 = readJson(`build/roms/tec1g/tecm8/expansion/bank${bank}.d8.json`);
  const visibleSegments = d8.segments.filter((segment: { start: number; end: number }) => {
    return segment.end > 0x8000 && segment.start < 0xc000;
  });
  const occupied = visibleSegments.reduce((sum: number, segment: { start: number; end: number }) => {
    return sum + segment.end - segment.start;
  }, 0);
  const low = Math.min(...visibleSegments.map((segment: { start: number }) => segment.start));
  const highWaterEnd = Math.max(...visibleSegments.map((segment: { end: number }) => segment.end));
  const span = highWaterEnd - low;

  return {
    occupied,
    span,
    highWaterEnd,
    freeAfterHighWater: bankBytes - span,
  };
}

function symbolAddress(d8Path: string, name: string): number {
  const d8 = readJson(d8Path);
  const symbol = d8.symbols.find((entry: { name: string }) => entry.name === name);
  assert.ok(symbol, `missing symbol ${name} in ${d8Path}`);
  return symbol.address ?? symbol.value;
}

test('TecMate ROM space map records current monitor and expansion measurements', () => {
  const doc = readFileSync(resolve(root, 'docs/mon3/tecmate-rom-space-map.md'), 'utf8');
  const monitor = readJson('build/roms/tec1g/tecm8/monitor/monitor.d8.json');
  const monitorLow = Math.min(...monitor.segments.map((segment: { start: number }) => segment.start));
  const monitorHigh = Math.max(...monitor.segments.map((segment: { end: number }) => segment.end));
  const monitorSpan = monitorHigh - monitorLow;

  assert.ok(doc.includes(`monitor source span is \`${monitorSpan}\` bytes`));
  assert.ok(doc.includes('High-water end: the D8 segment end address, which is end-exclusive.'));

  const roles = [
    'Shell, launcher, registry',
    'VDU/TMS9918 boundary',
    'TEC-FS boundary and block mapper',
    'RTC boundary',
    'GLCD boundary',
    'TEC-FS monitor-sector bridge',
    'Input snapshot boundary',
    'Assembler skeleton',
    'Run skeleton',
  ];
  let totalOccupied = 0;
  let totalSpan = 0;

  for (const [bank, role] of roles.entries()) {
    const measurement = bankMeasurement(bank);
    totalOccupied += measurement.occupied;
    totalSpan += measurement.span;
    const text = `| ${bank} | ${role} | \`${measurement.occupied}\` | \`${measurement.span}\` | \`${hex(measurement.highWaterEnd)}\` | \`${measurement.freeAfterHighWater}\` |`;
    assert.ok(doc.includes(text), `space map should include ${text}`);
  }

  assert.ok(doc.includes(`Expansion occupied bytes: \`${totalOccupied}\``));
  assert.ok(doc.includes(`Expansion high-water span total: \`${totalSpan}\``));
  assert.match(doc, /Latest TEC-FS geometry-line milestone delta/);
  assert.match(doc, /bank 0 span: 997 -> 995 bytes/);
  assert.match(doc, /expansion total span: 2668 -> 2666 bytes/);
  assert.match(doc, /fixed monitor span: unchanged at 16384 bytes/);
});

test('TecMate ROM space map classifies fixed-ROM and expansion responsibilities', () => {
  const doc = readFileSync(resolve(root, 'docs/mon3/tecmate-rom-space-map.md'), 'utf8');

  for (const text of [
    '| Reset, soft boot, NMI/INT/RST stubs | Required recovery and compatibility entry points. | Keep fixed. |',
    '| Bank switching and far-call services | Required because `C000h-FFFFh` is the only stable code region while `8000h-BFFFh` changes banks. | Keep fixed. |',
    '| Core RST 10h BIOS services | Required stable ABI for higher ROMs and RAM programs. | Keep fixed and document carefully. |',
    '| Expansion discovery hook | Required bridge from the MON3 menu into a bank-0 supervisor. | Keep fixed as a tiny generic socket. |',
    '| PATA and FAT32 compatibility | Not a fixed-ROM requirement for the TecMate direction. | Replace with TEC-FS path; move compatibility elsewhere if retained. |',
    '| VDU/TMS9918 console | Core TecMate user interface service. | Keep in expansion ROM behind the banked ABI. |',
  ]) {
    assert.ok(doc.includes(text), `space map should classify: ${text}`);
  }

  assert.match(doc, /GLCD remains a low-priority containment issue/);
  assert.doesNotMatch(doc, /next meaningful space work should measure real candidate moves.*GLCD/s);
});

test('TecMate ROM space map records current bank 0 private boundary labels', () => {
  const doc = readFileSync(resolve(root, 'docs/mon3/tecmate-rom-space-map.md'), 'utf8');
  const bank0D8 = 'build/roms/tec1g/tecm8/expansion/bank0.d8.json';

  const rows = [
    ['Bank 0 service dispatcher', 'Tecm8ServiceCall', 'Private table-driven label installed into the service vector.'],
    ['Bank 0 service registry', 'Tecm8ServiceRegistry', 'Private service ID to bank/address/target-`A` table.'],
    ['Bank 0 shell entry', 'Tecm8ShellEntry', 'Private descriptor and VDU home-screen path for `SHL_ENTRY`.'],
    ['Bank 0 info marker', 'Tecm8ExpansionBank0Info', 'Private marker, not a fixed ABI location.'],
  ];

  for (const [label, symbol, note] of rows) {
    const row = `| ${label} | \`${hex(symbolAddress(bank0D8, symbol))}\` | ${note} |`;
    assert.ok(doc.includes(row), `space map should include ${row}`);
  }
});
