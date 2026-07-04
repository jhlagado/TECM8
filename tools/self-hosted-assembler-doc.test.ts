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
