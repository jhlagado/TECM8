const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const gamerDoc = readFileSync(resolve(root, 'docs/gamer.md'), 'utf8');
const sliceDoc = readFileSync(resolve(root, 'docs/gamer-vertical-slice.md'), 'utf8');

test('gamer mission frames profiles as preprocessors over ordinary assembly', () => {
  assert.match(gamerDoc, /## Profile Preprocessor And Generated Assembly/);
  assert.match(gamerDoc, /profile preprocessor above ordinary AZM\/Z80/);
  assert.match(gamerDoc, /general-purpose assembler must remain able to\s+write monitors, ROMs, utilities, tools, demos/);
  assert.match(gamerDoc, /generated equates, tables, labels, includes, and resource blobs/);
  assert.match(gamerDoc, /concatenated ordinary AZM\/Z80 source/);
  assert.match(gamerDoc, /generated assembly inspectable/);
  assert.match(gamerDoc, /should not begin as a general scripting language/);
});

test('gamer mission keeps the shared runtime loop-based rather than desktop-event based', () => {
  assert.match(gamerDoc, /## Loop-Driven Programming Model/);
  assert.match(gamerDoc, /cooperative polling loop/);
  assert.match(gamerDoc, /poll input and timers[\s\S]*check dirty flags[\s\S]*run short routine slots[\s\S]*redraw dirty regions/);
  assert.match(gamerDoc, /## State And Routine-Slot Direction/);
  assert.match(gamerDoc, /stops short of an object-oriented or event-driven framework/);
  assert.match(gamerDoc, /state, dirty flags, and small behaviour\s+routines/);
  assert.match(gamerDoc, /An actor instance is a live state record/);
  assert.match(sliceDoc, /polling-loop,\s+state-record, and routine-slot runtime/);
  assert.match(sliceDoc, /screen\/card\/routine-slot\s+profile/);
  assert.match(sliceDoc, /state-record routine slots/);
  assert.doesNotMatch(sliceDoc, /screen\/object\/event profile/);
  assert.doesNotMatch(sliceDoc, /object event hooks/);
  assert.doesNotMatch(gamerDoc, /An actor instance is a live object/);
  assert.doesNotMatch(gamerDoc, /- event-driven/);
  assert.match(gamerDoc, /- loop-driven/);
});
