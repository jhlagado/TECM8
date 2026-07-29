#!/usr/bin/env node
/**
 * Assemble and run the TecMate bank-7 assembler service skeleton proof in Debug80.
 */

const { readFileSync, writeFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { loadDebug80RuntimeModules, loadExpansionRomImage } = require('./debug80-integration.ts');

const TECM8_ROOT = resolve(__dirname, '..');
const AZM_ROOT = process.env.AZM_ROOT ? resolve(process.env.AZM_ROOT) : undefined;
const PROOF_SOURCE = resolve(TECM8_ROOT, 'proofs/assembler-bank/assembler-bank-proof.asm');
const LAST_RUN = resolve(TECM8_ROOT, 'proofs/assembler-bank/assembler-bank-proof-last-run.json');
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
        bin: 'build/assembler-bank-proof.bin',
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
    expansionRomHex: EXPANSION_ROM_PATH,
  };
}

async function loadRuntime(bytes: Uint8Array): Promise<{ runtime: Runtime; platformRuntime: PlatformRuntime }> {
  const { createTec1gRuntime, createTec1gMemoryHooks, applyExpansionRomMemory, createZ80Runtime } =
    await loadDebug80RuntimeModules();

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
  const expansionImage = loadExpansionRomImage(EXPANSION_ROM_PATH);
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
  throw new Error(`assembler bank proof did not halt; pc=0x${runtime.cpu.pc.toString(16)}`);
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
  const { runtime, platformRuntime } = await loadRuntime(bytes);
  const instructions = runUntilHalt(runtime, platformRuntime);
  const resultAddr = symbolNumber(symbols, 'ASM_PROOF_RESULT');
  const paramBase = symbolNumber(symbols, 'ASM_PARAM_BASE');
  const runParamBase = symbolNumber(symbols, 'RUN_PARAM_BASE');
  const result = runtime.hardware.memory[resultAddr];
  const params = readTrace(runtime, paramBase, 8);
  const runParams = readTrace(runtime, runParamBase, 8);

  assertEqual(result, PROOF_PASS, 'assembler bank proof result marker');
  assertEqual(params[0], 0x5a, 'assembler status preserved after unknown selector');
  assertEqual(params[1], 0xa5, 'assembler last error preserved after unknown selector');
  assertEqual(params[2], 0x07, 'assembler service bank');
  assertEqual(params[3], 0x01, 'assembler service version');
  assertEqual(params[4], 0xab, 'assembler target descriptor low byte');
  assertEqual(params[5], 0x3b, 'assembler shell target descriptor high byte');
  assertEqual(params[6], 0x04, 'assembler shell result low byte');
  assertEqual(params[7], 0x00, 'assembler shell result high byte');
  assertEqual(runParams[0], 0x5a, 'run status preserved after unknown selector');
  assertEqual(runParams[1], 0xa5, 'run last error preserved after unknown selector');
  assertEqual(runParams[2], 0x08, 'run service bank');
  assertEqual(runParams[3], 0x01, 'run service version');
  assertEqual(runParams[4], 0xab, 'run shell target descriptor low byte');
  assertEqual(runParams[5], 0x3b, 'run shell target descriptor high byte');
  assertEqual(runParams[6], 0x04, 'run shell result low byte');
  assertEqual(runParams[7], 0x00, 'run shell result high byte');

  writeFileSync(
    LAST_RUN,
    `${JSON.stringify(
      {
        result: 'ok',
        instructions,
        resultMarker: result,
        params,
        runParams,
        finalPc: runtime.cpu.pc & 0xffff,
        finalSysCtrl: platformRuntime.state.system?.sysCtrl,
        finalPhysicalBank: platformRuntime.state.system?.memoryExpansionPhysicalBank,
      },
      null,
      2,
    )}\n`,
  );

  console.log(`assembler bank proof passed in ${instructions} instructions`);
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
