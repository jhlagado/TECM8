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

test('shell command contract defines project metadata import path', () => {
  assert.match(doc, /## Project Metadata Import Path/);
  assert.match(doc, /`\/tecm8\.prj` remains the human-readable project authority/);
  assert.match(doc, /TEC-FS metadata record is the machine-facing summary/);
  assert.match(doc, /Read and validate `\/tecm8\.prj`/);
  assert.match(doc, /Resolve `main` as the project main source path/);
  assert.match(doc, /Call `TFS_FORMAT_META_RECORD` to create a blank `TFM1` record/);
  assert.match(doc, /Call `TFS_PATCH_META_RECORD` with `TFS_FILE_PROJECT`/);
  assert.match(doc, /text config is\s+authoritative, `TFM1` records are the compact ABI/);
});

test('shell command contract reserves assembler result semantics', () => {
  assert.match(doc, /Assembler result reporting uses the shell command parameter block/);
  assert.match(doc, /SHL_PARAM_COMMAND_ACTION\s+= SHL_ACTION_ASM/);
  assert.match(doc, /SHL_PARAM_COMMAND_RESULT_LO = SHL_RESULT_\*/);
  assert.match(doc, /SHL_RESULT_OK\s+assembly completed and wrote \.bin\/\.map outputs/);
  assert.match(doc, /SHL_RESULT_BUILD_ERROR source parsed but did not assemble/);
  assert.match(doc, /SHL_RESULT_FILE_ERROR\s+source, output, map, or project file could not be used/);
  assert.match(doc, /SHL_RESULT_UNSUPPORTED asm was classified but the assembler tool is not linked/);
  assert.match(doc, /`SHL_RUN_COMMAND` classifies `asm`, points the target slot at the minimal\s+`SHL_TARGET_DESC`/);
  assert.match(doc, /marks that descriptor as the project-main default/);
  assert.match(doc, /calls the\s+bank-7 assembler skeleton/);
  assert.match(doc, /publishes the skeleton's\s+`SHL_RESULT_UNSUPPORTED` result/);
});

test('shell command contract reserves run result semantics', () => {
  assert.match(doc, /## `run`/);
  assert.match(doc, /`run` executes the derived project output by default/);
  assert.match(doc, /The shell runs `\/build\/<main-stem>\.bin`, derived from `main`/);
  assert.match(doc, /`SHL_RUN_COMMAND` classifies `run`, points the target slot at the minimal\s+`SHL_TARGET_DESC`/);
  assert.match(doc, /marks that descriptor as the derived project output default/);
  assert.match(doc, /calls the\s+bank-8 run skeleton/);
  assert.match(doc, /publishes the skeleton's\s+`SHL_RESULT_UNSUPPORTED` result/);
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
