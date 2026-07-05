#!/usr/bin/env node
/**
 * Print a compact TecMate milestone status with ROM footprint.
 */

const { existsSync, readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { spawnSync } = require('node:child_process');

const root = resolve(__dirname, '..');
const bankBytes = 0x4000;
const monitorBytes = 0x4000;
const totalExpansionHardSpan = 0x10000;

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

type ProofStatus = {
  name: string;
  path: string;
  isValid: (data: unknown) => boolean;
};

const banks = [
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

const proofStatuses: ProofStatus[] = [
  {
    name: 'monitor launch',
    path: 'proofs/tecmate-monitor-launch/tecmate-monitor-launch-last-run.json',
    isValid: (data) => {
      const installed = readObject(data, 'installed');
      const missing = readObject(data, 'missing');
      return (
        readString(data, 'result') === 'ok' &&
        hasNumber(installed, 'instructions') &&
        hasNumber(installed, 'bridgeInstructions') &&
        hasNumber(installed, 'menuVectorAddress') &&
        hasNumber(installed, 'expectedMenuAddress') &&
        hasNumber(missing, 'instructions') &&
        hasNumber(missing, 'bridgeInstructions')
      );
    },
  },
  {
    name: 'shell command loop',
    path: 'proofs/shell-commands/last-run.json',
    isValid: (data) =>
      readString(data, 'result') === 'ok' &&
      readString(data, 'resultMarker') === '0x42' &&
      hasNumber(data, 'instructions') &&
      hasNumber(data, 'proofCase'),
  },
  {
    name: 'VDU/TMS9918',
    path: 'proofs/tms9918-bank/tms9918-bank-proof-last-run.json',
    isValid: (data) => isOkProof(data) && hasNumber(data, 'tmsRegister7') && readArray(data, 'trace').length > 0,
  },
  {
    name: 'TEC-FS',
    path: 'proofs/tecfs-bank/tecfs-bank-proof-last-run.json',
    isValid: (data) => isOkProof(data) && readArray(data, 'params').length > 0 && readArray(data, 'trace').length > 0,
  },
  {
    name: 'input snapshot',
    path: 'proofs/input-bank/input-bank-proof-last-run.json',
    isValid: (data) => isOkProof(data) && readArray(data, 'params').length >= 8,
  },
  {
    name: 'bank ABI',
    path: 'proofs/bank-abi/bank-abi-proof-last-run.json',
    isValid: (data) => isOkProof(data) && readArray(data, 'trace').length > 0,
  },
];

function run(command: string, args: string[]): void {
  const result = spawnSync(command, args, {
    cwd: root,
    encoding: 'utf8',
    stdio: 'pipe',
  });

  if (result.status !== 0) {
    process.stdout.write(result.stdout ?? '');
    process.stderr.write(result.stderr ?? '');
    throw new Error(`${command} ${args.join(' ')} failed with status ${result.status}`);
  }
}

function readJson(path: string): D8File {
  return JSON.parse(readFileSync(resolve(root, path), 'utf8')) as D8File;
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

function hex(value: number): string {
  return `${value.toString(16).toUpperCase().padStart(4, '0')}h`;
}

function isRecord(data: unknown): data is Record<string, unknown> {
  return typeof data === 'object' && data !== null && !Array.isArray(data);
}

function hasObject(data: unknown, key: string): boolean {
  return isRecord(data) && isRecord(data[key]);
}

function readObject(data: unknown, key: string): Record<string, unknown> | undefined {
  return isRecord(data) && isRecord(data[key]) ? data[key] : undefined;
}

function hasNumber(data: unknown, key: string): boolean {
  return isRecord(data) && typeof data[key] === 'number';
}

function readArray(data: unknown, key: string): unknown[] {
  return isRecord(data) && Array.isArray(data[key]) ? data[key] : [];
}

function readString(data: unknown, key: string): string | undefined {
  return isRecord(data) && typeof data[key] === 'string' ? data[key] : undefined;
}

function isOkProof(data: unknown): boolean {
  return readString(data, 'result') === 'ok' && hasNumber(data, 'instructions') && hasNumber(data, 'resultMarker');
}

function readProofStatus(proof: ProofStatus): string {
  const path = resolve(root, proof.path);
  if (!existsSync(path)) {
    return 'missing';
  }

  try {
    const data = JSON.parse(readFileSync(path, 'utf8'));
    return proof.isValid(data) ? 'ok' : 'incomplete';
  } catch {
    return 'unreadable';
  }
}

function main(): void {
  run('npm', ['run', 'rom:size:check', '--silent']);

  const monitor = spanForSegments(readJson('build/roms/tec1g/tecm8/monitor/monitor.d8.json').segments);
  const bankReports = banks.map((role, bank) => {
    const d8 = readJson(`build/roms/tec1g/tecm8/expansion/bank${bank}.d8.json`);
    const measurement = spanForSegments(expansionWindowSegments(d8.segments));
    return { bank, role, ...measurement };
  });
  const expansionSpan = bankReports.reduce((sum, bank) => sum + bank.span, 0);
  const expansionOccupied = bankReports.reduce((sum, bank) => sum + bank.occupied, 0);

  console.log('TecMate milestone status');
  console.log(`monitor: span=${monitor.span}/${monitorBytes} high=${hex(monitor.highWaterEnd)}`);
  console.log(`expansion: occupied=${expansionOccupied} span=${expansionSpan}/${totalExpansionHardSpan} hard-budget`);
  for (const report of bankReports) {
    console.log(
      `bank ${report.bank}: span=${report.span.toString().padStart(4)} occupied=${report.occupied
        .toString()
        .padStart(4)} ${report.role}`,
    );
  }
  for (const proof of proofStatuses) {
    console.log(`last-run proof ${proof.name}: ${readProofStatus(proof)}`);
  }
}

main();
