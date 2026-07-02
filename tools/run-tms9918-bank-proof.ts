#!/usr/bin/env node
/**
 * Assemble and run the TecMate bank-1 TMS9918 service proof in Debug80.
 */

const { readFileSync, writeFileSync } = require('node:fs');
const { resolve } = require('node:path');

const TECM8_ROOT = resolve(__dirname, '..');
const DEBUG80_ROOT = resolve(process.env.DEBUG80_ROOT ?? '/Users/johnhardy/projects/debug80');
const AZM_ROOT = process.env.AZM_ROOT ? resolve(process.env.AZM_ROOT) : undefined;
const PROOF_SOURCE = resolve(TECM8_ROOT, 'proofs/tms9918-bank/tms9918-bank-proof.asm');
const LAST_RUN = resolve(TECM8_ROOT, 'proofs/tms9918-bank/tms9918-bank-proof-last-run.json');
const MONITOR_ROM_PATH = resolve(TECM8_ROOT, 'roms/tec1g/tecm8/monitor/monitor.bin');
const EXPANSION_ROM_PATH = resolve(TECM8_ROOT, 'roms/tec1g/tecm8/expansion/expansion.bin');
const APP_START = 0x4000;
const MON3_SYS_MODE = 0x089d;
const SYS_CTRL = 0xff;
const SHADOW_OFF = 0x01;
const PROOF_PASS = 0x42;
const INITIAL_SYS_CTRL = SHADOW_OFF;

type Runtime = {
  cpu: {
    pc: number;
    sp: number;
    halted: boolean;
  };
  hardware: {
    memory: Uint8Array;
    memRead?: (addr: number) => number;
    memWrite?: (addr: number, value: number) => void;
    forceMemWrite?: (addr: number, value: number) => void;
    isMemoryWritable?: (addr: number) => boolean;
  };
  step: () => { halted: boolean; pc: number; cycles?: number };
};

type PlatformRuntime = {
  recordCycles: (cycles: number) => void;
  state: {
    display?: {
      tms9918?: {
        snapshot: () => {
          active: boolean;
          registers: number[];
          vram: Uint8Array;
        };
      };
    };
    system?: {
      sysCtrl?: number;
      memoryExpansionPhysicalBank?: number;
    };
  };
};

type D8Symbol = {
  name: string;
  kind: string;
  address?: number;
  value?: number;
};

type CompileResult = {
  diagnostics: Array<{ id?: string; message?: string; severity?: string }>;
  artifacts: Array<{ kind: string; bytes?: Uint8Array; json?: { symbols?: D8Symbol[] } }>;
};

function requireFromDebug80(modulePath: string): unknown {
  return require(resolve(DEBUG80_ROOT, modulePath));
}

async function compileProof(): Promise<{ bytes: Uint8Array; symbols: D8Symbol[] }> {
  const { compile, defaultFormatWriters } = AZM_ROOT
    ? await import(resolve(AZM_ROOT, 'dist/src/api-compile.js'))
    : await import('@jhlagado/azm/compile');
  const result = (await compile(
    PROOF_SOURCE,
    {
      emitBin: true,
      emitD8m: true,
      outputType: 'bin',
      sourceRoot: TECM8_ROOT,
      d8mInputs: {
        bin: 'build/tms9918-bank-proof.bin',
      },
      registerCare: 'off',
    },
    { formats: defaultFormatWriters },
  )) as CompileResult;

  if (result.diagnostics.length > 0) {
    throw new Error(`AZM diagnostics:\n${JSON.stringify(result.diagnostics, null, 2)}`);
  }

  const bin = result.artifacts.find((artifact) => artifact.kind === 'bin');
  const d8m = result.artifacts.find((artifact) => artifact.kind === 'd8m');
  if (!bin?.bytes) {
    throw new Error('AZM did not emit bin artifact');
  }
  return { bytes: bin.bytes, symbols: d8m?.json?.symbols ?? [] };
}

function symbolNumber(symbols: D8Symbol[], name: string): number {
  const symbol = symbols.find((entry) => entry.name === name);
  const value = symbol?.address ?? symbol?.value;
  if (typeof value !== 'number') {
    throw new Error(`missing numeric symbol: ${name}`);
  }
  return value;
}

