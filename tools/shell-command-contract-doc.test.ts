const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const doc = readFileSync(resolve(root, 'docs/shell-command-contract.md'), 'utf8');
const ops = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank_ops.asmi'), 'utf8');
const bank0 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank0.asm'), 'utf8');
const proof = readFileSync(resolve(root, 'proofs/bank-abi/bank-abi-proof.asm'), 'utf8');
const bankAbiRunner = readFileSync(resolve(root, 'tools/run-bank-abi-proof.ts'), 'utf8');

test('shell command contract keeps v1 short commands small', () => {
  assert.match(doc, /## Short Commands/);
  assert.match(doc, /edit -> main/);
  assert.match(doc, /asm\s+-> main/);
  assert.match(doc, /run\s+-> derived output/);
  assert.match(doc, /dir\s+-> current volume catalogue summary/);
  assert.match(doc, /They are not stored in `\/tecm8\.prj`/);
  assert.match(doc, /A blank command line is a successful no-op/);
  assert.match(doc, /return to the prompt without reporting an unknown\s+command/);
  assert.match(doc, /`dir` defaults to `\/src`; `dir \/prefix`\s+selects another bounded\s+prefix/);
  assert.match(doc, /scans the real TM8 prefix and catalogue\s+sectors/);
  assert.match(doc, /hides leading-dot backup names/);
  assert.match(doc, /RAM proof bridge preserves\s+the earlier two-adjacent-slot summary behavior/);
});

test('shell command contract pins the proved ROM checkpoint matrix', () => {
  assert.match(doc, /## Proved ROM Checkpoint Matrix/);
  assert.match(doc, /`npm run checkpoint:tecmate-rom` currently proves this compact command surface/);
  assert.match(doc, /\| `edit` \| banks 0\/4\/6\/2\/5\/1 \| `EDIT` \| `OK` \| Runs the interactive multi-page editor, explicit save\/discard flow, and returns safely to the shell\. \|/);
  assert.match(doc, /\| `asm` \| banks 7\/2\/5 \| `ASM` \| `BUILD`, then `OK` \| Reports a source-record diagnostic, then emits binary\/map data and metadata after the proof fixes the source\. \|/);
  assert.match(doc, /\| `run` \| banks 8\/2\/5 \| `RUN` \| `FILE`, then `OK` \| Rejects a missing artifact, then validates, loads, executes, and returns after the successful build\. \|/);
  assert.match(doc, /\| `dir` \| banks 0\/2\/5\/1 \| `DIR` \| `OK` \| Walks `\/src` on the real SD image, hides a dot backup, returns two names, and renders them on TMS9918 rows\. \|/);
  assert.match(doc, /\| unknown \| bank 0 shell \| `ERRCMD` \| `NONE` \| Rejects the command and keeps target\/result fields clear\. \|/);
  assert.match(doc, /\| `dir` bad buffer \| bank 2 TEC-FS \| n\/a \| `FILE` \| Bad catalogue buffer pointer is reported as a file\/storage error\. \|/);
  assert.match(doc, /This matrix is the MVP shell contract with the persistent bounded editor and\s+TEC-FS source read\/write path present/);
  assert.match(doc, /New commands should not be added just to improve the demo/);
  assert.match(doc, /keep the bank-0 parser\s+small/);
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

test('shell command contract keeps bank 0 as a compact classifier', () => {
  assert.match(doc, /## Bank 0 Parser Boundary/);
  assert.match(doc, /compact shell classifier and service dispatcher/);
  assert.match(doc, /must not become the path parser, project-file parser, catalogue\s+scanner, or filename resolver/);
  assert.match(doc, /edit -> project-main target descriptor/);
  assert.match(doc, /asm\s+-> project-main target descriptor, then bank 7/);
  assert.match(doc, /run\s+-> project-output target descriptor, then bank 8/);
  assert.match(doc, /dir \[absolute-prefix\] -> bank 2 bounded catalogue-list service/);
  assert.match(doc, /Bank 0 only recognises the optional argument shape and copies its bounded bytes/);
  assert.match(doc, /bank 2 owns prefix\/path validation and catalogue scanning/);
  assert.match(doc, /should move\s+behind a banked service instead of expanding the bank-0 parser/);

  assert.match(bank0, /cp 0x03[\s\S]*jp z,Tecm8ShellRunCheckThree/);
  assert.match(bank0, /cp 0x04[\s\S]*jp z,Tecm8ShellRunCheckFour/);
  assert.match(bank0, /callBankService ASM_BANK,ASM_ENTRY,ASM_SVC_ASSEMBLE/);
  assert.match(bank0, /callBankService RUN_BANK,RUN_ENTRY,RUN_SVC_RUN/);
  assert.match(bank0, /callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_SUMMARIZE_CATALOG/);
  assert.match(bank0, /callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_NEXT_CATALOG/);
  assert.match(bank0, /callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_LIST_PATH/);
  assert.doesNotMatch(bank0, /tecm8\.prj|\.asm\b|\.bin\b|\/src|\/build|PATH_SEPARATOR|CATALOG_SCAN/i);
  assert.doesNotMatch(bank0, /TFS_SVC_READ|TFS_SVC_WRITE|TFS_SVC_FORMAT_META_RECORD|TFS_SVC_PATCH_META_RECORD/);
});

test('shell command contract reserves assembler result semantics', () => {
  assert.match(doc, /Assembler result reporting uses the shell command parameter block/);
  assert.match(doc, /SHL_PARAM_COMMAND_ACTION\s+= SHL_ACTION_ASM/);
  assert.match(doc, /SHL_PARAM_COMMAND_RESULT_LO = SHL_RESULT_\*/);
  assert.match(doc, /SHL_RESULT_OK\s+assembly completed and wrote \.bin\/\.map outputs/);
  assert.match(doc, /SHL_RESULT_BUILD_ERROR source parsed but did not assemble/);
  assert.match(doc, /SHL_RESULT_FILE_ERROR\s+source, output, map, or project file could not be used/);
  assert.match(doc, /SHL_RESULT_UNSUPPORTED a recognized tool slot has no implementation/);
  assert.match(doc, /`SHL_RENDER_RESULT` turns the low result byte into a short VDU status label/);
  assert.match(doc, /not a diagnostic formatter/);
  assert.match(doc, /`SHL_RUN_COMMAND` classifies `asm`, points the target slot at the minimal\s+`SHL_TARGET_DESC`/);
  assert.match(doc, /marks that descriptor as the project-main default/);
  assert.match(doc, /calls\s+the bank-7 two-pass assembler/);
  assert.match(doc, /publishes `BUILD` with a zero-based source record/);
  assert.match(doc, /writing binary and `TMAP` data\/metadata through bank 2/);
});

test('shell command contract reserves run result semantics', () => {
  assert.match(doc, /## `run`/);
  assert.match(doc, /`run` executes the derived project output by default/);
  assert.match(doc, /The shell runs `\/build\/<main-stem>\.bin`, derived from `main`/);
  assert.match(doc, /`SHL_RUN_COMMAND` classifies `run`, points the target slot at the minimal\s+`SHL_TARGET_DESC`/);
  assert.match(doc, /marks that descriptor as the derived project output default/);
  assert.match(doc, /calls bank 8/);
  assert.match(doc, /requires the artifact and entry point to stay inside `4000h-4FFFh`/);
  assert.match(doc, /phase-one program returns with `RET`/);
  assert.match(doc, /Missing or invalid\s+artifacts publish `FILE`/);
});

test('shell command contract reserves game command namespace without enabling it in bank0 yet', () => {
  assert.match(doc, /## Reserved Tool Namespaces/);
  assert.match(doc, /game build/);
  assert.match(doc, /game run/);
  assert.match(doc, /game debug/);
  assert.match(doc, /profile build/);
  assert.match(doc, /profile run/);
  assert.match(doc, /profile info/);
  assert.match(doc, /profile clean/);
  assert.match(doc, /placeholders for the later game runtime\/tool profile/);
  assert.match(doc, /should not replace the general `edit`, `asm`, and `run` commands/);
  assert.match(doc, /recognises `edit`, `asm`, `run`,\s+`dir`, `list`, `sym`, `debug`, `break SYMBOL`, `step`, and `cont`/);
  assert.match(doc, /rejects `game` and `profile`[\s\S]*multi-word shell parser and tool dispatcher/);
  assert.doesNotMatch(ops, /SHL_ACTION_GAME/);
  assert.doesNotMatch(ops, /SHL_ACTION_PROFILE/);
  assert.match(proof, /ld hl,ProfileCommand[\s\S]*ld de,SHL_COMMAND_BUFFER[\s\S]*ld bc,8[\s\S]*ldir/);
  assert.match(proof, /ProfileCommand:\s*\.db\s+"profile",0/);
  assert.match(proof, /ld hl,GameCommand[\s\S]*ld de,SHL_COMMAND_BUFFER[\s\S]*ld bc,5[\s\S]*ldir/);
  assert.match(proof, /GameCommand:\s*\.db\s+"game",0/);
  assert.match(bankAbiRunner, /shell command loop rejected profile namespace/);
  assert.match(bankAbiRunner, /shell command loop rejected game namespace/);
});

test('shell command contract defines future profile command surface', () => {
  assert.match(doc, /## Future Profile Command Surface/);
  assert.match(doc, /Profile commands should layer on the ordinary shell workflow/);
  assert.match(doc, /profile info/);
  assert.match(doc, /profile build/);
  assert.match(doc, /profile run/);
  assert.match(doc, /profile clean/);
  assert.match(doc, /`profile` is the generic namespace/);
  assert.match(doc, /`game` is an alias or specialised namespace/);
  assert.match(doc, /must remain disabled in the v1 one-word\s+command classifier/);
  assert.match(doc, /`profile build`: run the profile preprocessor, assemble generated source/);
  assert.match(doc, /`profile run`: validate the package and launch through the same runner path\s+as ordinary `run`/);
  assert.match(doc, /The shell should not parse profile source itself/);
});
