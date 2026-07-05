#!/usr/bin/env node
/**
 * Compare the compiled TecMate ROM footprint with the checked-in baseline.
 */

const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { spawnSync } = require('node:child_process');

const root = resolve(__dirname, '..');
const baselinePath = resolve(root, 'docs/metrics/rom-size-baseline.json');

type BankReport = {
  bank: number;
  role: string;
  occupied: number;
  span: number;
};

type RomSizeReport = {
  schema?: string;
  monitor: {
    occupied: number;
    span: number;
    highWaterEnd: number;
  };
  banks: BankReport[];
  expansionTotal: {
    occupied: number;
    span: number;
    hardSpan: number;
  };
};

const baselineSchema = 'tecm8-rom-size-baseline-v1';

function runJsonReport(): RomSizeReport {
  const build = spawnSync('npm', ['run', 'rom:check', '--silent'], {
    cwd: root,
    encoding: 'utf8',
    stdio: 'pipe',
  });
  if (build.status !== 0) {
    process.stdout.write(build.stdout ?? '');
    process.stderr.write(build.stderr ?? '');
    throw new Error(`rom:check failed with status ${build.status}`);
  }

  const result = spawnSync('node', ['--experimental-strip-types', 'tools/check-rom-size-budget.ts', '--json'], {
    cwd: root,
    encoding: 'utf8',
    stdio: 'pipe',
  });
  if (result.status !== 0) {
    process.stdout.write(result.stdout ?? '');
    process.stderr.write(result.stderr ?? '');
    throw new Error(`check-rom-size-budget --json failed with status ${result.status}`);
  }

  return JSON.parse(result.stdout) as RomSizeReport;
}

function readBaseline(): RomSizeReport {
  const baseline = JSON.parse(readFileSync(baselinePath, 'utf8')) as RomSizeReport;
  if (baseline.schema !== baselineSchema) {
    throw new Error(`baseline schema mismatch: got ${String(baseline.schema)}, expected ${baselineSchema}`);
  }
  return baseline;
}

function delta(current: number, baseline: number): string {
  const diff = current - baseline;
  if (diff > 0) {
    return `+${diff}`;
  }
  return `${diff}`;
}

function findBaselineBank(baseline: RomSizeReport, bank: number): BankReport {
  const report = baseline.banks.find((entry) => entry.bank === bank);
  if (!report) {
    throw new Error(`baseline missing bank ${bank}`);
  }
  return report;
}

function validateBaselineRoles(current: RomSizeReport, baseline: RomSizeReport): void {
  for (const bank of current.banks) {
    const base = findBaselineBank(baseline, bank.bank);
    if (base.role !== bank.role) {
      throw new Error(`baseline role mismatch for bank ${bank.bank}: got "${base.role}", expected "${bank.role}"`);
    }
  }
}

function main(): void {
  const baseline = readBaseline();
  const current = runJsonReport();
  validateBaselineRoles(current, baseline);

  console.log('# TecMate ROM Size Delta');
  console.log('');
  console.log('| Area | Current Span | Span Delta | Current Occupied | Occupied Delta |');
  console.log('| --- | ---: | ---: | ---: | ---: |');
  console.log(
    `| Fixed monitor | ${current.monitor.span} | ${delta(
      current.monitor.span,
      baseline.monitor.span,
    )} | ${current.monitor.occupied} | ${delta(current.monitor.occupied, baseline.monitor.occupied)} |`,
  );
  console.log(
    `| Expansion total | ${current.expansionTotal.span} | ${delta(
      current.expansionTotal.span,
      baseline.expansionTotal.span,
    )} | ${current.expansionTotal.occupied} | ${delta(
      current.expansionTotal.occupied,
      baseline.expansionTotal.occupied,
    )} |`,
  );
  for (const bank of current.banks) {
    const base = findBaselineBank(baseline, bank.bank);
    console.log(
      `| Bank ${bank.bank} ${bank.role} | ${bank.span} | ${delta(bank.span, base.span)} | ${bank.occupied} | ${delta(
        bank.occupied,
        base.occupied,
      )} |`,
    );
  }
}

main();
