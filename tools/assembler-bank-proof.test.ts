const { existsSync, readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');

test('assembler bank proof artifacts are wired into the repository', () => {
  assert.equal(existsSync(resolve(root, 'proofs/assembler-bank/assembler-bank-proof.asm')), true);
  assert.equal(existsSync(resolve(root, 'tools/run-assembler-bank-proof.ts')), true);
});

test('package check runs the assembler bank proof', () => {
  const pkg = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8'));
  assert.equal(pkg.scripts['proof:assembler-bank'], 'node --experimental-strip-types tools/run-assembler-bank-proof.ts');
  assert.match(pkg.scripts.check, /npm run proof:assembler-bank/);
});

test('assembler bank proof covers diagnose, fix, build, persist, run, and return', () => {
  const proof = readFileSync(resolve(root, 'proofs/assembler-bank/assembler-bank-proof.asm'), 'utf8');
  const runner = readFileSync(resolve(root, 'tools/run-assembler-bank-proof.ts'), 'utf8');
  const bank7 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank7.asm'), 'utf8');
  const bank8 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank8.asm'), 'utf8');

  assert.match(proof, /ld hl,SourceFixture[\s\S]*ld de,EDT_BUFFER_BASE[\s\S]*ldir/);
  assert.match(proof, /call PrepareAsmCommand[\s\S]*callService SHL_RUN_COMMAND[\s\S]*cp SHL_RESULT_BUILD_ERROR/);
  assert.match(proof, /ld a,\(ASM_PARAM_DIAG_LINE\)[\s\S]*cp 0x23[\s\S]*ld a,\(ASM_PARAM_DIAG_FILE\)[\s\S]*ld a,\(ASM_PARAM_DIAG_CODE\)[\s\S]*cp ASM_ERR_SYNTAX/);
  assert.match(proof, /ld a,"T"[\s\S]*ld \(EDT_BUFFER_BASE\+\(EDT_RECORD_BYTES\*35\)\+3\),a/);
  assert.match(proof, /call PrepareAsmCommand[\s\S]*callService SHL_RUN_COMMAND[\s\S]*cp SHL_RESULT_OK/);
  assert.match(proof, /BASE \.EQU 0x4F00\+0xF0/);
  assert.match(proof, /VALUE: \.EQU 0x50\+10/);
  assert.match(proof, /PUSH BC[\s\S]*DJNZ LOOP[\s\S]*CALL M,STORE/);
  assert.match(proof, /ld a,\(ASM_OUTPUT_BASE\+0\)[\s\S]*cp 0xF3[\s\S]*ld a,\(ASM_OUTPUT_BASE\+62\)[\s\S]*cp 0xD8/);
  assert.match(proof, /ld a,\(ASM_MAP_BASE\+0\)[\s\S]*cp "T"[\s\S]*ld a,\(ASM_MAP_BASE\+3\)[\s\S]*cp "P"/);
  assert.match(proof, /ASM_MAP_BASE\+91[\s\S]*cp 0x11[\s\S]*\.INCLUDE [\s\S]*lib\.asm/);
  assert.match(proof, /ld a,\(TFS_BRIDGE_ARTIFACT_DATA_WRITES\)[\s\S]*cp 0x02[\s\S]*ld a,\(TFS_BRIDGE_ARTIFACT_META_WRITES\)[\s\S]*cp 0x02/);
  assert.match(proof, /call PrepareRunCommand[\s\S]*callService SHL_RUN_COMMAND[\s\S]*cp SHL_RESULT_OK/);
  assert.match(proof, /ld a,\(PROGRAM_MARKER\)[\s\S]*cp 0x5A[\s\S]*ld a,\(RUN_PARAM_RETURN_COUNT\)[\s\S]*cp 0x01/);
  assert.match(bank7, /Tecm8ExpansionBank7Entry:[\s\S]*cp ASM_SVC_ASSEMBLE\s*\n\s*jp z,asmAssemble/);
  assert.match(bank8, /Tecm8ExpansionBank8Entry:[\s\S]*cp RUN_SVC_RUN\s*\n\s*jp z,runArtifact/);
  assert.match(
    readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank0.asm'), 'utf8'),
    /Tecm8ShellRunAsm:[\s\S]*ld \(ASM_PARAM_TARGET_LO\),hl[\s\S]*callBankService ASM_BANK,ASM_ENTRY,ASM_SVC_ASSEMBLE[\s\S]*call Tecm8ShellPublishAsmResult/,
  );
  assert.match(
    readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank0.asm'), 'utf8'),
    /Tecm8ShellRunRun:[\s\S]*ld \(RUN_PARAM_TARGET_LO\),hl[\s\S]*callBankService RUN_BANK,RUN_ENTRY,RUN_SVC_RUN[\s\S]*call Tecm8ShellPublishRunResult/,
  );
  assert.match(runner, /assertEqual\(params\[6\], 0x01, 'assembler shell result low byte'\)/);
  assert.match(runner, /assembler shell target descriptor high byte/);
  assert.match(runner, /assertEqual\(runParams\[6\], 0x01, 'run shell result low byte'\)/);
  assert.match(runner, /run shell target descriptor high byte/);
  assert.match(bank7, /asmSaveArtifacts:[\s\S]*TFS_ARTIFACT_KIND_BINARY[\s\S]*TFS_ARTIFACT_KIND_MAP/);
  assert.match(bank8, /ld hl,RUN_TRAMPOLINE_BASE[\s\S]*ld \(hl\),0xCD[\s\S]*call RUN_TRAMPOLINE_BASE/);
});
