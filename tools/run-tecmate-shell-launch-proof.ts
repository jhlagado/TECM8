#!/usr/bin/env node
/**
 * Assemble and run the TecMate shell launch proof in Debug80.
 */

const { readFileSync, writeFileSync } = require('node:fs');
const { resolve } = require('node:path');

const TECM8_ROOT = resolve(__dirname, '..');
const DEBUG80_ROOT = resolve(process.env.DEBUG80_ROOT ?? '/Users/johnhardy/projects/debug80');
const AZM_ROOT = process.env.AZM_ROOT ? resolve(process.env.AZM_ROOT) : undefined;
const PROOF_SOURCE = resolve(TECM8_ROOT, 'proofs/tecmate-shell-launch/tecmate-shell-launch-proof.asm');
const LAST_RUN = resolve(TECM8_ROOT, 'proofs/tecmate-shell-launch/tecmate-shell-launch-proof-last-run.json');
const MONITOR_ROM_PATH = resolve(TECM8_ROOT, 'roms/tec1g/tecm8/monitor/monitor.bin');
const EXPANSION_ROM_PATH = resolve(TECM8_ROOT, 'roms/tec1g/tecm8/expansion/expansion.bin');
const APP_START = 0x4000;
const MON3_SYS_MODE = 0x089d;
const SYS_CTRL = 0xff;
const SHADOW_OFF = 0x01;
const PROOF_PASS = 0x42;

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
        bin: 'build/tecmate-shell-launch-proof.bin',
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
  for (let i = 0; i < maxInstructions; i += 1) {
    const result = runtime.step();
    platformRuntime.recordCycles(result.cycles ?? 0);
    if (runtime.cpu.halted || result.halted) {
      return i + 1;
    }
  }
  throw new Error(`TecMate shell launch proof did not halt; pc=0x${runtime.cpu.pc.toString(16)}`);
}

function readTrace(runtime: Runtime, base: number, length: number): number[] {
  return Array.from(runtime.hardware.memory.slice(base, base + length));
}

function assertEqual(actual: number, expected: number, name: string): void {
  if (actual !== expected) {
    throw new Error(`${name}: got 0x${actual.toString(16)}, expected 0x${expected.toString(16)}`);
  }
}

function assertVramText(platformRuntime: PlatformRuntime, address: number, expected: string, name: string): void {
  const tms9918 = platformRuntime.state.display?.tms9918?.snapshot();
  if (!tms9918) {
    throw new Error('Debug80 runtime did not expose a TMS9918 device snapshot');
  }
  assertEqual(tms9918.active ? 1 : 0, 1, `${name} TMS9918 active`);
  for (let index = 0; index < expected.length; index += 1) {
    assertEqual(tms9918.vram[address + index] ?? 0, expected.charCodeAt(index), `${name} VRAM character ${index}`);
  }
}

async function main(): Promise<void> {
  const { bytes, symbols } = await compileProof();
  const { runtime, platformRuntime } = loadRuntime(bytes);
  const instructions = runUntilHalt(runtime, platformRuntime);
  const resultAddr = symbolNumber(symbols, 'PROOF_RESULT');
  const traceBase = symbolNumber(symbols, 'PROOF_TRACE_BASE');
  const shellParamBase = symbolNumber(symbols, 'SHL_PARAM_BASE');
  const shellStatusBuffer = symbolNumber(symbols, 'SHL_STATUS_BUFFER');
  const shellSplashBuffer = symbolNumber(symbols, 'SHL_SPLASH_BUFFER');
  const shellLoopTick = symbolNumber(symbols, 'SHL_LOOP_TICK');
  const tmsParamBase = symbolNumber(symbols, 'TMS_PARAM_BASE');
  const result = runtime.hardware.memory[resultAddr];
  const trace = readTrace(runtime, traceBase, 1);
  const params = readTrace(runtime, shellParamBase, 5);
  const status = readTrace(runtime, shellStatusBuffer, 8);
  const splash = readTrace(runtime, shellSplashBuffer, 8);
  const loop = readTrace(runtime, shellLoopTick, 6);
  const tmsParams = readTrace(runtime, tmsParamBase, 8);

  assertEqual(result, PROOF_PASS, 'shell launch proof result marker');
  assertEqual(trace[0], 0x80, 'service bridge shell launch return');
  assertEqual(params[0], 0x00, 'shell status');
  assertEqual(params[1], 0x00, 'shell last error');
  assertEqual(params[2], 0x00, 'shell bank marker');
  assertEqual(params[3], 0x01, 'shell version marker');
  assertEqual(params[4], 0x07, 'shell feature marker');
  assertEqual(status[0], 0x50, 'shell status P');
  assertEqual(status[1], 0x4f, 'shell status O');
  assertEqual(status[2], 0x4c, 'shell status L');
  assertEqual(status[3], 0x4c, 'shell status L');
  assertEqual(status[4], 0x00, 'shell status terminator');
  assertEqual(splash[0], 0x54, 'shell splash T');
  assertEqual(splash[1], 0x65, 'shell splash e');
  assertEqual(splash[2], 0x63, 'shell splash c');
  assertEqual(splash[3], 0x4d, 'shell splash M');
  assertEqual(splash[4], 0x61, 'shell splash a');
  assertEqual(splash[5], 0x74, 'shell splash t');
  assertEqual(splash[6], 0x65, 'shell splash e');
  assertEqual(splash[7], 0x00, 'shell splash terminator');
  assertEqual(loop[0], 0x01, 'shell loop tick');
  assertEqual(loop[1], 0x03, 'shell loop dirty mask');
  assertEqual(loop[2], 0x00, 'shell loop keys low');
  assertEqual(loop[3], 0x00, 'shell loop keys high');
  assertEqual(loop[4], 0x00, 'shell loop joystick');
  assertEqual(loop[5], 0x00, 'shell loop modifiers');
  assertEqual(platformRuntime.state.system?.sysCtrl ?? -1, SHADOW_OFF, 'shell launch SYS_CTRL restored');
  assertEqual(runtime.hardware.memory[MON3_SYS_MODE], SHADOW_OFF, 'shell launch SYS_MODE shadow restored');
  assertVramText(platformRuntime, 0x0000, 'TecMate ROM Shell', 'shell title');
  assertVramText(platformRuntime, 0x0020, 'VDU:TMS TEC-FS:ROM', 'shell mode line');
  assertVramText(platformRuntime, 0x0060, '> ', 'shell prompt');
  assertVramText(platformRuntime, 0x02e0, 'POLL', 'shell status');

  writeFileSync(
    LAST_RUN,
    `${JSON.stringify(
      {
        result: 'ok',
        instructions,
        resultMarker: result,
        trace,
        params,
        status,
        splash,
        loop,
        tmsParams,
        finalPc: runtime.cpu.pc & 0xffff,
        finalSysCtrl: platformRuntime.state.system?.sysCtrl,
        finalPhysicalBank: platformRuntime.state.system?.memoryExpansionPhysicalBank,
      },
      null,
      2,
    )}\n`,
  );

  console.log(`TecMate shell launch proof passed in ${instructions} instructions`);
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
