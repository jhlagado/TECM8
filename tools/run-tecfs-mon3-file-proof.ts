#!/usr/bin/env node
/**
 * Prove the banked ROM editor-storage path against a real Debug80 SD image.
 */

const { execFileSync } = require('node:child_process');
const { readFileSync, writeFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { loadDebug80RuntimeModules, loadExpansionRomImage } = require('./debug80-integration.ts');

const ROOT = resolve(__dirname, '..');
const SOURCE = resolve(ROOT, 'proofs/tecfs-bank/tecfs-mon3-file-proof.asm');
const IMAGE = resolve(ROOT, 'proofs/tecfs-bank/tecfs-mon3-file-fat32.img');
const IMAGE_TOOL = resolve(ROOT, 'tools/create-storage-proof-image.ts');
const LAST_RUN = resolve(ROOT, 'proofs/tecfs-bank/tecfs-mon3-file-proof-last-run.json');
const MONITOR = resolve(ROOT, 'roms/tec1g/tecm8/monitor/monitor.bin');
const EXPANSION = resolve(ROOT, 'roms/tec1g/tecm8/expansion/expansion.bin');
const APP_START = 0x4000;
const PROOF_RESULT = 0x3a10;
const PROOF_PASS = 0x42;
const MON3_SYS_MODE = 0x089d;
const MCB = 0x0888;
const MCB_SD_CARD = 0x80;
const SYS_CTRL = 0xff;
const SHADOW_OFF = 0x01;

type Runtime = {
  cpu: { pc: number; sp: number; halted: boolean };
  hardware: {
    memory: Uint8Array;
    memRead?: (addr: number) => number;
    memWrite?: (addr: number, value: number) => void;
    forceMemWrite?: (addr: number, value: number) => void;
    isMemoryWritable?: (addr: number) => boolean;
  };
  step: () => { halted: boolean; pc: number; cycles?: number };
};

function encodeSource(lines: string[]): Buffer {
  const result = Buffer.alloc(lines.length * 32);
  lines.forEach((line, index) => {
    const bytes = Buffer.from(line, 'ascii');
    result[index * 32] = bytes.length;
    bytes.copy(result, index * 32 + 1);
  });
  return result;
}

function prepareImage(): void {
  execFileSync(process.execPath, ['--experimental-strip-types', IMAGE_TOOL, IMAGE], {
    cwd: ROOT,
    stdio: 'ignore',
  });
  const { createVolumeImage, importFileIntoVolumeImage } =
    require(resolve(ROOT, 'tools/tm8/format.ts'));
  let volume = createVolumeImage() as Buffer;
  volume = importFileIntoVolumeImage(
    volume,
    '/src/main.asm',
    encodeSource(['ORG 0', 'LD A,1', 'RET']),
  );
  volume = importFileIntoVolumeImage(
    volume,
    '/src/util.asm',
    encodeSource(['Utility:', 'RET']),
  );
  volume = importFileIntoVolumeImage(
    volume,
    '/src/.main.bak',
    encodeSource(['hidden backup']),
  );
  volume = importFileIntoVolumeImage(
    volume,
    '/project/build.asm',
    encodeSource([
      '.ORG 0x4E00',
      'VALUE .EQU 0x5A',
      'CALL HELPER',
      'LD (0x4FF0),A',
      'RET',
      '.INCLUDE "lib.asm"',
    ]),
  );
  volume = importFileIntoVolumeImage(
    volume,
    '/project/lib.asm',
    encodeSource(['HELPER:', 'LD A,VALUE', 'RET']),
  );
  // TEC-FS creates files inside existing prefixes. This seed establishes the
  // build prefix while leaving build.bin and build.map for the ROM to create.
  volume = importFileIntoVolumeImage(volume, '/build/.keep', Buffer.alloc(0));
  const manifest = JSON.parse(readFileSync(IMAGE.replace(/\.[^.]*$/, '.json'), 'utf8'));
  const image = Buffer.from(readFileSync(IMAGE));
  volume.copy(image, manifest.volume_start_byte_offset);
  writeFileSync(IMAGE, image);
}

async function compileProof(): Promise<Uint8Array> {
  const { compile, defaultFormatWriters } = await import('@jhlagado/azm/compile');
  const result = await compile(
    SOURCE,
    {
      emitBin: true,
      outputType: 'bin',
      sourceRoot: ROOT,
      registerCare: 'off',
    },
    { formats: defaultFormatWriters },
  );
  if (result.diagnostics.length > 0) {
    throw new Error(`AZM diagnostics:\n${JSON.stringify(result.diagnostics, null, 2)}`);
  }
  const bin = result.artifacts.find((artifact: { kind: string }) => artifact.kind === 'bin') as
    | { bytes?: Uint8Array }
    | undefined;
  if (!bin?.bytes) {
    throw new Error('AZM did not emit the proof binary');
  }
  return bin.bytes;
}

async function loadRuntime(bytes: Uint8Array) {
  const { createTec1gRuntime, createTec1gMemoryHooks, applyExpansionRomMemory, createZ80Runtime } =
    await loadDebug80RuntimeModules();
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
    tms9918Active: true,
    sdEnabled: true,
    sdHighCapacity: true,
    sdImagePath: IMAGE,
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
  ) as Runtime;
  const hooks = createTec1gMemoryHooks(runtime.hardware.memory, config.romRanges, platform.state.system);
  applyExpansionRomMemory(hooks.expandBanks, loadExpansionRomImage(EXPANSION));
  runtime.hardware.memRead = hooks.memRead;
  runtime.hardware.memWrite = hooks.memWrite;
  runtime.hardware.forceMemWrite = hooks.forceMemWrite;
  runtime.hardware.isMemoryWritable = hooks.isMemoryWritable;
  platform.ioHandlers.write?.(SYS_CTRL, SHADOW_OFF);
  runtime.hardware.forceMemWrite?.(MON3_SYS_MODE, SHADOW_OFF);
  runtime.hardware.memory.set(runtime.hardware.memory.subarray(0xc000, 0xc100), 0);
  runtime.hardware.forceMemWrite?.(MCB, MCB_SD_CARD);
  runtime.cpu.sp = 0x7ff0;
  runtime.cpu.pc = APP_START;
  return { runtime, platform };
}

