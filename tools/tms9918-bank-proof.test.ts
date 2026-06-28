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

  assert.match(bank1, /@vduSetCursor:[\s\S]*ld hl,\(TECM8_TMS_PARAM_ADDR_LO\)[\s\S]*ld \(TECM8_TMS_PARAM_CURSOR_LO\),hl[\s\S]*ld a,0x81[\s\S]*ret/);
  assert.match(bank1, /@vduPutChar:[\s\S]*TECM8_TMS_PARAM_CURSOR_LO[\s\S]*call tmsWriteVram[\s\S]*inc hl[\s\S]*ld a,0x81[\s\S]*ret/);
  assert.match(bank1, /@vduPutString:[\s\S]*ld hl,\(TECM8_TMS_PARAM_STRING_LO\)[\s\S]*call vduPutChar[\s\S]*jr vduPutStringNext[\s\S]*ld a,0x81[\s\S]*ret/);
  assert.match(proof, /farCall 0x01,TECM8_VDU_SET_CURSOR/);
  assert.match(proof, /farCall 0x01,TECM8_VDU_PUT_CHAR/);
  assert.match(proof, /farCall 0x01,TECM8_VDU_PUT_STRING/);
  assert.match(runner, /VDU cursor low after put string/);
  assert.match(runner, /VDU put string return value/);
  assert.match(runner, /VDU string second character write/);
  assert.match(runner, /TMS VRAM write/);
});
