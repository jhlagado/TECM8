const { existsSync, readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');

test('TMS9918 bank proof artifacts are wired into the repository', () => {
  assert.equal(existsSync(resolve(root, 'proofs/tms9918-bank/tms9918-bank-proof.asm')), true);
  assert.equal(existsSync(resolve(root, 'tools/run-tms9918-bank-proof.ts')), true);
});

test('TMS9918 bank proof covers VDU cursor and put-char behavior', () => {
  const bank1 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank1.asm'), 'utf8');
  const proof = readFileSync(resolve(root, 'proofs/tms9918-bank/tms9918-bank-proof.asm'), 'utf8');
  const runner = readFileSync(resolve(root, 'tools/run-tms9918-bank-proof.ts'), 'utf8');

  assert.match(bank1, /@vduServiceCall:/);
  assert.match(bank1, /Tecm8VduServiceTable:/);
  assert.match(bank1, /cp VDU_SVC_NEWLINE\+1/);
  assert.match(bank1, /Tecm8VduServiceTable:[\s\S]*jp\s+vduSetCursorImpl[\s\S]*jp\s+vduPutCharImpl[\s\S]*jp\s+vduPutStringImpl[\s\S]*jp\s+vduNewlineImpl/);
  assert.match(bank1, /Tecm8TmsServiceTable:[\s\S]*jp\s+tmsInitImpl[\s\S]*jp\s+tmsSetRegisterImpl[\s\S]*jp\s+tmsWriteVramImpl/);
  assert.match(bank1, /vduSetCursorImpl:[\s\S]*ld hl,\(TMS_PARAM_ADDR_LO\)[\s\S]*ld \(TMS_PARAM_CURSOR_LO\),hl[\s\S]*ld a,0x81[\s\S]*ret/);
  assert.match(bank1, /vduPutCharImpl:[\s\S]*TMS_PARAM_CURSOR_LO[\s\S]*call tmsWriteVram[\s\S]*inc hl[\s\S]*ld a,0x81[\s\S]*ret/);
  assert.match(bank1, /vduPutStringImpl:[\s\S]*ld hl,\(TMS_PARAM_STRING_LO\)[\s\S]*call vduPutChar[\s\S]*jr vduPutStringNext[\s\S]*ld a,0x81[\s\S]*ret/);
  assert.match(bank1, /vduNewlineImpl:[\s\S]*and 0xE0[\s\S]*ld de,VDU_ROW_BYTES[\s\S]*add hl,de[\s\S]*ld a,0x81[\s\S]*ret/);
  assert.match(proof, /callBankService 0x01,VDU_CALL,VDU_SVC_SET_CURSOR/);
  assert.match(proof, /callBankService 0x01,VDU_CALL,VDU_SVC_PUT_CHAR/);
  assert.match(proof, /callBankService 0x01,VDU_CALL,VDU_SVC_PUT_STRING/);
  assert.match(proof, /callBankService 0x01,VDU_CALL,VDU_SVC_NEWLINE/);
  assert.match(runner, /VDU put string return value/);
  assert.match(runner, /VDU newline return value/);
  assert.match(runner, /VDU cursor low after newline/);
  assert.match(runner, /VDU string second character write/);
  assert.match(runner, /TMS VRAM write/);
});
