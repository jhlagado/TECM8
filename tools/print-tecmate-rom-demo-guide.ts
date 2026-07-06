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
    shellCommandStatus?: string;
    shellDirResultStatus?: string;
    shellDirErrorResultStatus?: string;
    shellDirResult?: {
      resultLo?: number;
      count?: number;
      firstFileId?: number;
      firstFileType?: number;
      firstNameLength?: number;
      flags?: number;
    };
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
  if (data.installed.shellCommandStatus !== 'EDIT') {
    throw new Error(`monitor launch proof output is missing exact shell command status EDIT: ${proofPath}`);
  }
  if (data.installed.shellDirResult?.resultLo !== 0x01 || data.installed.shellDirResult.count !== 0x02) {
    throw new Error(`monitor launch proof output is missing exact shell dir TEC-FS result: ${proofPath}`);
  }
  if (data.installed.shellDirResultStatus !== 'OK') {
    throw new Error(`monitor launch proof output is missing exact shell dir result status OK: ${proofPath}`);
  }
  if (data.installed.shellDirErrorResultStatus !== 'FILE') {
    throw new Error(`monitor launch proof output is missing exact shell dir error result status FILE: ${proofPath}`);
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
  console.log('5. On the TMS9918 VDU, expect `TecMate ROM Shell`, `TFS:30+1 128M 4K`, `KEY:0000 JOY:00`, `>`, and `POLL`.');
  console.log('6. The proof also runs `edit` through the shell command service and renders status `EDIT` on the VDU status line.');
  console.log('7. The proof runs `dir` through the shell command service, checks the bank-2 TEC-FS catalogue summary, renders result status `OK`, and proves the bad-buffer path renders `FILE`.');
  console.log('');
  console.log('Proof-backed addresses and markers from the last run:');
  console.log(`- launchExpansion: ${hex(proof.launchAddress)}`);
  console.log(`- installed menu vector: ${hex(installed.expectedMenuAddress)}`);
  console.log(`- installed service vector: ${hex(installed.expectedServiceAddress)}`);
  console.log(`- installed trace: ${(installed.trace ?? []).map((value) => hex(value)).join(' ')}`);
  console.log(`- instructions to launch: ${installed.instructions ?? 'unknown'}`);
  console.log(`- bridge instructions: ${installed.bridgeInstructions ?? 'unknown'}`);
  console.log(`- shell command status: ${installed.shellCommandStatus}`);
  console.log(`- shell dir result status: ${installed.shellDirResultStatus}`);
  console.log(`- shell dir error result status: ${installed.shellDirErrorResultStatus}`);
  console.log(
    `- shell dir result: result=${hex(installed.shellDirResult?.resultLo)}, count=${installed.shellDirResult?.count ?? 'unknown'}, lastSummaryFileId=${hex(installed.shellDirResult?.firstFileId)}, lastSummaryFileType=${hex(installed.shellDirResult?.firstFileType)}, nameLen=${installed.shellDirResult?.firstNameLength ?? 'unknown'}, flags=${hex(installed.shellDirResult?.flags)}`,
  );
  console.log(`- final SYS_CTRL: ${hex(installed.finalSysCtrl)}`);
  console.log(`- final physical bank: ${installed.finalPhysicalBank ?? 'unknown'}`);
  console.log('');
  console.log('Observable success means the fixed monitor, expansion discovery, bank 0 shell scaffold, VDU/TMS9918,');
  console.log('input snapshot service, TEC-FS service boundary, shell command status/result paths, and `dir` catalogue summary all ran through the ROM path.');
}

main();
