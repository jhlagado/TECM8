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
  const occupied = d8.segments.reduce((sum: number, segment: { start: number; end: number }) => {
    return sum + segment.end - segment.start;
  }, 0);
  const low = Math.min(...d8.segments.map((segment: { start: number }) => segment.start));
  const highWaterEnd = Math.max(...d8.segments.map((segment: { end: number }) => segment.end));
  const span = highWaterEnd - low;

  return {
    occupied,
    span,
    highWaterEnd,
    freeAfterHighWater: bankBytes - span,
  };
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
    'Reserved stub',
    'Reserved stub',
    'Reserved stub',
    'Reserved stub',
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
});

test('TecMate ROM space map classifies fixed-ROM and expansion responsibilities', () => {
  const doc = readFileSync(resolve(root, 'docs/mon3/tecmate-rom-space-map.md'), 'utf8');

  for (const text of [
    '| Reset, soft boot, NMI/INT/RST stubs | Required recovery and compatibility entry points. | Keep fixed. |',
    '| Bank switching and far-call services | Required because `C000h-FFFFh` is the only stable code region while `8000h-BFFFh` changes banks. | Keep fixed. |',
    '| Core RST 10h BIOS services | Required stable ABI for higher ROMs and RAM programs. | Keep fixed and document carefully. |',
    '| TecMate launcher | Required bridge from the MON3 menu into expansion bank 0. | Keep fixed as a tiny handoff. |',
    '| PATA and FAT32 compatibility | Not a fixed-ROM requirement for the TecMate direction. | Replace with TEC-FS path; move compatibility elsewhere if retained. |',
    '| VDU/TMS9918 console | Core TecMate user interface service. | Keep in expansion ROM behind the banked ABI. |',
  ]) {
    assert.ok(doc.includes(text), `space map should classify: ${text}`);
  }

  assert.match(doc, /GLCD remains a low-priority containment issue/);
  assert.doesNotMatch(doc, /next meaningful space work should measure real candidate moves.*GLCD/s);
});