function makeConfig() {
  return {
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
    sdEnabled: false,
    sdHighCapacity: true,
    tms9918Active: true,
    expansionRomHex: EXPANSION_ROM_PATH,
  };
}

function loadRuntime(bytes: Uint8Array): { runtime: Runtime; platformRuntime: PlatformRuntime } {
  const { createTec1gRuntime } = requireFromDebug80('out/platforms/tec1g/runtime.js') as {
    createTec1gRuntime: Function;
  };
  const { createTec1gMemoryHooks, applyExpansionRomMemory } = requireFromDebug80(
    'out/platforms/tec1g/tec1g-memory.js',
  ) as { createTec1gMemoryHooks: Function; applyExpansionRomMemory: Function };
  const { loadTec1gExpansionRomImage } = requireFromDebug80(
    'out/platforms/tec1g/tec1g-expansion-rom.js',
  ) as { loadTec1gExpansionRomImage: Function };
  const { createZ80Runtime } = requireFromDebug80('out/z80/runtime.js') as {
    createZ80Runtime: Function;
  };

  const config = makeConfig();
  const tec1gRuntime = createTec1gRuntime(config, () => {});
  const memory = new Uint8Array(0x10000);
  const monitorRom = readFileSync(MONITOR_ROM_PATH);
  memory.set(monitorRom.subarray(0, 0x4000), 0xc000);
  memory.set(bytes, APP_START);

  const runtime = createZ80Runtime({ memory, startAddress: APP_START }, APP_START, tec1gRuntime.ioHandlers, {
    romRanges: config.romRanges,
  }) as Runtime;

  const hooks = createTec1gMemoryHooks(
    runtime.hardware.memory,
    config.romRanges,
    tec1gRuntime.state.system,
  );
  const expansionImage = loadTec1gExpansionRomImage(EXPANSION_ROM_PATH);
  applyExpansionRomMemory(hooks.expandBanks, expansionImage);
  runtime.hardware.memRead = hooks.memRead;
  runtime.hardware.memWrite = hooks.memWrite;
  runtime.hardware.forceMemWrite = hooks.forceMemWrite;
  runtime.hardware.isMemoryWritable = hooks.isMemoryWritable;

  tec1gRuntime.ioHandlers.write?.(SYS_CTRL, SHADOW_OFF);
  runtime.hardware.forceMemWrite?.(MON3_SYS_MODE, SHADOW_OFF);
  runtime.hardware.memory.set(runtime.hardware.memory.subarray(0xc000, 0xc100), 0x0000);
  runtime.cpu.sp = 0x7ff0;
  runtime.cpu.pc = APP_START;
  return { runtime, platformRuntime: tec1gRuntime };
}

function runUntilHalt(runtime: Runtime, platformRuntime: PlatformRuntime): number {
  const maxInstructions = 1_000_000;
  const pcHistory: number[] = [];
  for (let i = 0; i < maxInstructions; i += 1) {
    pcHistory.push(runtime.cpu.pc & 0xffff);
    if (pcHistory.length > 64) {
      pcHistory.shift();
    }
    const result = runtime.step();
    platformRuntime.recordCycles(result.cycles ?? 0);
    if (runtime.cpu.halted || result.halted) {
      return i + 1;
    }
  }
  const sp = runtime.cpu.sp & 0xffff;
  const stack = Array.from(runtime.hardware.memory.slice(sp, sp + 16))
    .map((value) => value.toString(16).padStart(2, '0'))
    .join(' ');
  const trace = Array.from(runtime.hardware.memory.slice(0x3b10, 0x3b18))
    .map((value) => value.toString(16).padStart(2, '0'))
    .join(' ');
  const pcs = pcHistory.map((value) => value.toString(16).padStart(4, '0')).join(' ');
  throw new Error(
    `TMS9918 bank proof did not halt; pc=0x${runtime.cpu.pc.toString(16)} sp=0x${sp.toString(16)} stack=${stack} trace=${trace} pcs=${pcs}`,
  );
}

function readTrace(runtime: Runtime, base: number, length: number): number[] {
  return Array.from(runtime.hardware.memory.slice(base, base + length));
}

