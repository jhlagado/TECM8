#!/usr/bin/env node
/**
 * Run the fixed-monitor expansion discovery launch path in Debug80.
 */

const { readFileSync, writeFileSync } = require('node:fs');
const { resolve } = require('node:path');

const TECM8_ROOT = resolve(__dirname, '..');
const DEBUG80_ROOT = resolve(process.env.DEBUG80_ROOT ?? '/Users/johnhardy/projects/debug80');
const LAST_RUN = resolve(TECM8_ROOT, 'proofs/tecmate-monitor-launch/tecmate-monitor-launch-last-run.json');
const MONITOR_ROM_PATH = resolve(TECM8_ROOT, 'roms/tec1g/tecm8/monitor/monitor.bin');
const MONITOR_D8_PATH = resolve(TECM8_ROOT, 'build/roms/tec1g/tecm8/monitor/monitor.d8.json');
const BANK0_D8_PATH = resolve(TECM8_ROOT, 'build/roms/tec1g/tecm8/expansion/bank0.d8.json');
const EXPANSION_ROM_PATH = resolve(TECM8_ROOT, 'roms/tec1g/tecm8/expansion/expansion.bin');
const RETURN_STUB = 0x4000;
const STACK_RETURN = 0x7fee;
const MON3_SYS_MODE = 0x089d;
const SYS_CTRL = 0xff;
const SHADOW_OFF = 0x01;
const DBG_TRACE_BASE = 0x3000;
const BRIDGE_RESULT_F = DBG_TRACE_BASE + 10;
const BRIDGE_RESULT_A = DBG_TRACE_BASE + 11;
const EXP_MENU_VEC_BANK = 0x3bf0;
const EXP_MENU_VEC_ADDR = 0x3bf1;
const EXP_MENU_VEC_FLAGS = 0x3bf3;
const EXP_SVC_VEC_BANK = 0x3bf4;
const EXP_SVC_VEC_ADDR = 0x3bf5;
const EXP_SVC_VEC_FLAGS = 0x3bf7;
const TFS_MOUNT = 0x61;
const TFS_PARAM_VOLUME_MIB = 0x3b44;
const TFS_VOLUME_MIB = 128;

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
  address?: number;
  value?: number;
};

function requireFromDebug80(modulePath: string): unknown {
  return require(resolve(DEBUG80_ROOT, modulePath));
}

