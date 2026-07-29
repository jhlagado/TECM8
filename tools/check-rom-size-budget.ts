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

type Measurement = {
  occupied: number;
  span: number;
  highWaterEnd: number;
};

type BankReport = {
  bank: number;
  role: string;
  occupied: number;
  span: number;
  softSpan: number;
  hardSpan: number;
  highWaterEnd: number;
  freeAfterHighWater: number;
};

type RomSizeReport = {
  monitor: Measurement;
  banks: BankReport[];
  expansionTotal: {
    occupied: number;
    span: number;
    softSpan: number;
    hardSpan: number;
    freeAfterHighWater: number;
  };
};

const expansionBudgets: Budget[] = [
  { role: 'Shell, launcher, registry', softSpan: 0x0800, hardSpan: 0x1000 },
  { role: 'VDU/TMS9918 boundary', softSpan: 0x1000, hardSpan: 0x2000 },
  { role: 'TEC-FS boundary and block mapper', softSpan: 0x1000, hardSpan: 0x2000 },
  { role: 'RTC boundary', softSpan: 0x0400, hardSpan: 0x0800 },
  { role: 'Editor and optional GLCD boundary', softSpan: 0x1000, hardSpan: 0x2000 },
  { role: 'TEC-FS monitor-sector bridge', softSpan: 0x0400, hardSpan: 0x0800 },
  { role: 'Input snapshot boundary', softSpan: 0x0400, hardSpan: 0x0800 },
  { role: 'Phase-one self-hosted assembler', softSpan: 0x2000, hardSpan: 0x3000 },
  { role: 'Validated loader and runner', softSpan: 0x1000, hardSpan: 0x2000 },
];

const totalExpansionSoftSpan = 0x8000;
const totalExpansionHardSpan = 0x10000;

function readJson(path: string): D8File {
  return JSON.parse(readFileSync(resolve(root, path), 'utf8')) as D8File;
}

function hex(value: number): string {
  return `${value.toString(16).toUpperCase().padStart(4, '0')}h`;
}

