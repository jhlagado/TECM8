const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');

test('banked service architecture defines the monitor RST 10h dispatch plan', () => {
  const doc = readFileSync(resolve(root, 'docs/mon3/tecmate-banked-service-architecture.md'), 'utf8');

  assert.match(doc, /^## Monitor RST 10h Dispatch Plan/m);
  assert.match(doc, /RST 10h C=50h-54h\s+fixed monitor bank-control services/);
  assert.match(doc, /RST 10h C=60h\s+generic TecMate monitor-to-expansion bridge/);
  assert.match(doc, /RST 10h C=61h-6Fh\s+reserved TecMate bridge\/service range/);
  assert.match(doc, /bank 0 installed vector -> private service dispatcher/);
  assert.match(doc, /`C=60h` selects the\s+monitor bridge itself; `A` carries the TecMate service ID/);
  assert.match(doc, /constructs the same per-call stack-word request used by the current\s+`callService` helper/);
  assert.match(doc, /validates the installed expansion service vector/);
  assert.match(doc, /enters\s+that bank\/address through the fixed `BiosBankCall` path/);
  assert.match(doc, /keeps physical bank selection out\s+of ordinary callers/i);
  assert.match(doc, /preserving the fixed ROM as the only code that\s+changes `SYS_CTRL`/i);
  assert.match(doc, /`A` is the dispatch service ID and is not an\s+argument to the target service/);
  assert.match(doc, /target service arguments should use the remaining documented registers or\s+parameter blocks/);
  assert.match(doc, /unsupported service IDs return a carry-set error/);
  assert.match(doc, /GLCD should stay\s+as a containment boundary unless it blocks fixed-ROM space/);
  assert.match(doc, /first bridge users should be TecMate shell launch,\s+VDU\/TMS9918 text services, and TEC-FS mount\/volume\/sector services/);
});
