const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const doc = readFileSync(resolve(root, 'docs/shell-command-contract.md'), 'utf8');
const ops = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank_ops.asmi'), 'utf8');
const proof = readFileSync(resolve(root, 'proofs/bank-abi/bank-abi-proof.asm'), 'utf8');
const bankAbiRunner = readFileSync(resolve(root, 'tools/run-bank-abi-proof.ts'), 'utf8');

test('shell command contract keeps v1 short commands small', () => {
  assert.match(doc, /## Short Commands/);
  assert.match(doc, /edit -> main/);
  assert.match(doc, /asm\s+-> main/);
  assert.match(doc, /run\s+-> derived output/);
  assert.match(doc, /They are not stored in `\/tecm8\.prj`/);
});

test('shell command contract reserves game command namespace without enabling it in bank0 yet', () => {
  assert.match(doc, /## Reserved Tool Namespaces/);
  assert.match(doc, /game build/);
  assert.match(doc, /game run/);
  assert.match(doc, /game debug/);
  assert.match(doc, /placeholders for the later game runtime\/tool profile/);
  assert.match(doc, /should not replace the general `edit`, `asm`, and `run` commands/);
  assert.match(doc, /`SHL_RUN_COMMAND` boundary still classifies only exact\s+single-word `edit`, `asm`, and `run`/);
  assert.match(doc, /It should reject `game` until a real\s+multi-word shell parser and game tool dispatcher are implemented/);
  assert.doesNotMatch(ops, /SHL_ACTION_GAME/);
  assert.match(proof, /ld a,"g"[\s\S]*ld \(SHL_COMMAND_BUFFER\),a[\s\S]*ld a,"a"[\s\S]*ld \(SHL_COMMAND_BUFFER\+1\),a[\s\S]*ld a,"m"[\s\S]*ld \(SHL_COMMAND_BUFFER\+2\),a[\s\S]*ld a,"e"[\s\S]*ld \(SHL_COMMAND_BUFFER\+3\),a/);
  assert.match(bankAbiRunner, /shell command loop rejected unknown command/);
});