function symbolNumber(d8Path: string, name: string): number {
  const d8 = JSON.parse(readFileSync(d8Path, 'utf8')) as { symbols?: D8Symbol[] };
  const symbol = d8.symbols?.find((entry) => entry.name === name);
  const value = symbol?.address ?? symbol?.value;
  if (typeof value !== 'number') {
    throw new Error(`missing numeric symbol ${name} in ${d8Path}`);
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
    appStart: RETURN_STUB,
    entry: RETURN_STUB,
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

function loadRuntime(
  entryAddress: number,
  options: { expansionImage?: boolean } = {},
): { runtime: Runtime; platformRuntime: PlatformRuntime } {
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
  memory[RETURN_STUB] = 0x76;
  memory[STACK_RETURN] = RETURN_STUB & 0xff;
  memory[STACK_RETURN + 1] = RETURN_STUB >> 8;

  const runtime = createZ80Runtime({ memory, startAddress: entryAddress }, entryAddress, tec1gRuntime.ioHandlers, {
    romRanges: config.romRanges,
  }) as Runtime;

  const hooks = createTec1gMemoryHooks(
    runtime.hardware.memory,
    config.romRanges,
    tec1gRuntime.state.system,
  );
  if (options.expansionImage !== false) {
    const expansionImage = loadTec1gExpansionRomImage(EXPANSION_ROM_PATH);
    applyExpansionRomMemory(hooks.expandBanks, expansionImage);
  }
  runtime.hardware.memRead = hooks.memRead;
  runtime.hardware.memWrite = hooks.memWrite;
  runtime.hardware.forceMemWrite = hooks.forceMemWrite;
  runtime.hardware.isMemoryWritable = hooks.isMemoryWritable;

  tec1gRuntime.ioHandlers.write?.(SYS_CTRL, SHADOW_OFF);
  runtime.hardware.forceMemWrite?.(MON3_SYS_MODE, SHADOW_OFF);
  runtime.hardware.memory.set(runtime.hardware.memory.subarray(0xc000, 0xc100), 0x0000);
  runtime.cpu.sp = STACK_RETURN;
  runtime.cpu.pc = entryAddress;
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
  throw new Error(`TecMate monitor launch proof did not halt; pc=0x${runtime.cpu.pc.toString(16)}`);
}

function readTrace(runtime: Runtime, base: number, length: number): number[] {
  return Array.from(runtime.hardware.memory.slice(base, base + length));
}

function writeBridgeServiceStub(runtime: Runtime, serviceId: number): void {
  runtime.hardware.forceMemWrite?.(RETURN_STUB, 0x0e);
  runtime.hardware.forceMemWrite?.(RETURN_STUB + 1, serviceId);
  runtime.hardware.forceMemWrite?.(RETURN_STUB + 2, 0xd7);
  runtime.hardware.forceMemWrite?.(RETURN_STUB + 3, 0xf5);
  runtime.hardware.forceMemWrite?.(RETURN_STUB + 4, 0xe1);
  runtime.hardware.forceMemWrite?.(RETURN_STUB + 5, 0x22);
  runtime.hardware.forceMemWrite?.(RETURN_STUB + 6, BRIDGE_RESULT_F & 0xff);
  runtime.hardware.forceMemWrite?.(RETURN_STUB + 7, BRIDGE_RESULT_F >> 8);
  runtime.hardware.forceMemWrite?.(RETURN_STUB + 8, 0x76);
}

function assertEqual(actual: number, expected: number, name: string): void {
  if (actual !== expected) {
    throw new Error(`${name}: got 0x${actual.toString(16)}, expected 0x${expected.toString(16)}`);
  }
}

function assertClearedExpansionVectors(runtime: Runtime): void {
  assertEqual(runtime.hardware.memory[EXP_MENU_VEC_BANK], 0x00, 'cleared expansion menu bank');
  assertEqual(runtime.hardware.memory[EXP_MENU_VEC_ADDR], 0x00, 'cleared expansion menu address lo');
  assertEqual(runtime.hardware.memory[EXP_MENU_VEC_ADDR + 1], 0x00, 'cleared expansion menu address hi');
  assertEqual(runtime.hardware.memory[EXP_MENU_VEC_FLAGS], 0x00, 'cleared expansion menu flags');
  assertEqual(runtime.hardware.memory[EXP_SVC_VEC_BANK], 0x00, 'cleared expansion service bank');
  assertEqual(runtime.hardware.memory[EXP_SVC_VEC_ADDR], 0x00, 'cleared expansion service address lo');
  assertEqual(runtime.hardware.memory[EXP_SVC_VEC_ADDR + 1], 0x00, 'cleared expansion service address hi');
  assertEqual(runtime.hardware.memory[EXP_SVC_VEC_FLAGS], 0x00, 'cleared expansion service flags');
}

function runInstalledExpansionCase(launchAddress: number): {
  instructions: number;
  bridgeInstructions: number;
  expectedMenuAddress: number;
  menuVectorAddress: number;
  trace: number[];
  finalPc: number;
  finalSp: number;
  finalSysCtrl?: number;
  finalPhysicalBank?: number;
} {
  const expectedMenuAddress = symbolNumber(BANK0_D8_PATH, 'Tecm8ExpansionBank0Entry');
  const { runtime, platformRuntime } = loadRuntime(launchAddress);
  const instructions = runUntilHalt(runtime, platformRuntime);
  const trace = readTrace(runtime, DBG_TRACE_BASE, 9);
  const menuVectorAddress =
    runtime.hardware.memory[EXP_MENU_VEC_ADDR] | (runtime.hardware.memory[EXP_MENU_VEC_ADDR + 1] << 8);

  assertEqual(runtime.cpu.pc, RETURN_STUB + 1, 'return stub halt pc');
  assertEqual(runtime.hardware.memory[EXP_MENU_VEC_BANK], 0x00, 'installed expansion menu bank');
  assertEqual(menuVectorAddress, expectedMenuAddress, 'installed expansion menu address');
  assertEqual(runtime.hardware.memory[EXP_MENU_VEC_FLAGS], 0x00, 'installed expansion menu flags');
  assertEqual(trace[0], 0x00, 'bank 0 entry marker');
  assertEqual(trace[4], 0x81, 'VDU service marker');
  assertEqual(trace[5], 0x82, 'TEC-FS service marker');
  assertEqual(trace[6], 0x83, 'RTC service marker');
  assertEqual(trace[7], 0x70, 'input bootstrap marker');
  assertEqual(trace[8], 0x71, 'shell bootstrap marker');
  assertEqual(platformRuntime.state.system?.sysCtrl ?? -1, SHADOW_OFF, 'final SYS_CTRL restored');

  runtime.hardware.forceMemWrite?.(TFS_PARAM_VOLUME_MIB, 0x00);
  runtime.hardware.forceMemWrite?.(BRIDGE_RESULT_A, 0x00);
  runtime.hardware.forceMemWrite?.(BRIDGE_RESULT_F, 0x00);
  writeBridgeServiceStub(runtime, TFS_MOUNT);
  runtime.cpu.halted = false;
  runtime.cpu.pc = RETURN_STUB;
  runtime.cpu.sp = STACK_RETURN;
  const bridgeInstructions = runUntilHalt(runtime, platformRuntime);
  assertEqual(runtime.cpu.pc, RETURN_STUB + 9, 'bridge service halt pc');
  assertEqual(runtime.hardware.memory[TFS_PARAM_VOLUME_MIB], TFS_VOLUME_MIB, 'bridge TEC-FS mount side effect');
  assertEqual(runtime.hardware.memory[BRIDGE_RESULT_A], 0x82, 'bridge returned A');
  assertEqual(runtime.hardware.memory[BRIDGE_RESULT_F] & 0x01, 0x00, 'bridge returned carry clear');
  assertEqual(platformRuntime.state.system?.sysCtrl ?? -1, SHADOW_OFF, 'bridge SYS_CTRL restored');

  return {
    instructions,
    bridgeInstructions,
    expectedMenuAddress,
    menuVectorAddress,
    trace,
    finalPc: runtime.cpu.pc & 0xffff,
    finalSp: runtime.cpu.sp & 0xffff,
    finalSysCtrl: platformRuntime.state.system?.sysCtrl,
    finalPhysicalBank: platformRuntime.state.system?.memoryExpansionPhysicalBank,
  };
}

function runMissingExpansionCase(launchAddress: number): {
  instructions: number;
  bridgeInstructions: number;
  trace: number[];
  finalPc: number;
  finalSp: number;
  finalSysCtrl?: number;
  finalPhysicalBank?: number;
} {
  const { runtime, platformRuntime } = loadRuntime(launchAddress, { expansionImage: false });
  const instructions = runUntilHalt(runtime, platformRuntime);
  const trace = readTrace(runtime, DBG_TRACE_BASE, 9);

  assertEqual(runtime.cpu.pc, RETURN_STUB + 1, 'missing expansion return stub halt pc');
  assertClearedExpansionVectors(runtime);
  assertEqual(trace[0], 0x00, 'missing expansion bank 0 marker remains clear');
  assertEqual(trace[4], 0x00, 'missing expansion VDU marker remains clear');
  assertEqual(trace[5], 0x00, 'missing expansion TEC-FS marker remains clear');
  assertEqual(trace[6], 0x00, 'missing expansion RTC marker remains clear');
  assertEqual(trace[7], 0x00, 'missing expansion input marker remains clear');
  assertEqual(trace[8], 0x00, 'missing expansion shell marker remains clear');
  assertEqual(platformRuntime.state.system?.sysCtrl ?? -1, SHADOW_OFF, 'missing expansion SYS_CTRL restored');

  runtime.hardware.forceMemWrite?.(TFS_PARAM_VOLUME_MIB, 0x00);
  runtime.hardware.forceMemWrite?.(BRIDGE_RESULT_A, 0x00);
  runtime.hardware.forceMemWrite?.(BRIDGE_RESULT_F, 0x00);
  writeBridgeServiceStub(runtime, TFS_MOUNT);
  runtime.cpu.halted = false;
  runtime.cpu.pc = RETURN_STUB;
  runtime.cpu.sp = STACK_RETURN;
  const bridgeInstructions = runUntilHalt(runtime, platformRuntime);
  assertEqual(runtime.cpu.pc, RETURN_STUB + 9, 'missing expansion bridge halt pc');
  assertEqual(runtime.hardware.memory[TFS_PARAM_VOLUME_MIB], 0x00, 'missing expansion TEC-FS mount side effect remains clear');
  assertEqual(runtime.hardware.memory[BRIDGE_RESULT_A], 0xff, 'missing expansion returned A');
  assertEqual(runtime.hardware.memory[BRIDGE_RESULT_F] & 0x01, 0x01, 'missing expansion returned carry set');
  assertClearedExpansionVectors(runtime);
  assertEqual(platformRuntime.state.system?.sysCtrl ?? -1, SHADOW_OFF, 'missing bridge SYS_CTRL restored');

  return {
    instructions,
    bridgeInstructions,
    trace,
    finalPc: runtime.cpu.pc & 0xffff,
    finalSp: runtime.cpu.sp & 0xffff,
    finalSysCtrl: platformRuntime.state.system?.sysCtrl,
    finalPhysicalBank: platformRuntime.state.system?.memoryExpansionPhysicalBank,
  };
}

function main(): void {
  const launchAddress = symbolNumber(MONITOR_D8_PATH, 'launchExpansion');
  const installed = runInstalledExpansionCase(launchAddress);
  const missing = runMissingExpansionCase(launchAddress);

  writeFileSync(
    LAST_RUN,
    `${JSON.stringify(
      {
        result: 'ok',
        launchAddress,
        installed,
        missing,
      },
      null,
      2,
    )}\n`,
  );

  console.log(`TecMate monitor launch proof passed in ${installed.instructions} instructions`);
}

main();
