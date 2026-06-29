const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');

test('banked service architecture defines the monitor RST 10h dispatch plan', () => {
  const doc = readFileSync(resolve(root, 'docs/mon3/tecmate-banked-service-architecture.md'), 'utf8');

  assert.match(doc, /^## Monitor RST 10h Dispatch Plan/m);
  assert.match(doc, /RST 10h C=50h-54h\s+fixed monitor bank-control services/);
  assert.match(doc, /RST 10h C=60h-7Fh\s+expansion service selectors/);
  assert.match(doc, /RST 10h C=80h-FFh\s+expansion application\/tool selectors/);
  assert.match(doc, /bank 0 installed vector -> private service dispatcher/);
  assert.match(doc, /`C >= 60h`\s+selects the installed expansion service vector directly; `C` is the TecMate\s+service ID/);
  assert.match(doc, /validates the installed expansion service\s+vector/);
  assert.match(doc, /enters\s+that bank\/address through the fixed `BiosBankCall` path/);
  assert.match(doc, /keeps physical\s+bank selection out of ordinary callers/i);
  assert.match(doc, /preserving the fixed ROM as\s+the only code that changes `SYS_CTRL`/i);
  assert.match(doc, /`C` is the dispatch service ID/);
  assert.match(doc, /target service arguments may use documented registers or\s+parameter blocks/);
  assert.match(doc, /unsupported service IDs return a carry-set error/);
  assert.match(doc, /GLCD should stay\s+as a containment boundary unless it blocks fixed-ROM space/);
  assert.match(doc, /first bridge users should be TecMate shell launch,\s+VDU\/TMS9918 text services, and TEC-FS mount\/volume\/sector services/);
});
