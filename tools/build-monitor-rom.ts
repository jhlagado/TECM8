#!/usr/bin/env node
/**
 * Assemble the inactive TECM8 monitor ROM replacement image.
 */

const { mkdirSync, writeFileSync } = require('node:fs');
const { dirname, resolve } = require('node:path');

const TECM8_ROOT = resolve(__dirname, '..');
const AZM_ROOT = process.env.AZM_ROOT ? resolve(process.env.AZM_ROOT) : undefined;
const SOURCE_FILE = resolve(TECM8_ROOT, 'roms/tec1g/tecm8/monitor/monitor.asm');
const PROJECT_BIN_PATH = resolve(TECM8_ROOT, 'roms/tec1g/tecm8/monitor/monitor.bin');
const BUILD_BIN_PATH = resolve(TECM8_ROOT, 'build/roms/tec1g/tecm8/monitor/monitor.bin');
const BUILD_D8_PATH = resolve(TECM8_ROOT, 'build/roms/tec1g/tecm8/monitor/monitor.d8.json');
const ROM_START = 0xc000;
const ROM_BYTES = 16 * 1024;
const ROM_END_EXCLUSIVE = ROM_START + ROM_BYTES;

type Diagnostic = {
  id?: string;
  message?: string;
  severity?: string;
};

type D8Segment = {
  start: number;
  end: number;
};

type D8Map = {
  files?: Record<string, { segments?: D8Segment[] }>;
};

type CompileResult = {
  diagnostics: Diagnostic[];
  artifacts: Array<{ kind: string; bytes?: Uint8Array; json?: D8Map }>;
};

function toHex(value: number): string {
  return `0x${value.toString(16).toUpperCase().padStart(4, '0')}`;
}

function getMappedEnd(d8: D8Map): number | undefined {
  const ends = Object.values(d8.files ?? {})
    .flatMap((file) => file.segments ?? [])
    .map((segment) => segment.end);
  return ends.length === 0 ? undefined : Math.max(...ends);
}

async function main(): Promise<void> {
  const { compile, defaultFormatWriters } = AZM_ROOT
    ? await import(resolve(AZM_ROOT, 'dist/src/api-compile.js'))
    : await import('@jhlagado/azm/compile');

  const result = (await compile(
    SOURCE_FILE,
    {
      emitBin: true,
      emitD8m: true,
      outputType: 'bin',
      sourceRoot: TECM8_ROOT,
      d8mInputs: { bin: 'roms/tec1g/tecm8/monitor/monitor.bin' },
    },
    { formats: defaultFormatWriters }
  )) as CompileResult;

  if (result.diagnostics.length > 0) {
    throw new Error(`AZM diagnostics:\n${JSON.stringify(result.diagnostics, null, 2)}`);
  }

  const bin = result.artifacts.find((artifact) => artifact.kind === 'bin');
  const d8m = result.artifacts.find((artifact) => artifact.kind === 'd8m');
  if (!bin?.bytes) {
    throw new Error('AZM did not emit bin artifact');
  }

  const d8 = d8m?.json ?? {};
  const mappedEnd = getMappedEnd(d8);
  if (mappedEnd !== undefined && mappedEnd > ROM_END_EXCLUSIVE) {
    throw new Error(
      `Monitor ROM exceeds 16K fixed ROM: mapped end ${toHex(mappedEnd)}, limit ${toHex(ROM_END_EXCLUSIVE)}`
    );
  }
  if (bin.bytes.length > ROM_BYTES) {
    throw new Error(`Monitor ROM binary is ${bin.bytes.length} bytes; limit is ${ROM_BYTES}`);
  }

  mkdirSync(dirname(PROJECT_BIN_PATH), { recursive: true });
  mkdirSync(dirname(BUILD_BIN_PATH), { recursive: true });
  writeFileSync(PROJECT_BIN_PATH, Buffer.from(bin.bytes));
  writeFileSync(BUILD_BIN_PATH, Buffer.from(bin.bytes));
  writeFileSync(BUILD_D8_PATH, `${JSON.stringify(d8, null, 2)}\n`);

  console.log(
    JSON.stringify(
      {
        result: 'ok',
        source: SOURCE_FILE,
        projectBin: PROJECT_BIN_PATH,
        buildBin: BUILD_BIN_PATH,
        d8: BUILD_D8_PATH,
        bytes: bin.bytes.length,
        romStart: toHex(ROM_START),
        romEndExclusive: toHex(ROM_END_EXCLUSIVE),
      },
      null,
      2
    )
  );
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
