#!/usr/bin/env node
/**
 * Strict register-contract check for TECM8 expansion ROM banks.
 *
 * Debug80 does not yet apply target AZM contract policy to TEC-1G ROM
 * artifacts, so this project-local check keeps the banked ROM surface strict.
 */

const { relative, resolve } = require('node:path');

const TECM8_ROOT = resolve(__dirname, '..');
const EXPANSION_ROOT = resolve(TECM8_ROOT, 'roms/tec1g/tecm8/expansion');
const RST_INTERFACE = resolve(EXPANSION_ROOT, 'tecm8-rst-services.asmi');
const LEGACY_STORAGE_INTERFACE = resolve(EXPANSION_ROOT, 'mon3-storage-legacy.asmi');
const LEGACY_STORAGE_MODULE = resolve(
  TECM8_ROOT,
  'roms/tec1g/tecm8/monitor/pata_fat32.asm'
);
const BANK_COUNT = 9;

type Diagnostic = {
  severity?: string;
  code?: string;
  sourceName?: string;
  line?: number;
  column?: number;
  message?: string;
};

type CompileResult = {
  diagnostics: readonly Diagnostic[];
};

function formatDiagnostic(diagnostic: Diagnostic): string {
  const file = diagnostic.sourceName
    ? relative(TECM8_ROOT, diagnostic.sourceName)
    : 'unknown';
  const line = diagnostic.line ?? 0;
  const column = diagnostic.column ?? 0;
  const severity = diagnostic.severity ?? 'unknown';
  const code = diagnostic.code ?? 'unknown';
  const message = diagnostic.message ?? '';
  return `${file}:${line}:${column} ${severity} ${code} ${message}`;
}

function isQuarantinedLegacyStorageDiagnostic(diagnostic: Diagnostic): boolean {
  return (
    diagnostic.code === 'AZMN_REGISTER_CONTRACTS' &&
    diagnostic.sourceName === LEGACY_STORAGE_MODULE
  );
}

async function main(): Promise<void> {
  const { compile, defaultFormatWriters } = await import('@jhlagado/azm/compile');
  const allDiagnostics: Diagnostic[] = [];

  for (let bank = 0; bank < BANK_COUNT; bank += 1) {
    const sourceFile = resolve(EXPANSION_ROOT, `bank${bank}.asm`);
    const result = (await compile(
      sourceFile,
      {
        emitBin: false,
        emitD8m: false,
        outputType: 'bin',
        sourceRoot: TECM8_ROOT,
        registerContracts: 'strict',
        registerContractsPolicy: {
          strict: ['roms/tec1g/tecm8/expansion/**/*.asm'],
          off: ['roms/tec1g/tecm8/monitor/pata_fat32.asm'],
        },
        registerContractsProfile: 'mon3',
        registerContractsInterfaces: [RST_INTERFACE, LEGACY_STORAGE_INTERFACE],
        emitRegisterReport: true,
      },
      { formats: defaultFormatWriters }
    )) as CompileResult;

    const quarantinedDiagnostics = result.diagnostics.filter(
      isQuarantinedLegacyStorageDiagnostic
    );
    const blockingDiagnostics = result.diagnostics.filter(
      (diagnostic) => !isQuarantinedLegacyStorageDiagnostic(diagnostic)
    );
    console.log(
      `bank${bank}: diagnostics=${blockingDiagnostics.length} ` +
        `legacy-storage=${quarantinedDiagnostics.length}`
    );
    allDiagnostics.push(...blockingDiagnostics);
  }

  if (allDiagnostics.length > 0) {
    console.error('\nExpansion register contract diagnostics:');
    for (const diagnostic of allDiagnostics) {
      console.error(formatDiagnostic(diagnostic));
    }
    process.exitCode = 1;
    return;
  }

  console.log('Expansion register contracts passed.');
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
