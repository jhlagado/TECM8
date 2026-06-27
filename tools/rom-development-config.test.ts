const { strict: assert } = require('node:assert');
const { existsSync, readFileSync, statSync } = require('node:fs');
const { resolve } = require('node:path');
const { test } = require('node:test');

const root = resolve(__dirname, '..');

function readJson(path: string): unknown {
  return JSON.parse(readFileSync(resolve(root, path), 'utf8'));
}

function readText(path: string): string {
  return readFileSync(resolve(root, path), 'utf8');
}

function readDebugSymbols(path: string): Array<{ name: string; address?: number; value?: number }> {
  const debugMap = readJson(path) as {
    files?: Record<string, { symbols?: Array<{ name: string; address?: number; value?: number }> }>;
  };
  return Object.values(debugMap.files ?? {}).flatMap((file) => file.symbols ?? []);
}

function symbolAddress(path: string, name: string): number | undefined {
  return readDebugSymbols(path).find((symbol) => symbol.name === name)?.address;
}

function expectedExpansionBanks(): Array<Record<string, unknown>> {
  return Array.from({ length: 9 }, (_, physicalBank) => ({
    physicalBank,
    sourceFile: `roms/tec1g/tecm8/expansion/bank${physicalBank}.asm`,
    outputBin: `build/roms/tec1g/tecm8/expansion/bank${physicalBank}.bin`,
    outputDebugMap: `build/roms/tec1g/tecm8/expansion/bank${physicalBank}.d8.json`,
  }));
}

test('TECM8 Debug80 config uses a custom profile with monitor and expansion ROM source roots', () => {
  const config = readJson('debug80.json') as {
    defaultProfile?: string;
    profiles?: Record<string, { platform?: string; description?: string }>;
    targets?: Record<string, {
      profile?: string;
      sourceRoots?: string[];
      tec1g?: {
        romHex?: unknown;
        expansionRomHex?: unknown;
        romArtifacts?: Array<Record<string, unknown>>;
      };
    }>;
  };

  assert.equal(config.defaultProfile, 'tecm8');
  assert.equal(config.profiles?.tecm8?.platform, 'tec1g');
  assert.match(config.profiles?.tecm8?.description ?? '', /TECM8/);

  for (const targetName of ['main', 'keyboard-tester.main']) {
    const target = config.targets?.[targetName];
    assert.ok(target, `${targetName} target should exist`);
    const resolvedTarget = target as NonNullable<typeof target>;
    assert.equal(resolvedTarget.profile, 'tecm8');
    assert.deepEqual(resolvedTarget.sourceRoots, [
      'src',
      'roms/tec1g/mon3',
      'roms/tec1g/tecm8/monitor',
      'roms/tec1g/tecm8/expansion',
    ]);
    assert.equal(resolvedTarget.tec1g?.romHex, 'build/roms/tec1g/tecm8/monitor/monitor.bin');
    assert.equal(
      resolvedTarget.tec1g?.expansionRomHex,
      'build/roms/tec1g/tecm8/expansion/expansion-144k.bin'
    );
    assert.deepEqual(resolvedTarget.tec1g?.romArtifacts, [
      {
        id: 'tecm8-expansion',
        role: 'expansion',
        outputBin: 'build/roms/tec1g/tecm8/expansion/expansion-144k.bin',
        windowAddress: 32768,
        windowSize: 16384,
        imageSize: 147456,
        bankSize: 16384,
        bankCount: 9,
        banks: expectedExpansionBanks(),
      },
      {
        id: 'tecm8-monitor',
        role: 'monitor',
        sourceFile: 'roms/tec1g/tecm8/monitor/monitor.asm',
        outputBin: 'build/roms/tec1g/tecm8/monitor/monitor.bin',
        outputDebugMap: 'build/roms/tec1g/tecm8/monitor/monitor.d8.json',
        address: 49152,
        size: 16384,
      },
    ]);
  }
});

test('TECM8 project tracks ROM source folders and has ROM build scripts', () => {
  const gitignore = readText('.gitignore');
  assert.doesNotMatch(gitignore, /^roms\/$/m);

  for (const path of [
    'roms/tec1g/tecm8/monitor/monitor.asm',
    'tools/build-monitor-rom.ts',
    'tools/build-expansion-rom.ts',
    ...Array.from({ length: 9 }, (_, bank) => `roms/tec1g/tecm8/expansion/bank${bank}.asm`),
  ]) {
    assert.equal(existsSync(resolve(root, path)), true, `${path} should exist`);
  }

  const packageJson = readJson('package.json') as { scripts?: Record<string, string> };
  assert.equal(packageJson.scripts?.['rom:monitor'], 'node --experimental-strip-types tools/build-monitor-rom.ts');
  assert.equal(packageJson.scripts?.['rom:expansion'], 'node --experimental-strip-types tools/build-expansion-rom.ts');
  assert.equal(packageJson.scripts?.['rom:check'], 'npm run rom:monitor && npm run rom:expansion');
});

