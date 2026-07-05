const { existsSync, readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');

test('RTC bank proof artifacts are wired into the repository', () => {
  assert.equal(existsSync(resolve(root, 'proofs/rtc-bank/rtc-bank-proof.asm')), true);
  assert.equal(existsSync(resolve(root, 'tools/run-rtc-bank-proof.ts')), true);
});

test('package check runs the RTC bank proof', () => {
  const pkg = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8'));
  assert.equal(pkg.scripts['proof:rtc-bank'], 'node --experimental-strip-types tools/run-rtc-bank-proof.ts');
  assert.match(pkg.scripts.check, /npm run proof:rtc-bank/);
});

test('RTC bank proof covers unsupported UI and unknown selectors', () => {
  const proof = readFileSync(resolve(root, 'proofs/rtc-bank/rtc-bank-proof.asm'), 'utf8');
  const runner = readFileSync(resolve(root, 'tools/run-rtc-bank-proof.ts'), 'utf8');
  const bank3 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank3.asm'), 'utf8');
  const bankOps = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank_ops.asmi'), 'utf8');
  const doc = readFileSync(resolve(root, 'docs/mon3/tecmate-banked-service-abi.md'), 'utf8');

  assert.match(proof, /ld a,RTC_SVC_SETUP_UI[\s\S]*farCall 0x03,RTC_ENTRY[\s\S]*cp RTC_ERR_UNSUPPORTED/);
  assert.match(proof, /xor a\s+farCall 0x03,RTC_ENTRY[\s\S]*cp 0x83/);
  assert.match(proof, /ld a,RTC_SVC_PRAM_VIEWER[\s\S]*farCall 0x03,RTC_ENTRY[\s\S]*cp RTC_ERR_UNSUPPORTED/);
  assert.match(proof, /ld a,0x5A[\s\S]*ld \(RTC_PARAM_STATUS\),a[\s\S]*ld a,0xA5[\s\S]*ld \(RTC_PARAM_LAST_ERROR\),a/);
  assert.match(proof, /ld a,0x7F[\s\S]*farCall 0x03,RTC_ENTRY[\s\S]*cp RTC_ERR_UNKNOWN[\s\S]*ld a,\(RTC_PARAM_STATUS\)[\s\S]*cp 0x5A[\s\S]*ld a,\(RTC_PARAM_LAST_ERROR\)[\s\S]*cp 0xA5/);
  assert.match(runner, /RTC status preserved after unknown selector/);
  assert.match(runner, /RTC last error preserved after unknown selector/);
  assert.match(bank3, /or a\s+jp z,rtcServiceEntryImpl\s+cp RTC_SVC_TOOL_ENTRY\s+jp z,rtcServiceEntryImpl/);
  assert.match(bank3, /ld a,RTC_ERR_UNKNOWN\s+scf\s+ret/);
  assert.match(bankOps, /^RTC_ERR_UNKNOWN\s+\.equ\s+0xEE/m);
  assert.match(doc, /Unknown RTC selectors return `RTC_ERR_UNKNOWN`/);
});
