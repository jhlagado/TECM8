const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const doc = readFileSync(resolve(root, 'docs/tecmate-self-hosted-assembler.md'), 'utf8');

function assertMentionsAll(texts: string[]): void {
  for (const text of texts) {
    assert.match(doc, new RegExp(text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  }
}

test('self-hosted assembler doc keeps AZM as reference and TecMate as subset', () => {
  assert.match(doc, /AZM as the reference assembly language/);
  assert.match(doc, /AZM-compatible subset/);
  assert.match(doc, /not a plan to clone all of AZM/);
  assert.match(doc, /TecMate source should not grow a new dialect/);
  assert.match(doc, /explicitly documented as a TecMate-only\s+extension/);
});

test('self-hosted assembler doc defines phase 1 core subset boundaries', () => {
  assert.match(doc, /## Phase 1: Core Subset/);
  assertMentionsAll([
    'Z80 instruction mnemonics and operands',
    'global labels',
    'numeric literals in the forms already common in the project',
    'simple constant expressions',
    '`.equ`',
    '`.org`',
    '`.db`',
    '`.dw`',
    'binary output',
    'symbol table output sufficient for the shell/debugger',
    'clear source-line errors',
  ]);
  assertMentionsAll([
    'register-contract checking',
    '`op`',
    '`.import`',
    'layouts',
    'enums',
    'complex macro systems',
    'full expression language compatibility',
    'generated D8/D8M parity',
    'advanced include/module semantics',
  ]);
});

test('self-hosted assembler doc phases project usability before contracts', () => {
  assert.match(doc, /## Phase 2: Project Usability/);
  assert.match(doc, /## Phase 3: Contract-Aware Assembly/);
  assertMentionsAll([
    'include files',
    'listing output',
    'source location reporting suitable for editor jump-to-error',
    'shell command integration',
    'build products written through TEC-FS',
    'symbols readable by a debugger or monitor tool',
    'a stable command contract for `asm`',
  ]);
  assert.match(doc, /edit source -> asm -> run -> inspect\/debug -> edit source/);
  assert.match(doc, /register contracts are an advanced feature/i);
  assert.match(doc, /parse and preserve contract comments in listings/);
  assert.match(doc, /check known BIOS\/service calls through local interface records/);
  assert.match(doc, /If the checker cannot prove a path,\s+it should say so clearly/);
});

test('self-hosted assembler doc gates MVP work on editor buffer and TEC-FS output', () => {
  assert.match(doc, /## MVP Readiness Gates/);
  assert.match(doc, /should not move beyond the bank-7 skeleton until the smaller\s+file path exists/);
  assert.match(doc, /editor opens 32-byte-record source buffer[\s\S]*assembler reads that buffer or a TEC-FS source stream[\s\S]*assembler emits binary and map records through TEC-FS/);
  assert.match(doc, /shell `asm` reports `OK`, `BUILD`, `FILE`, or `UNSUP`/);
  assert.match(doc, /gated by the editor file-buffer ABI\s+and by TEC-FS source\/binary\/map record writes/);
  assert.match(doc, /bank 7 should\s+remain a compact handoff skeleton/);
  assert.match(doc, /one loaded source buffer or a simple\s+sequential TEC-FS source stream/);
  assert.match(doc, /should not require a general project graph,\s+directory scan, recursive include resolver, host-style build directory, or\s+profile preprocessor/);
  assert.match(doc, /one binary record plus a\s+minimal map record/);
  assert.match(doc, /Listings, include files, register-contract checking, and\s+profile-generated source can wait/);
});

test('self-hosted assembler doc keeps profile-generated source self-hostable', () => {
  assert.match(doc, /## Profile-Generated Source Compatibility/);
  assert.match(doc, /Profile preprocessors must generate source that the TecMate assembler can\s+eventually assemble/);
  assert.match(doc, /generated AZM-subset assembly/);
  assertMentionsAll([
    'ordinary labels',
    'generated labels with stable prefixes',
    '`.equ`',
    '`.db`',
    '`.dw`',
    'simple numeric expressions already accepted by Phase 1',
    'simple include order that Phase 2 can reproduce',
  ]);
  assert.match(doc, /Generated profile output should not require these features/);
  assertMentionsAll([
    '`op`',
    'macros',
    'layouts',
    'enums',
    'complex expressions',
    'host-only path expansion',
    'register-contract checking as a build prerequisite',
    'D8/D8M generation as a build prerequisite',
  ]);
  assert.match(doc, /generated entry file should include user behaviour files rather than\s+inlining them/);
  assert.match(doc, /taken as a profile-tool limitation, not as pressure to make the first\s+self-hosted assembler larger/);
});

test('self-hosted assembler doc defines artifact and TEC-FS metadata convention', () => {
  assert.match(doc, /## Artifact Convention/);
  assertMentionsAll([
    '/src/main.asm',
    '/build/main.bin',
    '/build/main.map',
    'TFS_FILE_SOURCE',
    'TFS_FILE_BINARY',
    'TFS_FILE_ASSET',
    'TFS_FILE_PROJECT',
    'TFS_META_OFFSET_FILE_TYPE',
    'TFS_META_OFFSET_LOAD_ADDR',
    'TFS_META_OFFSET_END_ADDR',
    'TFS_META_OFFSET_RUN_ADDR',
    'TFS_META_FLAG_EXECUTABLE',
    'TFS_META_OFFSET_REQUIRED_HW',
    'TFS_FORMAT_META_RECORD',
    'TFS_PATCH_META_RECORD',
  ]);
  assert.match(doc, /source stem,\s+place outputs under `\/build`, and use `\.bin` and `\.map`/);
  assert.match(doc, /The assembler should not parse `\/tecm8\.prj` independently/);
  assert.match(doc, /The shell owns the\s+project config import path/);
  assert.match(doc, /assembler receives the resolved target\s+descriptor/);
  assert.match(doc, /symbol address source-line/);
  assert.match(doc, /preserve the TEC-specific load\/run metadata/);
});

test('self-hosted assembler doc favors register-first APIs and keeps games as proving case', () => {
  assert.match(doc, /## Register-First Convention/);
  assert.match(doc, /prefer register arguments over stack arguments/);
  assert.match(doc, /It should\s+not become the normal argument-passing mechanism for hot TecMate APIs/);
  assert.match(doc, /Game development should not redefine TecMate/);
  assert.match(doc, /useful proving case\s+for the assembler/);
  assert.match(doc, /;! in IX/);
  assert.match(doc, /;! clobbers A,B,C,D,E,H,L,zero,sign,parity,halfCarry/);
  assert.match(doc, /@Player_Update:/);
  assert.doesNotMatch(doc, /^Player_Update:\n\s+ret/m);
});