function spanForSegments(segments: D8Segment[]): Measurement {
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

function measureRomSize(): RomSizeReport {
  const d8 = readJson('build/roms/tec1g/tecm8/monitor/monitor.d8.json');
  const monitor = spanForSegments(d8.segments);
  const banks: BankReport[] = [];
  let totalSpan = 0;
  let totalOccupied = 0;

  for (const [bank, budget] of expansionBudgets.entries()) {
    const bankD8 = readJson(`build/roms/tec1g/tecm8/expansion/bank${bank}.d8.json`);
    const measurement = spanForSegments(expansionWindowSegments(bankD8.segments));
    totalSpan += measurement.span;
    totalOccupied += measurement.occupied;

    banks.push({
      bank,
      role: budget.role,
      occupied: measurement.occupied,
      span: measurement.span,
      softSpan: budget.softSpan,
      hardSpan: budget.hardSpan,
      highWaterEnd: measurement.highWaterEnd,
      freeAfterHighWater: bankBytes - measurement.span,
    });
  }

  return {
    monitor,
    banks,
    expansionTotal: {
      occupied: totalOccupied,
      span: totalSpan,
      softSpan: totalExpansionSoftSpan,
      hardSpan: totalExpansionHardSpan,
      freeAfterHighWater: bankBytes * expansionBudgets.length - totalSpan,
    },
  };
}

function checkMonitor(report: RomSizeReport): void {
  const measurement = report.monitor;

  if (measurement.span !== monitorBytes) {
    fail(`monitor span changed: got ${measurement.span}, expected exactly ${monitorBytes}`);
  }

  console.log(
    `monitor span=${measurement.span}/${monitorBytes} high=${hex(measurement.highWaterEnd)} fixed ROM is full`,
  );
}

function checkExpansion(report: RomSizeReport): void {
  for (const bank of report.banks) {
    if (bank.span > bankBytes) {
      fail(`bank ${bank.bank} ${bank.role} exceeds 16K window: span=${bank.span}`);
    }
    if (bank.span > bank.hardSpan) {
      fail(`bank ${bank.bank} ${bank.role} exceeds hard budget: span=${bank.span}, hard=${bank.hardSpan}`);
    } else if (bank.span > bank.softSpan) {
      warn(`bank ${bank.bank} ${bank.role} exceeds soft budget: span=${bank.span}, soft=${bank.softSpan}`);
    }

    console.log(
      `bank ${bank.bank} ${bank.role}: occupied=${bank.occupied} span=${bank.span} soft=${bank.softSpan} softFree=${softFree(bank.span, bank.softSpan)} hard=${bank.hardSpan} free=${bank.freeAfterHighWater}`,
    );
  }

  if (report.expansionTotal.span > totalExpansionHardSpan) {
    fail(`expansion total exceeds hard budget: span=${report.expansionTotal.span}, hard=${totalExpansionHardSpan}`);
  } else if (report.expansionTotal.span > totalExpansionSoftSpan) {
    warn(`expansion total exceeds soft budget: span=${report.expansionTotal.span}, soft=${totalExpansionSoftSpan}`);
  }

  console.log(
    `expansion total: occupied=${report.expansionTotal.occupied} span=${report.expansionTotal.span} soft=${report.expansionTotal.softSpan} softFree=${softFree(report.expansionTotal.span, report.expansionTotal.softSpan)} hard=${totalExpansionHardSpan} free=${report.expansionTotal.freeAfterHighWater}`,
  );
}

function validateBudget(report: RomSizeReport): void {
  if (report.monitor.span !== monitorBytes) {
    fail(`monitor span changed: got ${report.monitor.span}, expected exactly ${monitorBytes}`);
  }

  for (const bank of report.banks) {
    if (bank.span > bankBytes) {
      fail(`bank ${bank.bank} ${bank.role} exceeds 16K window: span=${bank.span}`);
    }
    if (bank.span > bank.hardSpan) {
      fail(`bank ${bank.bank} ${bank.role} exceeds hard budget: span=${bank.span}, hard=${bank.hardSpan}`);
    } else if (bank.span > bank.softSpan) {
      warn(`bank ${bank.bank} ${bank.role} exceeds soft budget: span=${bank.span}, soft=${bank.softSpan}`);
    }
  }

  if (report.expansionTotal.span > totalExpansionHardSpan) {
    fail(`expansion total exceeds hard budget: span=${report.expansionTotal.span}, hard=${totalExpansionHardSpan}`);
  } else if (report.expansionTotal.span > totalExpansionSoftSpan) {
    warn(`expansion total exceeds soft budget: span=${report.expansionTotal.span}, soft=${totalExpansionSoftSpan}`);
  }
}

function statusFor(span: number, softSpan: number, hardSpan: number): string {
  if (span > hardSpan) {
    return 'hard fail';
  }
  if (span > softSpan) {
    return 'soft warn';
  }
  return 'ok';
}

function softFree(span: number, softSpan: number): number {
  return softSpan - span;
}

function printSummary(report: RomSizeReport): void {
  console.log('# TecMate ROM Footprint');
  console.log('');
  console.log(`Fixed monitor span: ${report.monitor.span}/${monitorBytes} bytes, high ${hex(report.monitor.highWaterEnd)}.`);
  console.log(
    `Expansion total span: ${report.expansionTotal.span}/${report.expansionTotal.hardSpan} bytes hard budget, occupied ${report.expansionTotal.occupied} bytes.`,
  );
  console.log('');
  console.log('| Bank | Role | Span | Soft | Soft Free | Hard | Free | Status |');
  console.log('| ---: | --- | ---: | ---: | ---: | ---: | ---: | --- |');
  for (const bank of report.banks) {
    console.log(
      `| ${bank.bank} | ${bank.role} | ${bank.span} | ${bank.softSpan} | ${softFree(bank.span, bank.softSpan)} | ${bank.hardSpan} | ${bank.freeAfterHighWater} | ${statusFor(bank.span, bank.softSpan, bank.hardSpan)} |`,
    );
  }
}

const report = measureRomSize();

if (process.argv.includes('--summary')) {
  printSummary(report);
  validateBudget(report);
} else if (process.argv.includes('--json')) {
  console.log(JSON.stringify(report, null, 2));
  validateBudget(report);
} else {
  checkMonitor(report);
  checkExpansion(report);
}
