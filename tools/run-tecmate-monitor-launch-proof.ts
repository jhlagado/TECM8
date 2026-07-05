#!/usr/bin/env node
/**
 * Run the fixed-monitor expansion discovery launch path in Debug80.
 */

const { mkdtempSync, readFileSync, rmSync, writeFileSync } = require('node:fs');
const { tmpdir } = require('node:os');
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
const EXP_HEADER_MAGIC = 0x8000;
const EXP_HEADER_VERSION = 0x8004;
const EXP_HEADER_BANK = 0x8005;
const EXP_HEADER_TYPE = 0x8006;
const EXP_HEADER_FLAGS = 0x8007;
const EXP_HEADER_INSTALL = 0x8008;
const TFS_MOUNT = 0x61;
const TFS_PARAM_VOLUME_MIB = 0x3b44;
const TFS_VOLUME_MIB = 128;
const INP_PARAM_BANK = 0x3bc2;
const INP_PARAM_JOYSTICK = 0x3bc6;
const ALT_INSTALL_ADDR = 0x8200;
const ALT_MENU_ADDR = 0x8230;
const ALT_SERVICE_ADDR = 0x8240;

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
    tms9918Active: true,
    expansionRomHex: EXPANSION_ROM_PATH,
  };
}

function loadRuntime(
  entryAddress: number,
  options: { expansionImage?: boolean; expansionRomPath?: string } = {},
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
    const expansionImage = loadTec1gExpansionRomImage(options.expansionRomPath ?? EXPANSION_ROM_PATH);
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

function writeWord(image: Buffer, address: number, value: number): void {
  const offset = address - 0x8000;
  image[offset] = value & 0xff;
  image[offset + 1] = value >> 8;
}

function writeBytes(image: Buffer, address: number, bytes: number[]): void {
  image.set(bytes, address - 0x8000);
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

function readWord(runtime: Runtime, address: number): number {
  return runtime.hardware.memory[address] | (runtime.hardware.memory[address + 1] << 8);
}

function assertBank0Header(): number {
  const expectedInstallAddress = symbolNumber(BANK0_D8_PATH, 'Tecm8ExpansionInstall');
  const expansionImage = readFileSync(EXPANSION_ROM_PATH);

  assertEqual(expansionImage[EXP_HEADER_MAGIC - 0x8000] ?? -1, 'E'.charCodeAt(0), 'bank 0 header magic E');
  assertEqual(expansionImage[EXP_HEADER_MAGIC + 1 - 0x8000] ?? -1, 'X'.charCodeAt(0), 'bank 0 header magic X');
  assertEqual(expansionImage[EXP_HEADER_MAGIC + 2 - 0x8000] ?? -1, 'P'.charCodeAt(0), 'bank 0 header magic P');
  assertEqual(expansionImage[EXP_HEADER_MAGIC + 3 - 0x8000] ?? -1, 'R'.charCodeAt(0), 'bank 0 header magic R');
  assertEqual(expansionImage[EXP_HEADER_VERSION - 0x8000] ?? -1, 0x01, 'bank 0 header version');
  assertEqual(expansionImage[EXP_HEADER_BANK - 0x8000] ?? -1, 0x00, 'bank 0 header physical bank');
  assertEqual(expansionImage[EXP_HEADER_TYPE - 0x8000] ?? -1, 0x01, 'bank 0 header supervisor type');
  assertEqual(expansionImage[EXP_HEADER_FLAGS - 0x8000] ?? -1, 0x00, 'bank 0 header flags');
  assertEqual(
    (expansionImage[EXP_HEADER_INSTALL - 0x8000] ?? 0) |
      ((expansionImage[EXP_HEADER_INSTALL + 1 - 0x8000] ?? 0) << 8),
    expectedInstallAddress,
    'bank 0 header install routine',
  );

  return expectedInstallAddress;
}

function createAlternateExpansionImage(): { path: string; dir: string } {
  const dir = mkdtempSync(resolve(tmpdir(), 'tecm8-expansion-proof-'));
  const path = resolve(dir, 'expansion.bin');
  const image = Buffer.from(readFileSync(EXPANSION_ROM_PATH));

  writeWord(image, EXP_HEADER_INSTALL, ALT_INSTALL_ADDR);
  writeBytes(image, ALT_INSTALL_ADDR, [
    0x3e, 0x00, 0x32, 0xf0, 0x3b, 0x21, ALT_MENU_ADDR & 0xff, ALT_MENU_ADDR >> 8, 0x22, 0xf1, 0x3b, 0xaf, 0x32,
    0xf3, 0x3b, 0x3e, 0x00, 0x32, 0xf4, 0x3b, 0x21, ALT_SERVICE_ADDR & 0xff, ALT_SERVICE_ADDR >> 8, 0x22,
    0xf5, 0x3b, 0xaf, 0x32, 0xf7, 0x3b, 0xc9,
  ]);
  writeBytes(image, ALT_MENU_ADDR, [0x3e, 0xa5, 0x32, 0x01, 0x30, 0xc9]);
  writeBytes(image, ALT_SERVICE_ADDR, [0x3e, 0x5a, 0x32, 0x02, 0x30, 0x3e, 0x99, 0xb7, 0xc9]);

  writeFileSync(path, image);
  return { path, dir };
}

function runInstalledExpansionCase(launchAddress: number): {
  instructions: number;
  bridgeInstructions: number;
  expectedInstallAddress: number;
  expectedMenuAddress: number;
  menuVectorAddress: number;
  expectedServiceAddress: number;
  serviceVectorAddress: number;
  trace: number[];
  finalPc: number;
  finalSp: number;
  finalSysCtrl?: number;
  finalPhysicalBank?: number;
} {
  const expectedServiceAddress = symbolNumber(BANK0_D8_PATH, 'Tecm8ServiceCall');
  const expectedMenuAddress = symbolNumber(BANK0_D8_PATH, 'Tecm8ExpansionBank0Entry');
  const expectedInstallAddress = assertBank0Header();
  const { runtime, platformRuntime } = loadRuntime(launchAddress);
  const instructions = runUntilHalt(runtime, platformRuntime);
  const trace = readTrace(runtime, DBG_TRACE_BASE, 9);
  const menuVectorAddress = readWord(runtime, EXP_MENU_VEC_ADDR);
  const serviceVectorAddress = readWord(runtime, EXP_SVC_VEC_ADDR);

  assertEqual(runtime.cpu.pc, RETURN_STUB + 1, 'return stub halt pc');
  assertEqual(runtime.hardware.memory[EXP_MENU_VEC_BANK], 0x00, 'installed expansion menu bank');
  assertEqual(menuVectorAddress, expectedMenuAddress, 'installed expansion menu address');
  assertEqual(runtime.hardware.memory[EXP_MENU_VEC_FLAGS], 0x00, 'installed expansion menu flags');
  assertEqual(runtime.hardware.memory[EXP_SVC_VEC_BANK], 0x00, 'installed expansion service bank');
  assertEqual(serviceVectorAddress, expectedServiceAddress, 'installed expansion service address');
  assertEqual(runtime.hardware.memory[EXP_SVC_VEC_FLAGS], 0x00, 'installed expansion service flags');
  assertEqual(trace[0], 0x00, 'bank 0 entry marker');
  assertEqual(trace[4], 0x81, 'VDU service marker');
  assertEqual(trace[5], 0x82, 'TEC-FS service marker');
  assertEqual(trace[6], 0x83, 'RTC service marker');
  assertEqual(trace[7], 0x86, 'input service marker');
  assertEqual(trace[8], 0x80, 'shell entry marker');
  assertEqual(platformRuntime.state.system?.sysCtrl ?? -1, SHADOW_OFF, 'final SYS_CTRL restored');
  assertDemoVram(runtime, platformRuntime);

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
    expectedInstallAddress,
    expectedMenuAddress,
    menuVectorAddress,
    expectedServiceAddress,
    serviceVectorAddress,
    trace,
    finalPc: runtime.cpu.pc & 0xffff,
    finalSp: runtime.cpu.sp & 0xffff,
    finalSysCtrl: platformRuntime.state.system?.sysCtrl,
    finalPhysicalBank: platformRuntime.state.system?.memoryExpansionPhysicalBank,
  };
}

function runAlternateInstallCase(launchAddress: number): {
  instructions: number;
  bridgeInstructions: number;
  menuVectorAddress: number;
  serviceVectorAddress: number;
  trace: number[];
  finalSysCtrl?: number;
} {
  const image = createAlternateExpansionImage();
  try {
    const { runtime, platformRuntime } = loadRuntime(launchAddress, { expansionRomPath: image.path });
    const instructions = runUntilHalt(runtime, platformRuntime);
    const menuVectorAddress = readWord(runtime, EXP_MENU_VEC_ADDR);
    const serviceVectorAddress = readWord(runtime, EXP_SVC_VEC_ADDR);
    const trace = readTrace(runtime, DBG_TRACE_BASE, 3);

    assertEqual(runtime.hardware.memory[EXP_MENU_VEC_BANK], 0x00, 'alternate expansion menu bank');
    assertEqual(menuVectorAddress, ALT_MENU_ADDR, 'alternate expansion menu address');
    assertEqual(runtime.hardware.memory[EXP_MENU_VEC_FLAGS], 0x00, 'alternate expansion menu flags');
    assertEqual(runtime.hardware.memory[EXP_SVC_VEC_BANK], 0x00, 'alternate expansion service bank');
    assertEqual(serviceVectorAddress, ALT_SERVICE_ADDR, 'alternate expansion service address');
    assertEqual(runtime.hardware.memory[EXP_SVC_VEC_FLAGS], 0x00, 'alternate expansion service flags');
    assertEqual(trace[1], 0xa5, 'alternate expansion menu marker');
    assertEqual(platformRuntime.state.system?.sysCtrl ?? -1, SHADOW_OFF, 'alternate expansion SYS_CTRL restored');

    runtime.hardware.forceMemWrite?.(BRIDGE_RESULT_A, 0x00);
    runtime.hardware.forceMemWrite?.(BRIDGE_RESULT_F, 0x00);
    writeBridgeServiceStub(runtime, TFS_MOUNT);
    runtime.cpu.halted = false;
    runtime.cpu.pc = RETURN_STUB;
    runtime.cpu.sp = STACK_RETURN;
    const bridgeInstructions = runUntilHalt(runtime, platformRuntime);
    assertEqual(runtime.hardware.memory[DBG_TRACE_BASE + 2], 0x5a, 'alternate expansion service marker');
    assertEqual(runtime.hardware.memory[BRIDGE_RESULT_A], 0x99, 'alternate expansion service returned A');
    assertEqual(runtime.hardware.memory[BRIDGE_RESULT_F] & 0x01, 0x00, 'alternate expansion service returned carry clear');
    assertEqual(platformRuntime.state.system?.sysCtrl ?? -1, SHADOW_OFF, 'alternate bridge SYS_CTRL restored');

    return {
      instructions,
      bridgeInstructions,
      menuVectorAddress,
      serviceVectorAddress,
      trace,
      finalSysCtrl: platformRuntime.state.system?.sysCtrl,
    };
  } finally {
    rmSync(image.dir, { recursive: true, force: true });
  }
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

function assertDemoVram(runtime: Runtime, platformRuntime: PlatformRuntime): void {
  const tms9918 = platformRuntime.state.display?.tms9918?.snapshot();
  if (!tms9918) {
    throw new Error('Debug80 runtime did not expose a TMS9918 device snapshot');
  }
  assertEqual(tms9918.active ? 1 : 0, 1, 'demo TMS9918 device active');
  assertEqual(tms9918.vram[0x0000] ?? 0, 'T'.charCodeAt(0), 'demo VDU first splash character');
  assertEqual(tms9918.vram[0x0001] ?? 0, 'e'.charCodeAt(0), 'demo VDU second splash character');
  assertEqual(tms9918.vram[0x0002] ?? 0, 'c'.charCodeAt(0), 'demo VDU third splash character');
  assertEqual(tms9918.vram[0x0003] ?? 0, 'M'.charCodeAt(0), 'demo VDU fourth splash character');
  assertEqual(tms9918.vram[0x0004] ?? 0, 'a'.charCodeAt(0), 'demo VDU fifth splash character');
  assertEqual(tms9918.vram[0x0005] ?? 0, 't'.charCodeAt(0), 'demo VDU sixth splash character');
  assertEqual(tms9918.vram[0x0006] ?? 0, 'e'.charCodeAt(0), 'demo VDU seventh splash character');
  assertEqual(tms9918.vram[0x0007] ?? 0, ' '.charCodeAt(0), 'demo VDU title separator');
  assertEqual(tms9918.vram[0x0008] ?? 0, 'R'.charCodeAt(0), 'demo VDU title ROM character');
  assertEqual(tms9918.vram[0x0020] ?? 0, 'V'.charCodeAt(0), 'demo mode line first character');
  assertEqual(tms9918.vram[0x0024] ?? 0, 'T'.charCodeAt(0), 'demo mode line TMS marker');
  assertEqual(tms9918.vram[0x0060] ?? 0, '>'.charCodeAt(0), 'demo prompt marker');
  assertEqual(tms9918.vram[0x02e0] ?? 0, 'P'.charCodeAt(0), 'demo status first character');
  assertEqual(tms9918.vram[0x02e1] ?? 0, 'O'.charCodeAt(0), 'demo status second character');
  assertEqual(tms9918.vram[0x02e2] ?? 0, 'L'.charCodeAt(0), 'demo status third character');
  assertEqual(tms9918.vram[0x02e3] ?? 0, 'L'.charCodeAt(0), 'demo status fourth character');
  assertEqual(runtime.hardware.memory[INP_PARAM_BANK], 0x06, 'demo input service bank side effect');
  assertEqual(runtime.hardware.memory[INP_PARAM_JOYSTICK], 0x00, 'demo input neutral joystick state');
  assertEqual(runtime.hardware.memory[TFS_PARAM_VOLUME_MIB], TFS_VOLUME_MIB, 'demo TEC-FS mount side effect');
}

function main(): void {
  const launchAddress = symbolNumber(MONITOR_D8_PATH, 'launchExpansion');
  const installed = runInstalledExpansionCase(launchAddress);
  const alternate = runAlternateInstallCase(launchAddress);
  const missing = runMissingExpansionCase(launchAddress);

  writeFileSync(
    LAST_RUN,
    `${JSON.stringify(
      {
        result: 'ok',
        launchAddress,
        installed,
        alternate,
        missing,
      },
      null,
      2,
    )}\n`,
  );

  console.log(`TecMate monitor launch proof passed in ${installed.instructions} instructions`);
}

main();