function run(runtime: Runtime, platform: { recordCycles: (cycles: number) => void }): {
  instructions: number;
  fatError: number;
} {
  let fatError = 0;
  for (let i = 0; i < 700_000_000; i += 1) {
    if (runtime.cpu.pc >= 0xf255 && runtime.cpu.pc <= 0xf291) {
      fatError = runtime.cpu.pc;
    }
    const step = runtime.step();
    platform.recordCycles(step.cycles ?? 0);
    if (runtime.cpu.halted || step.halted) {
      return { instructions: i + 1, fatError };
    }
  }
  throw new Error(
    `proof did not halt; pc=0x${runtime.cpu.pc.toString(16)} FAT error=0x${fatError.toString(16)} stage=${runtime.hardware.memory[0x3c59]} phase=${runtime.hardware.memory[0x3a11]} scan=${Array.from(runtime.hardware.memory.subarray(0x3ce6, 0x3cef)).join(',')} buffer=${Array.from(runtime.hardware.memory.subarray(0x3d00, 0x3d08)).join(',')}`,
  );
}

function verifyHostFiles(): {
  firstLine: string;
  createdLine: string;
  binaryBytes: number;
  mapRecords: number;
} {
  const { parseVolumeImage, readFileFromVolumeImage } = require(resolve(ROOT, 'tools/tm8/format.ts'));
  const manifest = JSON.parse(readFileSync(IMAGE.replace(/\.[^.]*$/, '.json'), 'utf8'));
  const image = readFileSync(IMAGE);
  const volume = Buffer.from(
    image.subarray(manifest.volume_start_byte_offset, manifest.volume_start_byte_offset + 4 * 1024 * 1024),
  );
  parseVolumeImage(volume);
  const source = readFileFromVolumeImage(volume, '/src/main.asm') as Buffer;
  const firstLine = source.subarray(1, 1 + (source[0] ?? 0)).toString('ascii');
  if (firstLine !== 'EXRG 0') {
    throw new Error(`host-side source is "${firstLine}", expected "EXRG 0"`);
  }
  const created = readFileFromVolumeImage(volume, '/src/new.asm') as Buffer;
  const createdLine = created.subarray(1, 1 + (created[0] ?? 0)).toString('ascii');
  if (created.byteLength !== 32 || createdLine !== 'N') {
    throw new Error(
      `host-side created source is ${created.byteLength} bytes with line ${JSON.stringify(createdLine)}, expected 32 bytes and "N"`,
    );
  }
  const binary = readFileFromVolumeImage(volume, '/build/build.bin') as Buffer;
  const expectedBinary = Buffer.from([
    0xcd, 0x07, 0x4e,
    0x32, 0xf0, 0x4f,
    0xc9,
    0x3e, 0x5a, 0xc9,
  ]);
  if (!binary.equals(expectedBinary)) {
    throw new Error(
      `host-side build binary was ${binary.toString('hex')}, expected ${expectedBinary.toString('hex')}`,
    );
  }
  const map = readFileFromVolumeImage(volume, '/build/build.map') as Buffer;
  if (
    map.byteLength !== 32 ||
    map.subarray(0, 4).toString('ascii') !== 'TMAP' ||
    map[4] !== 1 ||
    map[6] !== 2 ||
    map[19] !== 0x02 ||
    map[28] !== 0x07 ||
    map[29] !== 0x4e ||
    map[31] !== 0x11
  ) {
    throw new Error(`host-side build map was ${map.toString('hex')}`);
  }
  return { firstLine, createdLine, binaryBytes: binary.byteLength, mapRecords: map[6] };
}

