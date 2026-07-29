#!/usr/bin/env node
/**
 * Assemble the TECM8 multibank expansion ROM image used by Debug80's TEC-1G
 * expansion window.
 */

const { mkdirSync, renameSync, writeFileSync } = require('node:fs');
const { dirname, resolve } = require('node:path');

const TECM8_ROOT = resolve(__dirname, '..');
const AZM_ROOT = process.env.AZM_ROOT ? resolve(process.env.AZM_ROOT) : undefined;
const EXPANSION_ROOT = 'roms/tec1g/tecm8/expansion';
const PROJECT_PACKED_BIN_PATH = resolve(TECM8_ROOT, EXPANSION_ROOT, 'expansion.bin');
const BUILD_PACKED_BIN_PATH = resolve(
  TECM8_ROOT,
  'build/roms/tec1g/tecm8/expansion/expansion-144k.bin'
);
const ROM_START = 0x8000;
const ROM_BANK_BYTES = 16 * 1024;
const ROM_BANK_COUNT = 9;
const ROM_BYTES = ROM_BANK_BYTES * ROM_BANK_COUNT;
const ROM_WINDOW_END_EXCLUSIVE = ROM_START + ROM_BANK_BYTES;

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

type CompileFn = (
  sourceFile: string,
  options: Record<string, unknown>,
  environment: Record<string, unknown>
) => Promise<CompileResult>;

type BankBuildResult = {
  physicalBank: number;
  source: string;
  projectBin: string;
  buildBin: string;
  d8: string;
  sourceBytes: number;
};

function toHex(value: number): string {
  return `0x${value.toString(16).toUpperCase().padStart(4, '0')}`;
}

function writeArtifactAtomic(path: string, data: string | Uint8Array): void {
  const temporaryPath = `${path}.${process.pid}.${Math.random().toString(16).slice(2)}.tmp`;
  writeFileSync(temporaryPath, data);
  renameSync(temporaryPath, path);
}

function getMappedEnd(d8: D8Map): number | undefined {
  const ends = Object.values(d8.files ?? {})
    .flatMap((file) => file.segments ?? [])
    .map((segment) => segment.end);
  return ends.length === 0 ? undefined : Math.max(...ends);
}

function bankProjectBinPath(physicalBank: number): string {
  return resolve(TECM8_ROOT, EXPANSION_ROOT, `bank${physicalBank}.bin`);
}

function bankBuildBinPath(physicalBank: number): string {
  return resolve(TECM8_ROOT, 'build/roms/tec1g/tecm8/expansion', `bank${physicalBank}.bin`);
}

function bankBuildD8Path(physicalBank: number): string {
  return resolve(TECM8_ROOT, 'build/roms/tec1g/tecm8/expansion', `bank${physicalBank}.d8.json`);
}

async function compileBank(
  compile: CompileFn,
  defaultFormatWriters: unknown,
  physicalBank: number
): Promise<{ image: Buffer; result: BankBuildResult }> {
  const sourceRel = `${EXPANSION_ROOT}/bank${physicalBank}.asm`;
  const sourceFile = resolve(TECM8_ROOT, sourceRel);
  const projectBin = bankProjectBinPath(physicalBank);
  const buildBin = bankBuildBinPath(physicalBank);
  const d8Path = bankBuildD8Path(physicalBank);
  const compileResult = await compile(
    sourceFile,
    {
      emitBin: true,
      emitD8m: true,
      outputType: 'bin',
      sourceRoot: TECM8_ROOT,
      d8mInputs: { bin: `${EXPANSION_ROOT}/bank${physicalBank}.bin` },
    },
    { formats: defaultFormatWriters }
  );

  if (compileResult.diagnostics.length > 0) {
    throw new Error(
      `AZM diagnostics for expansion bank ${physicalBank}:\n${JSON.stringify(compileResult.diagnostics, null, 2)}`
    );
  }

  const bin = compileResult.artifacts.find((artifact) => artifact.kind === 'bin');
  const d8m = compileResult.artifacts.find((artifact) => artifact.kind === 'd8m');
  if (!bin?.bytes) {
    throw new Error(`AZM did not emit bin artifact for expansion bank ${physicalBank}`);
  }

  const d8 = d8m?.json ?? {};
  const mappedEnd = getMappedEnd(d8);
  if (mappedEnd !== undefined && mappedEnd > ROM_WINDOW_END_EXCLUSIVE) {
    throw new Error(
      `Expansion ROM bank ${physicalBank} exceeds the 16K visible window: mapped end ${toHex(mappedEnd)}, limit ${toHex(ROM_WINDOW_END_EXCLUSIVE)}`
    );
  }
  let bankBytes = Buffer.from(bin.bytes);
  if (bankBytes.length > ROM_BANK_BYTES && bankBytes.length <= ROM_WINDOW_END_EXCLUSIVE) {
    bankBytes = bankBytes.subarray(ROM_START, ROM_WINDOW_END_EXCLUSIVE);
  }
  if (bankBytes.length > ROM_BANK_BYTES) {
    throw new Error(
      `Expansion ROM bank ${physicalBank} binary is ${bin.bytes.length} bytes; limit is ${ROM_BANK_BYTES}`
    );
  }

  const image = Buffer.alloc(ROM_BANK_BYTES);
  bankBytes.copy(image);

  mkdirSync(dirname(projectBin), { recursive: true });
  mkdirSync(dirname(buildBin), { recursive: true });
  writeArtifactAtomic(projectBin, image);
  writeArtifactAtomic(buildBin, image);
  writeArtifactAtomic(d8Path, `${JSON.stringify(d8, null, 2)}\n`);

  return {
    image,
    result: {
      physicalBank,
      source: sourceFile,
      projectBin,
      buildBin,
      d8: d8Path,
      sourceBytes: bankBytes.length,
    },
  };
}

async function main(): Promise<void> {
  const { compile, defaultFormatWriters } = AZM_ROOT
    ? await import(resolve(AZM_ROOT, 'dist/src/api-compile.js'))
    : await import('@jhlagado/azm/compile');

  const romImage = Buffer.alloc(ROM_BYTES);
  const banks: BankBuildResult[] = [];
  for (let physicalBank = 0; physicalBank < ROM_BANK_COUNT; physicalBank += 1) {
    const built = await compileBank(compile as CompileFn, defaultFormatWriters, physicalBank);
    built.image.copy(romImage, physicalBank * ROM_BANK_BYTES);
    banks.push(built.result);
  }

  mkdirSync(dirname(PROJECT_PACKED_BIN_PATH), { recursive: true });
  mkdirSync(dirname(BUILD_PACKED_BIN_PATH), { recursive: true });
  writeArtifactAtomic(PROJECT_PACKED_BIN_PATH, romImage);
  writeArtifactAtomic(BUILD_PACKED_BIN_PATH, romImage);

  console.log(
    JSON.stringify(
      {
        result: 'ok',
        projectBin: PROJECT_PACKED_BIN_PATH,
        buildBin: BUILD_PACKED_BIN_PATH,
        imageBytes: romImage.length,
        romStart: toHex(ROM_START),
        romWindowEndExclusive: toHex(ROM_WINDOW_END_EXCLUSIVE),
        bankBytes: ROM_BANK_BYTES,
        bankCount: ROM_BANK_COUNT,
        banks,
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
