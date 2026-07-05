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

test('assembler bank proof covers unsupported skeleton service', () => {
  const proof = readFileSync(resolve(root, 'proofs/assembler-bank/assembler-bank-proof.asm'), 'utf8');
  const runner = readFileSync(resolve(root, 'tools/run-assembler-bank-proof.ts'), 'utf8');
  const bank7 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank7.asm'), 'utf8');
  const bank8 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank8.asm'), 'utf8');

  assert.match(proof, /ld a,"a"[\s\S]*ld a,"s"[\s\S]*ld a,"m"[\s\S]*callService SHL_RUN_COMMAND[\s\S]*cp SHL_ACTION_ASM/);
  assert.match(proof, /ld a,0x5A[\s\S]*ld \(ASM_PARAM_STATUS\),a[\s\S]*ld a,0xA5[\s\S]*ld \(ASM_PARAM_LAST_ERROR\),a/);
  assert.match(proof, /ld a,0x7F[\s\S]*farCall ASM_BANK,ASM_ENTRY[\s\S]*jp nc,AssemblerProofFail[\s\S]*cp ASM_ERR_UNKNOWN[\s\S]*ld a,\(ASM_PARAM_STATUS\)[\s\S]*cp 0x5A[\s\S]*ld a,\(ASM_PARAM_LAST_ERROR\)[\s\S]*cp 0xA5/);
  assert.doesNotMatch(proof, /ld \(ASM_PARAM_TARGET_LO\),a/);
  assert.match(proof, /ld a,\(ASM_PARAM_TARGET_LO\)[\s\S]*cp SHL_TARGET_DESC & 0xFF/);
  assert.match(proof, /ld a,\(ASM_PARAM_TARGET_HI\)[\s\S]*cp SHL_TARGET_DESC >> 8/);
  assert.match(proof, /ld a,\(ASM_PARAM_RESULT_LO\)[\s\S]*cp SHL_RESULT_UNSUPPORTED[\s\S]*ld a,\(SHL_PARAM_COMMAND_RESULT_LO\)[\s\S]*cp SHL_RESULT_UNSUPPORTED/);
  assert.match(proof, /ld a,\(ASM_PARAM_RESULT_HI\)[\s\S]*or a[\s\S]*ld a,\(SHL_PARAM_COMMAND_RESULT_HI\)[\s\S]*or a/);
  assert.match(proof, /ld a,"r"[\s\S]*ld a,"u"[\s\S]*ld a,"n"[\s\S]*callService SHL_RUN_COMMAND[\s\S]*cp SHL_ACTION_RUN/);
  assert.match(proof, /ld a,0x5A[\s\S]*ld \(RUN_PARAM_STATUS\),a[\s\S]*ld a,0xA5[\s\S]*ld \(RUN_PARAM_LAST_ERROR\),a/);
  assert.match(proof, /ld a,0x7F[\s\S]*farCall RUN_BANK,RUN_ENTRY[\s\S]*jp nc,AssemblerProofFail[\s\S]*cp RUN_ERR_UNKNOWN[\s\S]*ld a,\(RUN_PARAM_STATUS\)[\s\S]*cp 0x5A[\s\S]*ld a,\(RUN_PARAM_LAST_ERROR\)[\s\S]*cp 0xA5/);
  assert.doesNotMatch(proof, /ld \(RUN_PARAM_TARGET_LO\),a/);
  assert.match(proof, /ld a,\(RUN_PARAM_TARGET_LO\)[\s\S]*cp SHL_TARGET_DESC & 0xFF/);
  assert.match(proof, /ld a,\(RUN_PARAM_TARGET_HI\)[\s\S]*cp SHL_TARGET_DESC >> 8/);
  assert.match(proof, /ld a,\(RUN_PARAM_RESULT_LO\)[\s\S]*cp SHL_RESULT_UNSUPPORTED[\s\S]*ld a,\(SHL_PARAM_COMMAND_RESULT_LO\)[\s\S]*cp SHL_RESULT_UNSUPPORTED/);
  assert.match(proof, /ld a,\(RUN_PARAM_RESULT_HI\)[\s\S]*or a[\s\S]*ld a,\(SHL_PARAM_COMMAND_RESULT_HI\)[\s\S]*or a/);
  assert.match(bank7, /@Tecm8ExpansionBank7Entry:[\s\S]*cp ASM_SVC_ASSEMBLE\s*\n\s*jp z,asmAssembleUnsupported/);
  assert.match(bank8, /@Tecm8ExpansionBank8Entry:[\s\S]*cp RUN_SVC_RUN\s*\n\s*jp z,runUnsupported/);
  assert.match(
    readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank0.asm'), 'utf8'),
    /Tecm8ShellRunAsm:[\s\S]*ld \(ASM_PARAM_TARGET_LO\),hl[\s\S]*callBankService ASM_BANK,ASM_ENTRY,ASM_SVC_ASSEMBLE[\s\S]*call Tecm8ShellPublishAsmResult/,
  );
  assert.match(
    readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank0.asm'), 'utf8'),
    /Tecm8ShellRunRun:[\s\S]*ld \(RUN_PARAM_TARGET_LO\),hl[\s\S]*callBankService RUN_BANK,RUN_ENTRY,RUN_SVC_RUN[\s\S]*call Tecm8ShellPublishRunResult/,
  );
  assert.match(runner, /assembler status preserved after unknown selector/);
  assert.match(runner, /assertEqual\(params\[6\], 0x04, 'assembler shell result low byte'\)/);
  assert.match(runner, /assembler shell target descriptor high byte/);
  assert.match(runner, /run status preserved after unknown selector/);
  assert.match(runner, /assertEqual\(runParams\[6\], 0x04, 'run shell result low byte'\)/);
  assert.match(runner, /run shell target descriptor high byte/);
  assert.match(bank7, /asmAssembleUnsupported:[\s\S]*ld \(ASM_PARAM_BANK\),a[\s\S]*ld \(ASM_PARAM_STATUS\),a[\s\S]*ld \(ASM_PARAM_RESULT_LO\),a[\s\S]*scf[\s\S]*ret/);
  assert.match(bank8, /runUnsupported:[\s\S]*ld \(RUN_PARAM_BANK\),a[\s\S]*ld \(RUN_PARAM_STATUS\),a[\s\S]*ld \(RUN_PARAM_RESULT_LO\),a[\s\S]*scf[\s\S]*ret/);
});