test('TECM8 monitor source is a project-local MON-3 source tree', () => {
  const monitorAsm = readText('roms/tec1g/tecm8/monitor/monitor.asm');

  assert.doesNotMatch(monitorAsm, /\.include\s+"monitor\.main\.asm"/);
  assert.doesNotMatch(monitorAsm, /Tecm8MonitorHold/);
  assert.equal(existsSync(resolve(root, 'roms/tec1g/tecm8/monitor/monitor.main.asm')), false);

  for (const path of [
    'roms/tec1g/tecm8/monitor/packages.asm',
    'roms/tec1g/tecm8/monitor/glcd_library.asm',
    'roms/tec1g/tecm8/monitor/pata_fat32.asm',
    'roms/tec1g/tecm8/monitor/disassembler.asm',
    'roms/tec1g/tecm8/monitor/rtc.asm',
    'roms/tec1g/tecm8/monitor/sound.asm',
    'roms/tec1g/tecm8/monitor/api_includes.asm',
  ]) {
    assert.equal(existsSync(resolve(root, path)), true, `${path} should exist`);
  }

  assert.match(monitorAsm, /MONITOR 3 for the TEC-1G/);
  assert.match(monitorAsm, /\.org BASE_ADDR/);
  assert.match(monitorAsm, /\.include "packages\.asm"/);
});

test('TECM8 monitor ROM binary is a full fixed ROM image', () => {
  const monitorBin = resolve(root, 'roms/tec1g/tecm8/monitor/monitor.bin');

  assert.equal(existsSync(monitorBin), true, 'monitor ROM binary should exist');
  assert.equal(statSync(monitorBin).size, 16384);
});

test('TECM8 expansion ROM binary is a full packed nine-bank backing image', () => {
  const expansionBin = resolve(root, 'roms/tec1g/tecm8/expansion/expansion.bin');

  assert.equal(existsSync(expansionBin), true, 'expansion ROM binary should exist');
  assert.equal(statSync(expansionBin).size, 147456);
});

test('TECM8 expansion banks expose the first service skeleton entry points', () => {
  assert.equal(symbolAddress('build/roms/tec1g/tecm8/expansion/bank1.d8.json', 'vduInit'), 0x8010);
  assert.equal(symbolAddress('build/roms/tec1g/tecm8/expansion/bank1.d8.json', 'vduClear'), 0x8020);
  assert.equal(symbolAddress('build/roms/tec1g/tecm8/expansion/bank1.d8.json', 'vduSetCursor'), 0x8030);
  assert.equal(symbolAddress('build/roms/tec1g/tecm8/expansion/bank1.d8.json', 'vduPutChar'), 0x8040);
  assert.equal(symbolAddress('build/roms/tec1g/tecm8/expansion/bank1.d8.json', 'tmsInit'), 0x8080);
  assert.equal(symbolAddress('build/roms/tec1g/tecm8/expansion/bank1.d8.json', 'tmsSetRegister'), 0x8090);
  assert.equal(symbolAddress('build/roms/tec1g/tecm8/expansion/bank1.d8.json', 'tmsWriteVram'), 0x80A0);

  assert.equal(symbolAddress('build/roms/tec1g/tecm8/expansion/bank2.d8.json', 'tecfsMount'), 0x8010);
  assert.equal(symbolAddress('build/roms/tec1g/tecm8/expansion/bank2.d8.json', 'tecfsSelectVolume'), 0x8020);
  assert.equal(symbolAddress('build/roms/tec1g/tecm8/expansion/bank2.d8.json', 'tecfsRead'), 0x8030);
  assert.equal(symbolAddress('build/roms/tec1g/tecm8/expansion/bank2.d8.json', 'tecfsWrite'), 0x8040);
  assert.equal(symbolAddress('build/roms/tec1g/tecm8/expansion/bank2.d8.json', 'tecfsLoadRange'), 0x8050);
  assert.equal(symbolAddress('build/roms/tec1g/tecm8/expansion/bank2.d8.json', 'tecfsSaveRange'), 0x8060);

  assert.equal(symbolAddress('build/roms/tec1g/tecm8/expansion/bank3.d8.json', 'rtcToolEntry'), 0x8010);
  assert.equal(symbolAddress('build/roms/tec1g/tecm8/expansion/bank3.d8.json', 'rtcSetupUi'), 0x8020);
  assert.equal(symbolAddress('build/roms/tec1g/tecm8/expansion/bank3.d8.json', 'rtcPramViewer'), 0x8030);
});
