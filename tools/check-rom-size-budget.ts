#!/usr/bin/env node
/**
 * Check the compiled TecMate ROM footprint against project size budgets.
 */

const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');

const root = resolve(__dirname, '..');
const bankBytes = 0x4000;
const monitorBytes = 0x4000;

type Budget = {
  role: string;
  softSpan: number;
  hardSpan: number;
};

type D8Segment = {
  start: number;
  end: number;
};

type D8File = {
  segments: D8Segment[];
};

const expansionBudgets: Budget[] = [
  { role: 'Shell, launcher, registry', softSpan: 0x0800, hardSpan: 0x1000 },
  { role: 'VDU/TMS9918 boundary', softSpan: 0x1000, hardSpan: 0x2000 },
  { role: 'TEC-FS boundary and block mapper', softSpan: 0x1000, hardSpan: 0x2000 },
  { role: 'RTC boundary', softSpan: 0x0400, hardSpan: 0x0800 },
  { role: 'GLCD boundary', softSpan: 0x0400, hardSpan: 0x0800 },
  { role: 'TEC-FS monitor-sector bridge', softSpan: 0x0400, hardSpan: 0x0800 },
  { role: 'Input snapshot boundary', softSpan: 0x0400, hardSpan: 0x0800 },
  { role: 'Assembler skeleton', softSpan: 0x2000, hardSpan: 0x3000 },
  { role: 'Run skeleton', softSpan: 0x1000, hardSpan: 0x2000 },
];

const totalExpansionSoftSpan = 0x8000;
const totalExpansionHardSpan = 0x10000;

function readJson(path: string): D8File {
  return JSON.parse(readFileSync(resolve(root, path), 'utf8')) as D8File;
}

function hex(value: number): string {
  return `${value.toString(16).toUpperCase().padStart(4, '0')}h`;
}

function spanForSegments(segments: D8Segment[]): { occupied: number; span: number; highWaterEnd: number } {
  if (segments.length === 0) {
    return { occupied: 0, span: 0, highWaterEnd: 0 };
  }

  const occupied = segments.reduce((sum, segment) => sum + segment.end - segment.start, 0);
  const low = Math.min(...segments.map((segment) => segment.start));
  const highWaterEnd = Math.max(...segments.map((segment) => segment.end));

  return {
    occupied,
    span: highWaterEnd - low,
    highWaterEnd,
  };
}

function expansionWindowSegments(segments: D8Segment[]): D8Segment[] {
  return segments
    .filter((segment) => segment.end > 0x8000 && segment.start < 0xc000)
    .map((segment) => ({
      start: Math.max(segment.start, 0x8000),
      end: Math.min(segment.end, 0xc000),
    }));
}

function fail(message: string): void {
  console.error(message);
  process.exitCode = 1;
}

function warn(message: string): void {
  console.warn(message);
}

function checkMonitor(): void {
  const d8 = readJson('build/roms/tec1g/tecm8/monitor/monitor.d8.json');
  const measurement = spanForSegments(d8.segments);

  if (measurement.span !== monitorBytes) {
    fail(`monitor span changed: got ${measurement.span}, expected exactly ${monitorBytes}`);
  }

  console.log(
    `monitor span=${measurement.span}/${monitorBytes} high=${hex(measurement.highWaterEnd)} fixed ROM is full`,
  );
}

function checkExpansion(): void {
  let totalSpan = 0;
  let totalOccupied = 0;

  for (const [bank, budget] of expansionBudgets.entries()) {
    const d8 = readJson(`build/roms/tec1g/tecm8/expansion/bank${bank}.d8.json`);
    const measurement = spanForSegments(expansionWindowSegments(d8.segments));
    totalSpan += measurement.span;
    totalOccupied += measurement.occupied;

    if (measurement.span > bankBytes) {
      fail(`bank ${bank} ${budget.role} exceeds 16K window: span=${measurement.span}`);
    }
    if (measurement.span > budget.hardSpan) {
      fail(
        `bank ${bank} ${budget.role} exceeds hard budget: span=${measurement.span}, hard=${budget.hardSpan}`,
      );
    } else if (measurement.span > budget.softSpan) {
      warn(
        `bank ${bank} ${budget.role} exceeds soft budget: span=${measurement.span}, soft=${budget.softSpan}`,
      );
    }

    console.log(
      `bank ${bank} ${budget.role}: occupied=${measurement.occupied} span=${measurement.span} hard=${budget.hardSpan} free=${bankBytes - measurement.span}`,
    );
  }

  if (totalSpan > totalExpansionHardSpan) {
    fail(`expansion total exceeds hard budget: span=${totalSpan}, hard=${totalExpansionHardSpan}`);
  } else if (totalSpan > totalExpansionSoftSpan) {
    warn(`expansion total exceeds soft budget: span=${totalSpan}, soft=${totalExpansionSoftSpan}`);
  }

  console.log(
    `expansion total: occupied=${totalOccupied} span=${totalSpan} hard=${totalExpansionHardSpan} free=${bankBytes * expansionBudgets.length - totalSpan}`,
  );
}

checkMonitor();
checkExpansion();
