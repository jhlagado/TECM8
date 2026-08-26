#!/usr/bin/env node
/** Prove native named-object ABI 1 against the real MON3/SD provider chain. */

const { execFileSync } = require('node:child_process');
const { readFileSync, writeFileSync } = require('node:fs');
const { resolve } = require('node:path');

const ROOT = resolve(__dirname, '..');
const DEBUG80_ROOT = resolve(process.env.DEBUG80_ROOT ?? '/Users/johnhardy/projects/debug80');
const SOURCE = resolve(ROOT, 'proofs/tecfs-bank/tecfs-object-provider-proof.asm');
const IMAGE = resolve(ROOT, 'build/proofs/tecfs-object-provider.img');
const MANIFEST = resolve(ROOT, 'build/proofs/tecfs-object-provider.json');
const MONITOR = resolve(ROOT, 'roms/tec1g/tecm8/monitor/monitor.bin');
const EXPANSION = resolve(ROOT, 'roms/tec1g/tecm8/expansion/expansion.bin');
const BANK5_MAP = resolve(ROOT, 'build/roms/tec1g/tecm8/expansion/bank5.d8.json');
const APP_START = 0x4000;
const PROOF_RESULT = 0x3a10;
const PROOF_PHASE = 0x3a11;
const PROOF_PASS = 0x42;
const INITIAL_SP = 0x7ff0;
const MCB = 0x0888;
const MCB_SD_CARD = 0x80;
const MON3_SYS_MODE = 0x089d;
const SYS_CTRL = 0xff;
const SHADOW_OFF = 0x01;
const DESCRIPTOR_SECTOR = 81;
const DATA_SECTOR = 2048 + 128;

function requireDebug80(path: string): unknown {
  return require(resolve(DEBUG80_ROOT, path));
}

function prepareImage(): void {
  execFileSync(
    process.execPath,
    ['--experimental-strip-types', resolve(ROOT, 'tools/create-storage-proof-image.ts'), IMAGE],
    { cwd: ROOT, stdio: 'ignore' },
  );
  const manifest = JSON.parse(readFileSync(MANIFEST, 'utf8'));
  const image = readFileSync(IMAGE);
  const { createVolumeImage } = require(resolve(ROOT, 'tools/tm8/format.ts')) as {
    createVolumeImage: () => Buffer;
  };
  createVolumeImage().copy(image, manifest.volume_start_byte_offset);
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

function expansionImage(): { banks: Uint8Array[]; memory: Uint8Array } {
  const bytes = new Uint8Array(readFileSync(EXPANSION));
  return {
    banks: Array.from({ length: 9 }, (_, index) =>
      bytes.slice(index * 0x4000, (index + 1) * 0x4000),
    ),
    memory: new Uint8Array(0x10000),
  };
}

function symbolAddress(mapPath: string, name: string): number {
  const map = JSON.parse(readFileSync(mapPath, 'utf8'));
  for (const file of Object.values(map.files) as Array<{ symbols?: Array<Record<string, unknown>> }>) {
    const symbol = file.symbols?.find((item) => item.name === name && item.kind === 'label');
    if (typeof symbol?.address === 'number') return symbol.address;
  }
  throw new Error(`missing ${name} in ${mapPath}`);
}

function sum(bytes: Buffer): number {
  let result = 0;
  for (const byte of bytes) result = (result + byte) & 0xff;
  return result;
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
  const expansion = expansionImage();
  applyExpansionRomMemory(hooks.expandBanks, expansion);
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

  const writeEntry = symbolAddress(BANK5_MAP, 'tecfsMon3FileWrite') - 0x8000;
  const originalWriteEntry = hooks.expandBanks[5]!.slice(writeEntry, writeEntry + 4);
  let writeFaultActive = false;

  let instructions = 0;
  let tStates = 0;
  for (; instructions < 300_000_000; instructions += 1) {
    const phase = runtime.hardware.memory[PROOF_PHASE];
    const wantWriteFault = phase === 0x30 || phase === 0x31;
    if (wantWriteFault !== writeFaultActive) {
      hooks.expandBanks[5]!.set(
        wantWriteFault ? Uint8Array.from([0x3e, 0x06, 0x37, 0xc9]) : originalWriteEntry,
        writeEntry,
      );
      writeFaultActive = wantWriteFault;
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
    const handles = Array.from(runtime.hardware.memory.slice(0x3c80, 0x3cd0));
    throw new Error(
      `proof failed: marker=0x${marker.toString(16)} phase=${runtime.hardware.memory[PROOF_PHASE]} status=0x${runtime.hardware.memory[0x3a12].toString(16)} pc=0x${runtime.cpu.pc.toString(16)} sp=0x${runtime.cpu.sp.toString(16)} instructions=${instructions} scan=${runtime.hardware.memory[0x3c62]} half=${runtime.hardware.memory[0x3c65]} sector=${runtime.hardware.memory[0x3b4f].toString(16)}${runtime.hardware.memory[0x3b4e].toString(16).padStart(2, '0')} stage=${runtime.hardware.memory[0x3c52]} request=${request.join(',')} handles=${handles.join(',')}`,
    );
  }
  if (runtime.cpu.sp !== INITIAL_SP) {
    throw new Error(
      `stack mismatch: got 0x${runtime.cpu.sp.toString(16)}, expected 0x${INITIAL_SP.toString(16)}`,
    );
  }
  const manifest = JSON.parse(readFileSync(MANIFEST, 'utf8'));
  const image = readFileSync(IMAGE);
  const volume = manifest.volume_start_byte_offset;
  const descriptor = image.subarray(
    volume + DESCRIPTOR_SECTOR * 512,
    volume + (DESCRIPTOR_SECTOR + 1) * 512,
  );
  const expectedName = Buffer.from('src/alpha.nu', 'ascii');
  if (descriptor.subarray(0, 4).toString('ascii') !== 'NTO1') {
    throw new Error('generation-two descriptor magic is missing');
  }
  if (descriptor.readUInt16LE(6) !== 2 || descriptor[8] !== 1) {
    throw new Error('generation-two descriptor selection is incorrect');
  }
  if (descriptor.readUInt16LE(10) !== 5) {
    throw new Error('generation-two descriptor length is incorrect');
  }
  if (!descriptor.subarray(12, 12 + expectedName.length).equals(expectedName)) {
    throw new Error('descriptor name is incorrect');
  }
  if (sum(descriptor) !== 0) throw new Error('descriptor checksum is invalid');
  const observed = image.subarray(volume + DATA_SECTOR * 512, volume + DATA_SECTOR * 512 + 5);
  const expected = Buffer.from([0x00, 0x1a, 0x7f, 0x80, 0xff]);
  if (!observed.equals(expected)) {
    throw new Error(`committed binary mismatch: ${Array.from(observed).join(',')}`);
  }
  const report = { result: 'ok', instructions: instructions + 1, tStates };
  writeFileSync(
    resolve(ROOT, 'build/proofs/tecfs-object-provider-last-run.json'),
    `${JSON.stringify(report, null, 2)}\n`,
  );
  console.log(
    `TEC-FS object provider proof passed in ${report.instructions} instructions and ${tStates} T-states`,
  );
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
