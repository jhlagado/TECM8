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
    shellAsmStatus?: string;
    shellAsmResultStatus?: string;
    shellRunStatus?: string;
    shellRunResultStatus?: string;
    shellUnknownStatus?: string;
    shellUnknownResultStatus?: string;
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
  if (data.installed.shellAsmStatus !== 'ASM') {
    throw new Error(`monitor launch proof output is missing exact shell asm status ASM: ${proofPath}`);
  }
  if (data.installed.shellAsmResultStatus !== 'UNSUP') {
    throw new Error(`monitor launch proof output is missing exact shell asm result status UNSUP: ${proofPath}`);
  }
  if (data.installed.shellRunStatus !== 'RUN') {
    throw new Error(`monitor launch proof output is missing exact shell run status RUN: ${proofPath}`);
  }
  if (data.installed.shellRunResultStatus !== 'UNSUP') {
    throw new Error(`monitor launch proof output is missing exact shell run result status UNSUP: ${proofPath}`);
  }
  if (data.installed.shellUnknownStatus !== 'ERRCMD') {
    throw new Error(`monitor launch proof output is missing exact shell unknown status ERRCMD: ${proofPath}`);
  }
  if (data.installed.shellUnknownResultStatus !== 'NONE') {
    throw new Error(`monitor launch proof output is missing exact shell unknown result status NONE: ${proofPath}`);
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
  console.log('7. The proof runs `asm` through the shell command service, reaches the bank-7 assembler skeleton, and renders `ASM` then `UNSUP`.');
  console.log('8. The proof runs `run` through the shell command service, reaches the bank-8 run skeleton, and renders `RUN` then `UNSUP`.');
  console.log('9. The proof runs `dir` through the shell command service, checks the bank-2 TEC-FS catalogue summary, renders result status `OK`, and proves the bad-buffer path renders `FILE`.');
  console.log('');
  console.log('Proof-backed service inventory:');
  console.log('- fixed monitor: expansion discovery, installed menu vector, installed service vector');
  console.log('- bank 0: shell entry, one-command shell boundary, status/result renderers');
  console.log('- bank 1: VDU/TMS9918 text/status rendering');
  console.log('- bank 2: TEC-FS mount, catalogue summary, catalogue advance, bad-buffer error');
  console.log('- bank 6: input snapshot boundary');
  console.log('- bank 7: assembler skeleton handoff and unsupported result');
  console.log('- bank 8: run skeleton handoff and unsupported result');
  console.log('');
  console.log('Proof-backed shell command matrix:');
  console.log('| Command | Route | Visible status | Visible result | Detail |');
  console.log('| --- | --- | --- | --- | --- |');
  console.log(`| edit | bank 0 shell | ${installed.shellCommandStatus ?? 'unknown'} | n/a | project main target |`);
  console.log(`| asm | bank 7 skeleton | ${installed.shellAsmStatus ?? 'unknown'} | ${installed.shellAsmResultStatus ?? 'unknown'} | project main target |`);
  console.log(`| run | bank 8 skeleton | ${installed.shellRunStatus ?? 'unknown'} | ${installed.shellRunResultStatus ?? 'unknown'} | project output target |`);
  console.log(`| unknown | bank 0 shell | ${installed.shellUnknownStatus ?? 'unknown'} | ${installed.shellUnknownResultStatus ?? 'unknown'} | target/result clear |`);
  console.log(`| dir | bank 2 TEC-FS | DIR | ${installed.shellDirResultStatus ?? 'unknown'} | count ${installed.shellDirResult?.count ?? 'unknown'} |`);
  console.log(`| dir bad-buffer | bank 2 TEC-FS | n/a | ${installed.shellDirErrorResultStatus ?? 'unknown'} | buffer error path |`);
  console.log('');
  console.log('Next manual milestone:');
  console.log('- shell `edit` should hand a project-main target descriptor to TEC-FS lookup, then to an editor file-buffer service.');
  console.log('- visible success is one loaded 32-byte-record source window on the VDU/TMS9918 path, cursor state, dirty flag clear, and return to shell.');
  console.log('- this is not yet save, insert/delete, scrolling, assembler diagnostics, or GLCD rendering.');
  console.log('');
  console.log('Proof-backed addresses and markers from the last run:');
  console.log(`- launchExpansion: ${hex(proof.launchAddress)}`);
  console.log(`- installed menu vector: ${hex(installed.expectedMenuAddress)}`);
  console.log(`- installed service vector: ${hex(installed.expectedServiceAddress)}`);
  console.log(`- installed trace: ${(installed.trace ?? []).map((value) => hex(value)).join(' ')}`);
  console.log(`- instructions to launch: ${installed.instructions ?? 'unknown'}`);
  console.log(`- bridge instructions: ${installed.bridgeInstructions ?? 'unknown'}`);
  console.log(`- shell command status: ${installed.shellCommandStatus}`);
  console.log(`- shell asm status: ${installed.shellAsmStatus}`);
  console.log(`- shell asm result status: ${installed.shellAsmResultStatus}`);
  console.log(`- shell run status: ${installed.shellRunStatus}`);
  console.log(`- shell run result status: ${installed.shellRunResultStatus}`);
  console.log(`- shell unknown status: ${installed.shellUnknownStatus}`);
  console.log(`- shell unknown result status: ${installed.shellUnknownResultStatus}`);
  console.log(`- shell dir result status: ${installed.shellDirResultStatus}`);
  console.log(`- shell dir error result status: ${installed.shellDirErrorResultStatus}`);
  console.log(`- shell dir aggregate count: ${installed.shellDirResult?.count ?? 'unknown'}`);
  console.log(
    `- shell dir last summary: fileId=${hex(installed.shellDirResult?.firstFileId)}, fileType=${hex(installed.shellDirResult?.firstFileType)}, nameLen=${installed.shellDirResult?.firstNameLength ?? 'unknown'}, flags=${hex(installed.shellDirResult?.flags)}`,
  );
  console.log(`- final SYS_CTRL: ${hex(installed.finalSysCtrl)}`);
  console.log(`- final physical bank: ${installed.finalPhysicalBank ?? 'unknown'}`);
  console.log('');
  console.log('Observable success means the fixed monitor, expansion discovery, bank 0 shell scaffold, VDU/TMS9918,');
  console.log('input snapshot service, TEC-FS service boundary, assembler/run skeleton handoffs, shell command status/result paths, and `dir` catalogue summary all ran through the ROM path.');
}

main();