function assertEqual(actual: number, expected: number, name: string): void {
  if (actual !== expected) {
    throw new Error(`${name}: got 0x${actual.toString(16)}, expected 0x${expected.toString(16)}`);
  }
}

async function main(): Promise<void> {
  const { bytes, symbols } = await compileProof();
  const { runtime, platformRuntime } = loadRuntime(bytes);
  const instructions = runUntilHalt(runtime, platformRuntime);
  const traceBase = symbolNumber(symbols, 'TMS_PROOF_TRACE_BASE');
  const resultAddr = symbolNumber(symbols, 'TMS_PROOF_RESULT');
  const trace = readTrace(runtime, traceBase, 13);
  const tmsParamBase = symbolNumber(symbols, 'TMS_PARAM_BASE');
  const tmsParams = readTrace(runtime, tmsParamBase, 10);
  const result = runtime.hardware.memory[resultAddr];
  const tms9918 = platformRuntime.state.display?.tms9918?.snapshot();

  if (!tms9918) {
    throw new Error('Debug80 runtime did not expose a TMS9918 device snapshot');
  }

  assertEqual(result, PROOF_PASS, 'TMS9918 bank proof result marker');
  assertEqual(trace[0], INITIAL_SYS_CTRL, 'initial SYS_CTRL snapshot');
  assertEqual(trace[1], 0x81, 'VDU init return value');
  assertEqual(trace[2], INITIAL_SYS_CTRL, 'SYS_CTRL restored after VDU init');
  assertEqual(trace[3], INITIAL_SYS_CTRL, 'SYS_CTRL restored after TMS writes');
  assertEqual(trace[4], 0x81, 'VDU set cursor return value');
  assertEqual(trace[5], 0x81, 'VDU put char return value');
  assertEqual(trace[6], 0x81, 'VDU put string return value');
  assertEqual(trace[7], 0x81, 'VDU newline return value');
  assertEqual(trace[8], 0x81, 'VDU clear return value');
  assertEqual(trace[9], 0x81, 'VDU row/column cursor return value');
  assertEqual(trace[10], 0x81, 'VDU scroll-up return value');
  assertEqual(trace[11], 0x43, 'VDU row/column cursor low byte');
  assertEqual(trace[12], 0x00, 'VDU row/column cursor high byte');
  assertEqual(tms9918.registers[7] ?? 0, 0xf4, 'TMS register 7');
  assertEqual(tms9918.vram[0x0000] ?? 0, 0x53, 'VDU scroll copied row 1 to row 0');
  assertEqual(tms9918.vram[0x0123] ?? 0, 0x5a, 'TMS VRAM write');
  assertEqual(tms9918.vram[0x0124] ?? 0, 0x42, 'VDU put character write');
  assertEqual(tms9918.vram[0x0125] ?? 0, 0x4f, 'VDU string first character write');
  assertEqual(tms9918.vram[0x0126] ?? 0, 0x4b, 'VDU string second character write');
  assertEqual(tms9918.vram[0x02ff] ?? 0, 0x20, 'VDU clear final name-table byte');
  assertEqual(tmsParams[4], 0x40, 'VDU cursor low after newline');
  assertEqual(tmsParams[5], 0x01, 'VDU cursor high after newline');
  assertEqual(tmsParams[8], 0x20, 'VDU final fill count low byte');
  assertEqual(tmsParams[9], 0x00, 'VDU final fill count high byte');

  writeFileSync(
    LAST_RUN,
    `${JSON.stringify(
      {
        result: 'ok',
        instructions,
        resultMarker: result,
        trace,
        tmsParams,
        tmsRegister7: tms9918.registers[7] ?? 0,
        tmsVram0123: tms9918.vram[0x0123] ?? 0,
        tmsVram0124: tms9918.vram[0x0124] ?? 0,
        finalPc: runtime.cpu.pc & 0xffff,
        finalSysCtrl: platformRuntime.state.system?.sysCtrl,
        finalPhysicalBank: platformRuntime.state.system?.memoryExpansionPhysicalBank,
      },
      null,
      2,
    )}\n`,
  );

  console.log(`TMS9918 bank proof passed in ${instructions} instructions`);
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