async function main(): Promise<void> {
  prepareImage();
  const bytes = await compileProof();
  const { runtime, platform } = await loadRuntime(bytes);
  const { instructions, fatError } = run(runtime, platform);
  const marker = runtime.hardware.memory[PROOF_RESULT];
  if (marker !== PROOF_PASS) {
    throw new Error(
      `proof failed with marker 0x${marker.toString(16)}; TFS error=0x${runtime.hardware.memory[0x3b43].toString(16)} stage=${runtime.hardware.memory[0x3c59]} FAT error=0x${fatError.toString(16)} scan=${Array.from(runtime.hardware.memory.subarray(0x3ce0, 0x3d00)).join(',')} list-count=${runtime.hardware.memory[0x3cf5]} list=${JSON.stringify(Buffer.from(runtime.hardware.memory.subarray(0x5800, 0x5840)).toString('ascii'))} catalog=${Array.from(runtime.hardware.memory.subarray(0x3d00, 0x3d34)).join(',')}`,
    );
  }
  const tms9918 = (platform as any).state.display?.tms9918?.snapshot();
  if (!tms9918) {
    throw new Error('TMS9918 snapshot unavailable after shell directory render');
  }
  const renderedDirectory = Buffer.from(tms9918.vram.subarray(0x00a0, 0x00a0 + 96))
    .toString('ascii');
  if (
    !renderedDirectory.startsWith('main.asm') ||
    !renderedDirectory.slice(32).startsWith('util.asm') ||
    !renderedDirectory.slice(64).startsWith('new.asm')
  ) {
    throw new Error(`shell directory rows were ${JSON.stringify(renderedDirectory)}`);
  }
  const { firstLine, createdLine, binaryBytes, mapRecords } = verifyHostFiles();
  writeFileSync(
    LAST_RUN,
    `${JSON.stringify({ result: 'ok', instructions, firstLine, createdLine, binaryBytes, mapRecords, renderedDirectory, finalPc: runtime.cpu.pc }, null, 2)}\n`,
  );
  console.log(
    `TEC-FS MON3 file proof passed in ${instructions} instructions (${firstLine}; created ${createdLine}; built ${binaryBytes} bytes with ${mapRecords} symbols)`,
  );
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
