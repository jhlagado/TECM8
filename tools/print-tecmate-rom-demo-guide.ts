#!/usr/bin/env node
/**
 * Print the manual Debug80 launch checklist for the current ROM demo proof.
 */

const { existsSync, readFileSync } = require('node:fs');
const { resolve } = require('node:path');

const root = resolve(__dirname, '..');
const proofPath = resolve(root, 'proofs/tecmate-monitor-launch/tecmate-monitor-launch-last-run.json');

type LastRun = {
  result?: string;
  launchAddress?: number;
  installed?: {
    instructions?: number;
    bridgeInstructions?: number;
    trace?: number[];
    finalSysCtrl?: number;
    finalPhysicalBank?: number;
    expectedMenuAddress?: number;
    expectedServiceAddress?: number;
  };
};

function hex(value: number | undefined): string {
  if (typeof value !== 'number') {
    return 'unknown';
  }
  return `${value.toString(16).toUpperCase().padStart(4, '0')}h`;
}

function readLastRun(): LastRun {
  if (!existsSync(proofPath)) {
    throw new Error(`missing monitor launch proof output: ${proofPath}`);
  }

  const data = JSON.parse(readFileSync(proofPath, 'utf8')) as LastRun;
  if (data.result !== 'ok') {
    throw new Error(`monitor launch proof did not report ok in ${proofPath}`);
  }
  if (!data.installed || !Array.isArray(data.installed.trace)) {
    throw new Error(`monitor launch proof output is missing installed trace data: ${proofPath}`);
  }

  const expectedTrace = [0x00, undefined, undefined, undefined, 0x81, 0x82, 0x83, 0x86, 0x80];
  for (let index = 0; index < expectedTrace.length; index += 1) {
    const expected = expectedTrace[index];
    if (typeof expected === 'number' && data.installed.trace[index] !== expected) {
      throw new Error(
        `unexpected installed trace[${index}]: got ${hex(data.installed.trace[index])}, expected ${hex(expected)}`,
      );
    }
  }

  return data;
}

function main(): void {
  const proof = readLastRun();
  const installed = proof.installed ?? {};

  console.log('# TecMate ROM Demo Manual Launch');
  console.log('');
  console.log('Run this before opening Debug80:');
  console.log('');
  console.log('```text');
  console.log('npm run demo:tecmate-rom:manual');
  console.log('```');
  console.log('');
  console.log('This is the ROM/TMS9918 path. Do not use `GO 4000h`, `debug80:editor-image`, or the old RAM editor path.');
  console.log('');
  console.log('Generated ROM artifacts:');
  console.log('- monitor: `build/roms/tec1g/tecm8/monitor/monitor.bin`');
  console.log('- expansion: `build/roms/tec1g/tecm8/expansion/expansion-144k.bin`');
  console.log('');
  console.log('Manual Debug80 route:');
  console.log('1. Open the TECM8 profile in Debug80 after the command above completes.');
  console.log('2. Reset the TEC-1G runtime and let the MON3-compatible monitor start.');
  console.log('3. Enter the monitor `Expansion` menu item.');
  console.log('4. Expect bank 0 to install the expansion vectors, then launch the TecMate shell scaffold.');
  console.log('5. On the TMS9918 VDU, expect `TecMate ROM Shell`, `VDU:TMS TEC-FS:ROM`, `>`, and `POLL`.');
  console.log('');
  console.log('Proof-backed addresses and markers from the last run:');
  console.log(`- launchExpansion: ${hex(proof.launchAddress)}`);
  console.log(`- installed menu vector: ${hex(installed.expectedMenuAddress)}`);
  console.log(`- installed service vector: ${hex(installed.expectedServiceAddress)}`);
  console.log(`- installed trace: ${(installed.trace ?? []).map((value) => hex(value)).join(' ')}`);
  console.log(`- instructions to launch: ${installed.instructions ?? 'unknown'}`);
  console.log(`- bridge instructions: ${installed.bridgeInstructions ?? 'unknown'}`);
  console.log(`- final SYS_CTRL: ${hex(installed.finalSysCtrl)}`);
  console.log(`- final physical bank: ${installed.finalPhysicalBank ?? 'unknown'}`);
  console.log('');
  console.log('Observable success means the fixed monitor, expansion discovery, bank 0 shell scaffold, VDU/TMS9918,');
  console.log('input snapshot service, and TEC-FS service boundary all ran through the ROM path.');
}

main();
