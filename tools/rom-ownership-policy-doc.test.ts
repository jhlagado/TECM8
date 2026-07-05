const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const doc = readFileSync(resolve(root, 'docs/mon3/rom-ownership-policy.md'), 'utf8');
const readme = readFileSync(resolve(root, 'docs/README.md'), 'utf8');

test('ROM ownership policy keeps fixed ROM small and stable', () => {
  assert.match(doc, /fixed `C000h-FFFFh` ROM is the stable BIOS and recovery layer/);
  assert.match(doc, /fixed `RST 10h` service dispatch/);
  assert.match(doc, /bank switching, far-call, and far-jump services/);
  assert.match(doc, /expansion discovery and installed menu\/service vectors/);
  assert.match(doc, /Any fixed-ROM growth must name the service it enables and the code it replaces/);
});

test('ROM ownership policy puts TecMate growth in expansion ROM', () => {
  assert.match(doc, /banked `8000h-BFFFh` window is where TecMate grows/);
  assert.match(doc, /bank 0 supervisor, registry, shell, and launch policy/);
  assert.match(doc, /VDU\/TMS9918 services/);
  assert.match(doc, /TEC-FS mount, volume, locator, block, metadata, and file services/);
  assert.match(doc, /assembler, runner, debugger, and editor-facing services/);
  assert.match(doc, /should not depend on private implementation\s+labels in another bank/);
});

test('ROM ownership policy keeps storage and GLCD out of fixed ROM by default', () => {
  assert.match(doc, /PATA is not part of the standard TecMate fixed-ROM direction/);
  assert.match(doc, /FAT32 remains the\s+outer card\/container compatibility format/);
  assert.match(doc, /runtime storage should\s+move toward TEC-FS services in expansion ROM/);
  assert.match(doc, /should not grow a new FAT32 browser,\s+PATA path, or human-facing storage UI/);
  assert.match(doc, /main display direction is VDU\/TMS9918 first/);
  assert.match(doc, /GLCD remains useful, but it is\s+not a near-term fixed-ROM priority/);
  assert.match(doc, /Do not spend fixed-ROM bytes on GLCD\s+terminal policy, banner assets, scrollback, or editor-specific display logic/);
});

test('ROM ownership policy requires size review before commit', () => {
  assert.match(doc, /Every ROM-facing increment should answer three questions before commit/);
  assert.match(doc, /Did fixed monitor size change/);
  assert.match(doc, /Did expansion ROM size change, and in which bank/);
  assert.match(doc, /Does the change follow this ownership policy/);
  assert.match(doc, /npm run rom:size:delta/);
});

test('ROM ownership policy is discoverable from docs index', () => {
  assert.match(readme, /\[TecMate ROM Ownership Policy\]\(mon3\/rom-ownership-policy\.md\)/);
});
