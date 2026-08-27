const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');

test('MON3 shrink checklist prioritizes storage replacement before GLCD work', () => {
  const core = readFileSync(resolve(root, 'docs/mon3/core-and-auxiliary-services.md'), 'utf8');
  const space = readFileSync(resolve(root, 'docs/mon3/tecmate-rom-space-map.md'), 'utf8');

  assert.match(core, /^## Near-Term Shrink Checklist/m);
  assert.match(core, /Replace the old PATA\/FAT32 default with the TEC-FS direction/);
  assert.match(core, /Remove PATA from the standard ROM profile/);
  assert.match(core, /Treat FAT32 compatibility as tooling or compatibility code/);
  assert.match(core, /Leave RTC hardware services alone for now/);
  assert.match(core, /Treat GLCD as low priority unless it blocks another change/);
  assert.match(core, /GLCD banner removal is a\s+measured optional cut/);
  assert.match(core, /Do not remove the disassembler or classic monitor\s+commands until storage replacement has been measured/);
  assert.match(space, /just under 10K/);
  assert.match(space, /Private labels may move/);
  assert.match(space, /GLCD remains a low-priority containment issue/);
});
