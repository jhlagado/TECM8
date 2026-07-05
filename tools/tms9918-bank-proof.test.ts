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
  assert.match(bank1, /cp VDU_SVC_STATUS_LINE\+1/);
  assert.match(bank1, /Tecm8VduServiceTable:[\s\S]*jp\s+vduSetCursorImpl[\s\S]*jp\s+vduPutCharImpl[\s\S]*jp\s+vduPutStringImpl[\s\S]*jp\s+vduNewlineImpl[\s\S]*jp\s+vduSetRowColImpl[\s\S]*jp\s+vduScrollUpImpl[\s\S]*jp\s+vduStatusLineImpl/);
  assert.match(bank1, /cp TMS_SVC_READ_VRAM\+1/);
  assert.match(bank1, /Tecm8TmsServiceTable:[\s\S]*jp\s+tmsInitImpl[\s\S]*jp\s+tmsSetRegisterImpl[\s\S]*jp\s+tmsWriteVramImpl[\s\S]*jp\s+tmsFillVramImpl[\s\S]*jp\s+tmsReadVramImpl/);
  assert.match(bank1, /vduClearImpl:[\s\S]*ld a,VDU_BLANK_CHAR[\s\S]*ld hl,VDU_SCREEN_BYTES[\s\S]*call tmsFillVramImpl/);
  assert.match(bank1, /vduSetCursorImpl:[\s\S]*ld hl,\(TMS_PARAM_ADDR_LO\)[\s\S]*ld \(TMS_PARAM_CURSOR_LO\),hl[\s\S]*ld a,0x81[\s\S]*ret/);
  assert.match(bank1, /vduPutCharImpl:[\s\S]*TMS_PARAM_CURSOR_LO[\s\S]*call tmsWriteVram[\s\S]*inc hl[\s\S]*ld a,0x81[\s\S]*ret/);
  assert.match(bank1, /vduPutStringImpl:[\s\S]*ld hl,\(TMS_PARAM_STRING_LO\)[\s\S]*call vduPutChar[\s\S]*jr vduPutStringNext[\s\S]*ld a,0x81[\s\S]*ret/);
  assert.match(bank1, /vduNewlineImpl:[\s\S]*and 0xE0[\s\S]*ld de,VDU_ROW_BYTES[\s\S]*add hl,de[\s\S]*ld a,0x81[\s\S]*ret/);
  assert.match(bank1, /vduSetRowColImpl:[\s\S]*ld a,\(TMS_PARAM_ROW\)[\s\S]*add hl,hl[\s\S]*ld a,\(TMS_PARAM_COL\)/);
  assert.match(bank1, /vduScrollUpImpl:[\s\S]*ld bc,VDU_SCROLL_BYTES[\s\S]*call tmsReadVramImpl[\s\S]*call tmsWriteVramImpl/);
  assert.match(bank1, /vduStatusLineImpl:[\s\S]*push hl[\s\S]*ld hl,VDU_LAST_ROW_ADDR[\s\S]*call tmsFillVramImpl[\s\S]*call vduPutStringImpl[\s\S]*pop hl[\s\S]*ld \(TMS_PARAM_CURSOR_LO\),hl/);
  assert.match(bank1, /tmsFillVramImpl:[\s\S]*ld hl,\(TMS_PARAM_COUNT_LO\)[\s\S]*out \(TMS_DATA_PORT\),a[\s\S]*dec hl/);
  assert.match(bank1, /tmsReadVramImpl:[\s\S]*in a,\(TMS_DATA_PORT\)[\s\S]*ld \(TMS_PARAM_VALUE\),a/);
  assert.match(proof, /callBankService 0x01,VDU_CALL,VDU_SVC_CLEAR/);
  assert.match(proof, /callBankService 0x01,VDU_CALL,VDU_SVC_SET_CURSOR/);
  assert.match(proof, /callBankService 0x01,VDU_CALL,VDU_SVC_PUT_CHAR/);
  assert.match(proof, /callBankService 0x01,VDU_CALL,VDU_SVC_PUT_STRING/);
  assert.match(proof, /callBankService 0x01,VDU_CALL,VDU_SVC_NEWLINE/);
  assert.match(proof, /callBankService 0x01,VDU_CALL,VDU_SVC_SET_ROWCOL/);
  assert.match(proof, /callBankService 0x01,VDU_CALL,VDU_SVC_SCROLL_UP/);
  assert.match(proof, /callBankService 0x01,VDU_CALL,VDU_SVC_STATUS_LINE/);
  assert.match(proof, /callBankService 0x01,VDU_CALL,0x00[\s\S]*ld \(TMS_PROOF_TRACE_16\),a[\s\S]*adc a,0[\s\S]*ld \(TMS_PROOF_TRACE_17\),a/);
  assert.match(proof, /callBankService 0x01,VDU_CALL,0x0A[\s\S]*ld \(TMS_PROOF_TRACE_18\),a[\s\S]*adc a,0[\s\S]*ld \(TMS_PROOF_TRACE_19\),a/);
  assert.match(proof, /callBankService 0x01,VDU_CALL,0x7F[\s\S]*ld \(TMS_PROOF_TRACE_20\),a[\s\S]*adc a,0[\s\S]*ld \(TMS_PROOF_TRACE_21\),a/);
  assert.match(runner, /VDU put string return value/);
  assert.match(runner, /VDU newline return value/);
  assert.match(runner, /VDU low unknown selector carry marker/);
  assert.match(runner, /VDU gap unknown selector carry marker/);
  assert.match(runner, /VDU high unknown selector carry marker/);
  assert.match(runner, /VDU cursor low preserved after unknown selectors/);
  assert.match(runner, /VDU cursor high preserved after unknown selectors/);
  assert.match(runner, /VDU clear return value/);
  assert.match(runner, /VDU scroll-up return value/);
  assert.match(runner, /VDU status-line return value/);
  assert.match(runner, /VDU status-line restored cursor low byte/);
  assert.match(runner, /VDU row\/column cursor low byte/);
  assert.match(runner, /VDU scroll copied row 1 to row 0/);
  assert.match(runner, /VDU status-line first character write/);
  assert.match(runner, /VDU cursor low after newline/);
  assert.match(runner, /VDU string second character write/);
  assert.match(runner, /TMS VRAM write/);
});
