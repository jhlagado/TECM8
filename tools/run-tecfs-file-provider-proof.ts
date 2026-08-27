#!/usr/bin/env node
/** Prove the read-only TEC-FS file provider through the real MON3/SD chain. */

const { execFileSync } = require('node:child_process');
const { readFileSync, writeFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { loadTec1gExpansionRomImage } = require('./tec1g-expansion-image.ts');

const ROOT = resolve(__dirname, '..');
const DEBUG80_ROOT = resolve(process.env.DEBUG80_ROOT ?? '/Users/johnhardy/projects/debug80');
const SOURCE = resolve(ROOT, 'proofs/tecfs-bank/tecfs-file-provider-proof.asm');
const IMAGE = resolve(ROOT, 'build/proofs/tecfs-file-provider.img');
const MANIFEST = resolve(ROOT, 'build/proofs/tecfs-file-provider.json');
const MONITOR = resolve(ROOT, 'roms/tec1g/tecm8/monitor/monitor.bin');
const EXPANSION = resolve(ROOT, 'roms/tec1g/tecm8/expansion/expansion.bin');
const BANK5_MAP = resolve(ROOT, 'build/roms/tec1g/tecm8/expansion/bank5.d8.json');
const APP_START = 0x4000;
const PROOF_RESULT = 0x3a10;
const PROOF_PHASE = 0x3a11;
const PROOF_STATUS = 0x3a12;
const PROOF_PASS = 0x42;
const INITIAL_SP = 0x7ff0;
const MCB = 0x0888;
const MCB_SD_CARD = 0x80;
const MON3_SYS_MODE = 0x089d;
const SYS_CTRL = 0xff;
const SHADOW_OFF = 0x01;

const sourceBytes = Buffer.alloc(5000);
for (let index = 0; index < sourceBytes.length; index += 1) {
  sourceBytes[index] = (index * 37 + 11) & 0xff;
}

function requireDebug80(path: string): unknown {
  return require(resolve(DEBUG80_ROOT, 'packages/debug80-runtime/dist', path));
}

function prepareImage(): void {
  execFileSync(
    process.execPath,
    ['--experimental-strip-types', resolve(ROOT, 'tools/create-storage-proof-image.ts'), IMAGE],
    { cwd: ROOT, stdio: 'ignore' },
  );
  const manifest = JSON.parse(readFileSync(MANIFEST, 'utf8'));
  const image = readFileSync(IMAGE);
  const { createVolumeImage, importFileIntoVolumeImage, parseVolumeImage } = require(
    resolve(ROOT, 'tools/tm8/format.ts'),
  ) as {
    createVolumeImage: () => Buffer;
    importFileIntoVolumeImage: (image: Buffer, path: string, bytes: Buffer) => Buffer;
    parseVolumeImage: (image: Buffer) => { files: Array<{ fileId: number; size: number }> };
  };
  const volume = importFileIntoVolumeImage(createVolumeImage(), '/src/main.asm', sourceBytes);
  const parsed = parseVolumeImage(volume);
  if (parsed.files.length !== 1 || parsed.files[0]?.fileId !== 0 || parsed.files[0]?.size !== 5000) {
    throw new Error('proof source did not receive the expected binary file id and length');
  }
  volume.copy(image, manifest.volume_start_byte_offset);
  writeFileSync(IMAGE, image);
}

async function compileProof(): Promise<Uint8Array> {
  const { compile, defaultFormatWriters } = await import('@jhlagado/azm/compile');
  const result = await compile(
    SOURCE,
    { emitBin: true, outputType: 'bin', sourceRoot: ROOT, registerCare: 'off' },
    { formats: defaultFormatWriters },
  );
  if (result.diagnostics.length !== 0) {
    throw new Error(`AZM diagnostics:\n${JSON.stringify(result.diagnostics, null, 2)}`);
  }
  const artifact = result.artifacts.find((item: { kind: string }) => item.kind === 'bin') as
    | { bytes?: Uint8Array }
    | undefined;
  if (!artifact?.bytes) throw new Error('AZM did not emit the proof binary');
  return artifact.bytes;
}

function symbolAddress(mapPath: string, name: string): number {
  const map = JSON.parse(readFileSync(mapPath, 'utf8'));
  for (const file of Object.values(map.files) as Array<{ symbols?: Array<Record<string, unknown>> }>) {
    const symbol = file.symbols?.find((item) => item.name === name && item.kind === 'label');
    if (typeof symbol?.address === 'number') return symbol.address;
  }
  throw new Error(`missing ${name} in ${mapPath}`);
}

function assertBytes(memory: Uint8Array, address: number, expected: Uint8Array, label: string): void {
  const actual = memory.slice(address, address + expected.length);
  if (!Buffer.from(actual).equals(Buffer.from(expected))) {
    throw new Error(`${label} differs at ${address.toString(16)}`);
  }
}

async function main(): Promise<void> {
  prepareImage();
  const bytes = await compileProof();
  const { createTec1gRuntime } = requireDebug80('platforms/tec1g/runtime.js') as {
    createTec1gRuntime: Function;
  };
  const { createTec1gMemoryHooks, applyExpansionRomMemory } = requireDebug80(
    'platforms/tec1g/tec1g-memory.js',
  ) as { createTec1gMemoryHooks: Function; applyExpansionRomMemory: Function };
  const { createZ80Runtime } = requireDebug80('z80/runtime.js') as {
    createZ80Runtime: Function;
  };
  const config = {
    regions: [
      { start: 0x0000, end: 0x07ff, kind: 'rom' },
      { start: 0x0800, end: 0x7fff, kind: 'ram' },
      { start: 0xc000, end: 0xffff, kind: 'rom' },
    ],
    romRanges: [
      { start: 0x0000, end: 0x07ff },
      { start: 0xc000, end: 0xffff },
    ],
    appStart: APP_START,
    entry: APP_START,
    updateMs: 100,
    yieldMs: 0,
    gimpSignal: false,
    expansionBankHi: false,
    matrixMode: false,
    protectOnReset: false,
    rtcEnabled: false,
    sdEnabled: true,
    sdHighCapacity: true,
    sdImagePath: IMAGE,
    tms9918Active: false,
    expansionRomHex: EXPANSION,
  };
  const platform = createTec1gRuntime(config, () => {});
  const memory = new Uint8Array(0x10000);
  memory.set(readFileSync(MONITOR).subarray(0, 0x4000), 0xc000);
  memory.set(bytes, APP_START);
  const runtime = createZ80Runtime(
    { memory, startAddress: APP_START },
    APP_START,
    platform.ioHandlers,
    { romRanges: config.romRanges },
  );
  const hooks = createTec1gMemoryHooks(
    runtime.hardware.memory,
    config.romRanges,
    platform.state.system,
  );
  applyExpansionRomMemory(hooks.expandBanks, loadTec1gExpansionRomImage(EXPANSION));
  runtime.hardware.memRead = hooks.memRead;
  runtime.hardware.memWrite = hooks.memWrite;
  runtime.hardware.forceMemWrite = hooks.forceMemWrite;
  runtime.hardware.isMemoryWritable = hooks.isMemoryWritable;
  platform.ioHandlers.write?.(SYS_CTRL, SHADOW_OFF);
  runtime.hardware.forceMemWrite?.(MON3_SYS_MODE, SHADOW_OFF);
  runtime.hardware.memory.set(runtime.hardware.memory.subarray(0xc000, 0xc100), 0);
  runtime.hardware.forceMemWrite?.(MCB, MCB_SD_CARD);
  runtime.cpu.sp = INITIAL_SP;
  runtime.cpu.pc = APP_START;

  const readEntry = symbolAddress(BANK5_MAP, 'tecfsMon3FileRead') - 0x8000;
  const originalReadEntry = hooks.expandBanks[5]!.slice(readEntry, readEntry + 4);
  let readFaultActive = false;
  let instructions = 0;
  let tStates = 0;
  for (; instructions < 300_000_000; instructions += 1) {
    const wantReadFault = runtime.hardware.memory[PROOF_PHASE] === 0x30;
    if (wantReadFault !== readFaultActive) {
      hooks.expandBanks[5]!.set(
        wantReadFault ? Uint8Array.from([0x3e, 0x06, 0x37, 0xc9]) : originalReadEntry,
        readEntry,
      );
      readFaultActive = wantReadFault;
    }
    const step = runtime.step();
    const cycles = step.cycles ?? 0;
    tStates += cycles;
    platform.recordCycles(cycles);
    if (runtime.cpu.halted || step.halted) break;
  }
  const marker = runtime.hardware.memory[PROOF_RESULT];
  if (marker !== PROOF_PASS) {
    const request = Array.from(runtime.hardware.memory.slice(0x5800, 0x5810));
    throw new Error(
      `proof failed: marker=0x${marker.toString(16)} phase=0x${runtime.hardware.memory[PROOF_PHASE].toString(16)} status=0x${runtime.hardware.memory[PROOF_STATUS].toString(16)} pc=0x${runtime.cpu.pc.toString(16)} sp=0x${runtime.cpu.sp.toString(16)} instructions=${instructions} request=${request.join(',')}`,
    );
  }
  if (runtime.cpu.sp !== INITIAL_SP) {
    throw new Error(
      `stack mismatch: got 0x${runtime.cpu.sp.toString(16)}, expected 0x${INITIAL_SP.toString(16)}`,
    );
  }
  assertBytes(runtime.hardware.memory, 0x6000, sourceBytes.subarray(0, 600), 'sector-crossing read');
  assertBytes(runtime.hardware.memory, 0x6300, sourceBytes.subarray(4090, 4122), 'block-crossing read');
  assertBytes(runtime.hardware.memory, 0x6400, sourceBytes.subarray(4990), 'short read');
  assertBytes(runtime.hardware.memory, 0x6500, sourceBytes.subarray(1, 17), 'retry after storage failure');
  if (runtime.hardware.memory[0x7fff] !== sourceBytes[0]) {
    throw new Error('half-open boundary read did not write byte 7FFFh');
  }
  const report = { result: 'ok', instructions: instructions + 1, tStates };
  writeFileSync(
    resolve(ROOT, 'build/proofs/tecfs-file-provider-last-run.json'),
    `${JSON.stringify(report, null, 2)}\n`,
  );
  console.log(
    `TEC-FS file provider proof passed in ${report.instructions} instructions and ${tStates} T-states`,
  );
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
