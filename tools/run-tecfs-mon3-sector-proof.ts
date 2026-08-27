#!/usr/bin/env node
/** Prove the real bank-5 VOLUME.TM8 sector driver against Debug80 SD I/O. */

const { execFileSync } = require('node:child_process');
const { readFileSync, writeFileSync } = require('node:fs');
const { resolve } = require('node:path');

const ROOT = resolve(__dirname, '..');
const DEBUG80_ROOT = resolve(process.env.DEBUG80_ROOT ?? '/Users/johnhardy/projects/debug80');
const SOURCE = resolve(ROOT, 'proofs/tecfs-bank/tecfs-mon3-sector-proof.asm');
const IMAGE = resolve(ROOT, 'build/proofs/tecfs-mon3-sector.img');
const MANIFEST = resolve(ROOT, 'build/proofs/tecfs-mon3-sector.json');
const MONITOR = resolve(ROOT, 'roms/tec1g/tecm8/monitor/monitor.bin');
const EXPANSION = resolve(ROOT, 'roms/tec1g/tecm8/expansion/expansion.bin');
const APP_START = 0x4000;
const PROOF_RESULT = 0x3a10;
const PROOF_PHASE = 0x3a11;
const PROOF_PASS = 0x42;
const MCB = 0x0888;
const MCB_SD_CARD = 0x80;
const MON3_SYS_MODE = 0x089d;
const SYS_CTRL = 0xff;
const SHADOW_OFF = 0x01;
const INITIAL_SP = 0x7ff0;

function requireDebug80(path: string): unknown {
  return require(resolve(DEBUG80_ROOT, 'packages/debug80-runtime/dist', path.replace(/^out\//, '')));
}

function prepareImage(): void {
  execFileSync(
    process.execPath,
    ['--experimental-strip-types', resolve(ROOT, 'tools/create-storage-proof-image.ts'), IMAGE],
    { cwd: ROOT, stdio: 'ignore' },
  );
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

function expansionImage(): { banks: Uint8Array[]; memory: Uint8Array } {
  const bytes = new Uint8Array(readFileSync(EXPANSION));
  return {
    banks: Array.from({ length: 9 }, (_, index) =>
      bytes.slice(index * 0x4000, (index + 1) * 0x4000),
    ),
    memory: new Uint8Array(0x10000),
  };
}

async function main(): Promise<void> {
  prepareImage();
  const bytes = await compileProof();
  const { createTec1gRuntime } = requireDebug80('out/platforms/tec1g/runtime.js') as {
    createTec1gRuntime: Function;
  };
  const { createTec1gMemoryHooks, applyExpansionRomMemory } = requireDebug80(
    'out/platforms/tec1g/tec1g-memory.js',
  ) as { createTec1gMemoryHooks: Function; applyExpansionRomMemory: Function };
  const { createZ80Runtime } = requireDebug80('out/z80/runtime.js') as {
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
  applyExpansionRomMemory(hooks.expandBanks, expansionImage());
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

  let instructions = 0;
  let tStates = 0;
  for (; instructions < 20_000_000; instructions += 1) {
    const step = runtime.step();
    const cycles = step.cycles ?? 0;
    tStates += cycles;
    platform.recordCycles(cycles);
    if (runtime.cpu.halted || step.halted) break;
  }
  const marker = runtime.hardware.memory[PROOF_RESULT];
  if (marker !== PROOF_PASS) {
    const hexBytes = (start: number, count: number): string =>
      Array.from(runtime.hardware.memory.slice(start, start + count) as Uint8Array)
        .map((value) => value.toString(16).padStart(2, '0'))
        .join('');
    throw new Error(
      `proof failed: marker=0x${marker.toString(16)} phase=${runtime.hardware.memory[PROOF_PHASE]} pc=0x${runtime.cpu.pc.toString(16)} sp=0x${runtime.cpu.sp.toString(16)} instructions=${instructions} status=0x${runtime.hardware.memory[0x3b42].toString(16)} error=0x${runtime.hardware.memory[0x3b43].toString(16)} stage=${runtime.hardware.memory[0x3c52]} file=${runtime.hardware.memory[0x0897]} rfc=${hexBytes(0x0430,16)} root=${hexBytes(0x05f8,4)} data=${hexBytes(0x05fc,4)} next=${hexBytes(0x05c9,4)}`,
    );
  }
  if (runtime.cpu.sp !== INITIAL_SP) {
    throw new Error(
      `stack mismatch: got 0x${runtime.cpu.sp.toString(16)}, expected 0x${INITIAL_SP.toString(16)}`,
    );
  }
  const manifest = JSON.parse(readFileSync(MANIFEST, 'utf8'));
  const image = readFileSync(IMAGE);
  const offset = manifest.volume_start_byte_offset + 7 * 512;
  const observed = Array.from(image.subarray(offset, offset + 5));
  const expected = [0x00, 0x1a, 0x7f, 0x80, 0xff];
  if (observed.some((value, index) => value !== expected[index])) {
    throw new Error(`host image mismatch: ${observed.join(',')}`);
  }
  const report = { result: 'ok', instructions: instructions + 1, tStates, observed };
  writeFileSync(resolve(ROOT, 'build/proofs/tecfs-mon3-sector-last-run.json'), `${JSON.stringify(report, null, 2)}\n`);
  console.log(
    `TEC-FS MON3 sector proof passed in ${report.instructions} instructions and ${tStates} T-states`,
  );
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
